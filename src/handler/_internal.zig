const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const files = @import("self/files");
const pek = @import("pek");
const jwt = @import("jwt");
const extras = @import("extras");
const ulid = @import("ulid");
const root = @import("root");
const options = @import("build_options");

const cookies = @import("../cookies.zig");
const db = @import("../db/_db.zig");

const epoch: i64 = 1577836800000; // 'Jan 1 2020' -> unix milli

pub var jwt_secret: string = "";
pub var access_tokens: std.StringHashMap(string) = undefined;
pub var token_liveness: std.StringHashMap(i64) = undefined;
pub var token_expires: std.StringHashMap(i64) = undefined;
pub var last_check: i64 = 0;

pub fn writePageResponse(alloc: std.mem.Allocator, response: *http.Response, request: http.Request, comptime name: string, data: anytype) !void {
    _ = request;
    try response.headers.put("Content-Type", "text/html");

    const w = response.writer();
    const head = files.@"/_header.pek";
    const page = @field(files, name);
    const tmpl = comptime pek.parse(head ++ page);
    try pek.compile(root, alloc, w, tmpl, data);
}

pub const JWT = struct {
    const Payload = struct {
        iss: string, // issuer
        sub: string, // subject
        iat: i64, // issued-at
        exp: i64, // expiration
        nbf: u64, // not-before
    };

    pub fn veryifyRequest(request: http.Request) !string {
        const text = (try tokenFromRequest(request)) orelse return error.NoTokenFound;
        const payload = try jwt.validate(Payload, request.arena, .HS256, text, .{ .key = jwt_secret });
        return payload.sub;
    }

    fn tokenFromRequest(request: http.Request) !?string {
        const T = fn (http.Request) anyerror!?string;
        for (&[_]T{ tokenFromCookie, tokenFromHeader, tokenFromQuery }) |item| {
            if (try item(request)) |token| {
                return token;
            }
        }
        return null;
    }

    fn tokenFromHeader(request: http.Request) !?string {
        const headers = try request.headers(request.arena);
        // extra check caused by https://github.com/Luukdegram/apple_pie/issues/70
        const auth = headers.get("Authorization") orelse headers.get("authorization");
        if (auth == null) return null;
        const ret = extras.trimPrefix(auth.?, "Bearer ");
        if (ret.len == auth.?.len) return null;
        return ret;
    }

    fn tokenFromCookie(request: http.Request) !?string {
        const headers = try request.headers(request.arena);
        const yum = try cookies.parse(request.arena, headers);
        return yum.get("jwt");
    }

    fn tokenFromQuery(request: http.Request) !?string {
        const q = try request.context.url.queryParameters(request.arena);
        return q.get("jwt");
    }

    pub fn encodeMessage(alloc: std.mem.Allocator, msg: string) !string {
        const p = Payload{
            .iss = root.name ++ ".r" ++ options.version,
            .sub = msg,
            .iat = std.time.timestamp(),
            .exp = std.time.timestamp() + (std.time.s_per_hour * 24 * 30),
            .nbf = epoch / std.time.ms_per_s,
        };
        return try jwt.encode(alloc, .HS256, p, .{ .key = jwt_secret });
    }
};

pub fn getUser(response: *http.Response, request: http.Request) !db.User {
    const x = JWT.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => |e| {
            try response.headers.put("X-Jwt-Fail", @errorName(e));
            try redirectTo(response, "./login");
            return error.HttpNoOp;
        },
        else => return err,
    };
    const alloc = request.arena;
    const y = try db.User.byKey(alloc, .uuid, try ulid.ULID.parse(alloc, x));
    return y.?;
}

pub fn getUserOp(response: *http.Response, request: http.Request) !?db.User {
    _ = response;

    const x = JWT.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => return null,
        else => return err,
    };
    const alloc = request.arena;
    const y = try db.User.byKey(alloc, .uuid, try ulid.ULID.parse(alloc, x));
    return y.?;
}

pub fn cleanMaps() !void {
    if (std.time.timestamp() - last_check < std.time.s_per_hour) return;
    defer last_check = std.time.timestamp();

    var iter = token_expires.iterator();
    while (iter.next()) |entry| {
        const now = std.time.timestamp();
        const uid = entry.key_ptr.*;
        const then = token_liveness.get(uid).?;
        const token = access_tokens.get(uid).?;
        if (then - now > entry.value_ptr.*) {
            _ = access_tokens.remove(uid);
            _ = token_liveness.remove(uid);
            _ = token_expires.remove(uid);
            access_tokens.allocator.free(uid);
            access_tokens.allocator.free(token);
        }
    }
}

pub fn mergeSlices(alloc: std.mem.Allocator, comptime T: type, side_a: []const T, side_b: []const T) ![]const T {
    var list = std.ArrayList(T).init(alloc);
    defer list.deinit();
    try list.ensureTotalCapacity(side_a.len + side_b.len);
    try list.appendSlice(side_a);
    try list.appendSlice(side_b);
    return list.toOwnedSlice();
}

pub fn assert(cond: bool, response: *http.Response, status: http.Response.Status, comptime fmt: string, args: anytype) !void {
    if (!cond) {
        return fail(response, status, fmt, args);
    }
}

pub fn fail(response: *http.Response, status: http.Response.Status, comptime fmt: string, args: anytype) (http.Response.Writer.Error || error{HttpNoOp}) {
    response.status_code = status;
    try response.writer().print(fmt ++ "\n", args);
    return error.HttpNoOp;
}

pub fn reqRemote(request: http.Request, response: *http.Response, id: u64) !db.Remote {
    const alloc = request.arena;
    const r = try db.Remote.byKey(alloc, .id, id);
    return r orelse fail(response, .not_found, "error: remote by id '{d}' not found", .{id});
}

pub fn reqUser(request: http.Request, response: *http.Response, r: db.Remote, name: string) !db.User {
    const alloc = request.arena;
    const u = try r.findUserBy(alloc, .name, name);
    return u orelse fail(response, .not_found, "error: user by name '{s}' not found", .{name});
}

pub fn reqPackage(request: http.Request, response: *http.Response, u: db.User, name: string) !db.Package {
    const alloc = request.arena;
    const p = try u.findPackageBy(alloc, .name, name);
    return p orelse fail(response, .not_found, "error: package by name '{s}' not found", .{name});
}

pub fn reqVersion(request: http.Request, response: *http.Response, p: db.Package, major: u32, minor: u32) !db.Version {
    const alloc = request.arena;
    const v = try p.findVersionAt(alloc, major, minor);
    return v orelse fail(response, .not_found, "error: version by id 'v{d}.{d}' not found", .{ major, minor });
}

pub fn parseInt(comptime T: type, input: ?string, response: *http.Response, comptime fmt: string, args: anytype) !T {
    const str = input orelse return fail(response, .bad_request, fmt, args);
    return std.fmt.parseUnsigned(T, str, 10) catch fail(response, .bad_request, fmt, args);
}

pub fn rename(old_path: string, new_path: string) !void {
    std.fs.cwd().rename(old_path, new_path) catch |err| switch (err) {
        error.RenameAcrossMountPoints => {
            try std.fs.copyFileAbsolute(old_path, new_path, .{});
            try std.fs.cwd().deleteFile(old_path);
        },
        else => |e| return e,
    };
}

pub fn redirectTo(response: *http.Response, dest: string) !void {
    try response.headers.put("Location", dest);
    try response.writeHeader(.found);
}

pub fn readFileContents(dir: std.fs.Dir, alloc: std.mem.Allocator, path: string) !?string {
    const file = dir.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        error.IsDir => return null,
        else => |e| return e,
    };
    defer file.close();
    return try file.reader().readAllAlloc(alloc, 1024 * 1024 * 2); // 2mb
}
