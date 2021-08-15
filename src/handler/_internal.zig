const std = @import("std");
const http = @import("apple_pie");

const files = @import("self/files");
const pek = @import("pek");

pub fn writePageResponse(alloc: *std.mem.Allocator, response: *http.Response, request: http.Request, comptime name: []const u8, data: anytype) !void {
    _ = request;
    try response.headers.put("Content-Type", "text/html");

    const w = response.writer();
    const head = comptime files.open("/_header.pek").?;
    const page = comptime files.open(name) orelse @compileError("file '" ++ name ++ "' not found in your files cache");
    const tmpl = comptime pek.parse(head ++ page);
    try pek.compile(alloc, w, tmpl, data);
}
