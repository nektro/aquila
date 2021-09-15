const std = @import("std");
const http = @import("apple_pie");
const jwt = @import("jwt");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);
    const r = try u.remote(alloc);
    const p = try u.packages(alloc);

    try _internal.writePageResponse(alloc, response, request, "/dashboard.pek", .{
        .aquila_version = @import("root").version,
        .logged_in = true,
        .user = u,
        .repo = r,
        .pkgs = p,
    });
}
