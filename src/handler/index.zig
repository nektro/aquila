const std = @import("std");
const http = @import("apple_pie");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request) !void {
    try _internal.writePageResponse(request.arena, response, request, "/index.pek", .{
        .aquila_version = @import("root").version,
        .logged_in = false,
    });
}
