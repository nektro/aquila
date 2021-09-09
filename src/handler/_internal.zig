const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const files = @import("self/files");
const pek = @import("pek");
const jwt = @import("jwt");
const extras = @import("extras");

const cookies = @import("../cookies.zig");
const db = @import("../db/_.zig");

pub var jwt_secret: []const u8 = "";

pub fn writePageResponse(alloc: *std.mem.Allocator, response: *http.Response, request: http.Request, comptime name: []const u8, data: anytype) !void {
    _ = request;
    try response.headers.put("Content-Type", "text/html");

    const w = response.writer();
    const head = comptime files.open("/_header.pek").?;
    const page = comptime files.open(name) orelse @compileError("file '" ++ name ++ "' not found in your files cache");
    const tmpl = comptime pek.parse(head ++ page);
    try pek.compile(alloc, w, tmpl, data);
}

pub const JWT = struct {
    //

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

    // TODO
    fn tokenFromQuery(request: http.Request) !?string {
        _ = request;
        // return r.URL.Query().Get("jwt")
        return null;
    }
};
