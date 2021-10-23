const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const files = @import("self/files");
const extras = @import("extras");
const oauth2 = @import("oauth2");
const json = @import("json");

const mime = @import("../mime.zig");
const db = @import("../db/_db.zig");

const _internal = @import("./_internal.zig");
const _index = @import("./index.zig");
const _user = @import("./user.zig");
const _package = @import("./package.zig");
const _dashboard = @import("./dashboard.zig");
const _import = @import("./import.zig");

pub fn init(alloc: *std.mem.Allocator) !void {
    var secret_seed: [std.rand.DefaultCsprng.secret_seed_length]u8 = undefined;
    std.crypto.random.bytes(&secret_seed);
    var csprng = std.rand.DefaultCsprng.init(secret_seed);

    _internal.jwt_secret = try extras.randomSlice(alloc, &csprng.random, u8, 64);
    _internal.access_tokens = std.StringHashMap(string).init(alloc);
    _internal.token_liveness = std.StringHashMap(i64).init(alloc);
    _internal.token_expires = std.StringHashMap(i64).init(alloc);
}

pub fn getHandler(comptime oa2: type) http.RequestHandler(void) {
    @setEvalBranchQuota(10000);
    return http.router.Router(void, &.{
        http.router.get("/", Middleware(_index.get).next),
        file_route("/theme.css"),
        http.router.get("/about", Middleware(StaticPek("/about.pek").get).next),
        http.router.get("/contact", Middleware(StaticPek("/contact.pek").get).next),
        http.router.get("/login", Middleware(oa2.login).next),
        http.router.get("/callback", Middleware(oa2.callback).next),
        http.router.get("/dashboard", Middleware(_dashboard.get).next),
        http.router.get("/import", Middleware(_import.get).next),
        http.router.get("/:remote/:user", Middleware(_user.get).next),
        http.router.get("/:remote/:user/:package", Middleware(_package.get).next),
    });
}

fn Middleware(comptime f: anytype) type {
    const Args = @typeInfo(@TypeOf(f)).Fn.args[3].arg_type.?;
    return struct {
        pub fn next(_: void, response: *http.Response, request: http.Request, args: Args) !void {
            f({}, response, request, args) catch |err| {
                if (@as(anyerror, err) == error.HttpNoOp) return;
                return err;
            };
        }
    };
}

fn file_route(comptime path: string) http.router.Route {
    const T = struct {
        fn f(_: void, response: *http.Response, request: http.Request) !void {
            _ = request;

            if (comptime mime.typeByExtension(std.fs.path.extension(path))) |mediatype| {
                try response.headers.put("Content-Type", mediatype);
            }
            const w = response.writer();
            try w.writeAll(files.open(path).?);
        }
    };
    return http.router.get(path, T.f);
}

fn StaticPek(comptime path: string) type {
    return struct {
        pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
            _ = args;

            try _internal.writePageResponse(request.arena, response, request, path, .{
                .aquila_version = @import("root").version,
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
    const ulid = try std.mem.dupe(_internal.access_tokens.allocator, u8, try u.uuid.toString(alloc));

    try response.headers.put("Set-Cookie", try std.fmt.allocPrint(alloc, "jwt={s}", .{
        try _internal.JWT.encodeMessage(alloc, ulid),
    }));
    try _internal.cleanMaps();
    try _internal.access_tokens.put(ulid, try std.mem.dupe(_internal.access_tokens.allocator, u8, val.get("access_token").?.String));
    try _internal.token_liveness.put(ulid, std.time.timestamp());
    try _internal.token_expires.put(ulid, val.get("expires_in", .Int) orelse std.time.s_per_day);
}

pub fn getAccessToken(ulid: string) ?string {
    return _internal.access_tokens.get(ulid);
}
