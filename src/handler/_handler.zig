const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const files = @import("self/files");
const extras = @import("extras");
const oauth2 = @import("oauth2");
const json = @import("json");
const builtin = @import("builtin");

const mime = @import("../mime.zig");
const db = @import("../db/_db.zig");
const cookies = @import("../cookies.zig");

const _internal = @import("./_internal.zig");
const _index = @import("./index.zig");
const _user = @import("./user.zig");
const _package = @import("./package.zig");
const _dashboard = @import("./dashboard.zig");
const _import = @import("./import.zig");
const _do_import = @import("./do_import.zig");
const _hook = @import("./hook.zig");
const _version = @import("./version.zig");
const _all = @import("./all.zig");
const _stats = @import("./stats.zig");

pub fn init(alloc: std.mem.Allocator) !void {
    _internal.jwt_secret = try extras.randomSlice(alloc, std.crypto.random, u8, 64);
    _internal.access_tokens = std.StringHashMap(string).init(alloc);
    _internal.token_liveness = std.StringHashMap(i64).init(alloc);
    _internal.token_expires = std.StringHashMap(i64).init(alloc);
}

pub fn getHandler(comptime oa2: type) http.RequestHandler(void) {
    @setEvalBranchQuota(10000);
    return http.router.Router(void, &.{
        Route2(.get, "/", _index),
        file_route("/theme.css"),
        Route2(.get, "/stats", _stats),
        file_route("/stats.js"),
        Route2(.get, "/about", StaticPek("/about.pek", "About")),
        Route3(.get, "/login", oa2.login),
        Route3(.get, "/callback", oa2.callback),
        Route3(.get, "/logout", logout),
        Route2(.get, "/dashboard", _dashboard),
        Route2(.get, "/import", _import),
        Route2(.get, "/do_import", _do_import),
        Route3(.get, "/all/users", _all.users),
        Route3(.get, "/all/packages", _all.packages),
        Route2(.get, "/:remote/:user", _user),
        Route2(.get, "/:remote/:user/:package", _package),
        Route2(.post, "/:remote/:user/:package/hook", _hook),
        Route2(.get, "/:remote/:user/:package/:version", _version),
    });
}

fn Route1(comptime method: http.Request.Method, comptime endpoint: string, comptime C: ?type, comptime f: anytype) http.router.Route(void) {
    return @field(http.router.Builder(void), @tagName(method))(endpoint, C, Middleware(f).next);
}

fn Route2(comptime method: http.Request.Method, comptime endpoint: string, comptime T: type) http.router.Route(void) {
    return Route1(method, endpoint, T.Args, @field(T, @tagName(method)));
}

fn Route3(comptime method: http.Request.Method, comptime endpoint: string, comptime f: anytype) http.router.Route(void) {
    return Route1(method, endpoint, null, f);
}

fn Middleware(comptime f: anytype) type {
    return struct {
        pub fn next(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
            f({}, response, request, captures) catch |err| {
                if (@as(anyerror, err) == error.HttpNoOp) return;
                return err;
            };
        }
    };
}

fn file_route(comptime path: string) http.router.Route(void) {
    const T = struct {
        fn f(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
            _ = request;
            _ = captures;

            if (comptime mime.typeByExtension(std.fs.path.extension(path))) |mediatype| {
                try response.headers.put("Content-Type", mediatype);
            }
            const w = response.writer();
            if (builtin.mode == .Debug) {
                if (try openFile(std.fs.cwd(), try std.mem.join(request.arena, "", &.{ "www", path }))) |file| {
                    defer file.close();
                    return try extras.pipe(file.reader(), w);
                }
            }
            try response.headers.put("Etag", try etag(request.arena, @field(files, path)));
            try w.writeAll(@field(files, path));
        }
    };
    return Route1(.get, path, null, T.f);
}

fn StaticPek(comptime path: string, comptime title: string) type {
    return struct {
        pub const Args: ?type = null;
        pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
            _ = captures;

            try _internal.writePageResponse(request.arena, response, request, path, .{
                .aquila_version = @import("root").version,
                .page = "static",
                .title = title,
                .user = try _internal.getUserOp(response, request),
            });
        }
    };
}

pub fn isLoggedIn(request: http.Request) !bool {
    const x = _internal.JWT.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => return false,
        else => return err,
    };
    // don't need to waste hops to the db to check if its a value user ID because
    // if the signature is valid we know it came from us
    _ = x;
    return true;
}

pub fn saveInfo(response: *http.Response, request: http.Request, idp: oauth2.Provider, id: string, name: string, val: json.Value, val2: json.Value) !void {
    _ = name;
    _ = val2;

    const alloc = request.arena;
    const r = (try db.Remote.byKey(alloc, .domain, idp.domain())) orelse unreachable;
    const u = (try r.findUserBy(alloc, .snowflake, id)) orelse try db.User.create(alloc, r.id, id, name);
    const ulid = try _internal.access_tokens.allocator.dupe(u8, try u.uuid.toString(alloc));

    try response.headers.put("Set-Cookie", try std.fmt.allocPrint(alloc, "jwt={s}", .{
        try _internal.JWT.encodeMessage(alloc, ulid),
    }));
    try _internal.cleanMaps();
    try _internal.access_tokens.put(ulid, try _internal.access_tokens.allocator.dupe(u8, val.get("access_token").?.String));
    try _internal.token_liveness.put(ulid, std.time.timestamp());
    try _internal.token_expires.put(ulid, val.getT("expires_in", .Int) orelse std.time.s_per_day);
}

pub fn getAccessToken(ulid: string) ?string {
    return _internal.access_tokens.get(ulid);
}

pub fn logout(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    std.debug.assert(captures == null);
    _ = response;
    _ = request;

    try cookies.delete(response, "jwt");
    try _internal.redirectTo(response, "./");
}

pub fn openFile(dir: std.fs.Dir, path: string) !?std.fs.File {
    return dir.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |e| return e,
    };
}

fn etag(alloc: std.mem.Allocator, input: string) !string {
    var h = std.hash.Wyhash.init(0);
    h.update(input);
    return try std.fmt.allocPrint(alloc, "{x}", .{h.final()});
}
