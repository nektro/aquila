const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const files = @import("self/files");
const pek = @import("pek");
const jwt = @import("jwt");
const extras = @import("extras");
const ulid = @import("ulid");

const cookies = @import("../cookies.zig");
const db = @import("../db/_db.zig");

pub var jwt_secret: string = "";
pub var access_tokens: std.StringHashMap(string) = undefined;
pub var token_liveness: std.StringHashMap(i64) = undefined;
pub var token_expires: std.StringHashMap(i64) = undefined;
pub var last_check: i64 = 0;

pub fn writePageResponse(alloc: *std.mem.Allocator, response: *http.Response, request: http.Request, comptime name: string, data: anytype) !void {
    _ = request;
    try response.headers.put("Content-Type", "text/html");

    const w = response.writer();
    const head = files.@"/_header.pek";
    const page = @field(files, name);
    const tmpl = comptime pek.parse(head ++ page);
    try pek.compile(alloc, w, tmpl, data);
}

pub const JWT = struct {
    pub fn veryifyRequest(request: http.Request) !string {
        return try jwt.validateMessage(request.arena, .HS256, (try tokenFromRequest(request)) orelse return error.NoTokenFound, .{ .key = jwt_secret });
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
        const auth = headers.get("Authorization");
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

    pub fn encodeMessage(alloc: *std.mem.Allocator, msg: string) !string {
        return try jwt.encodeMessage(alloc, .HS256, msg, .{ .key = jwt_secret });
    }
};

pub fn getUser(response: *http.Response, request: http.Request) !db.User {
    const x = JWT.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => {
            try response.headers.put("Location", "./login");
            try response.writeHeader(.found);
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

pub fn mergeSlices(alloc: *std.mem.Allocator, comptime T: type, side_a: []const T, side_b: []const T) ![]const T {
    var list = std.ArrayList(T).init(alloc);
    defer list.deinit();
    try list.ensureTotalCapacity(side_a.len + side_b.len);
    try list.appendSlice(side_a);
    try list.appendSlice(side_b);
    return list.toOwnedSlice();
}

/// workaround for https://github.com/ziglang/zig/issues/10317
pub fn dirSize(alloc: *std.mem.Allocator, path: string) !usize {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();
    return try extras.dirSize(alloc, dir);
}

/// workaround for https://github.com/ziglang/zig/issues/10317
pub fn fileList(alloc: *std.mem.Allocator, path: string) ![]const string {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();
    return try extras.fileList(alloc, dir);
}

pub fn assert(cond: bool, response: *http.Response, comptime fmt: string, args: anytype) !void {
    if (!cond) {
        try response.writer().print(fmt, args);
        return error.HttpNoOp;
    }
}

pub fn fail(response: *http.Response, comptime fmt: string, args: anytype) (http.Response.Writer.Error || error{HttpNoOp}) {
    try response.writer().print(fmt, args);
    return error.HttpNoOp;
}
