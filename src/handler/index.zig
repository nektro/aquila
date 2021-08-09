const std = @import("std");
const http = @import("apple_pie");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request) !void {
    const user: ?usize = null;
    try _internal.writePageResponse(response, request, "/index.pek", .{
        .aquila_version = @import("root").version,
        .user = user,
    });
}
