const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const files = @import("self/files");
const pek = @import("pek");
const jwt = @import("jwt");
const extras = @import("extras");

const cookies = @import("../cookies.zig");
const db = @import("../db/_db.zig");

pub var jwt_secret: string = "";

pub fn writePageResponse(alloc: *std.mem.Allocator, response: *http.Response, request: http.Request, comptime name: string, data: anytype) !void {
    _ = request;
    try response.headers.put("Content-Type", "text/html");

    const w = response.writer();
    const head = comptime files.open("/_header.pek").?;
    const page = comptime files.open(name) orelse @compileError("file '" ++ name ++ "' not found in your files cache");
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
    const y = try db.User.byKey(alloc, .uuid, x);
    return y.?;
}

pub fn getUserOp(response: *http.Response, request: http.Request) !?db.User {
    _ = response;

    const x = JWT.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => return null,
        else => return err,
    };
    const alloc = request.arena;
    const y = try db.User.byKey(alloc, .uuid, x);
    return y.?;
}
