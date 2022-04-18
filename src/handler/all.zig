const std = @import("std");
const http = @import("apple_pie");
const root = @import("root");
const ox = @import("ox").www;

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn users(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    std.debug.assert(captures == null);

    const alloc = request.arena;

    try ox.writePageResponse(alloc, response, request, "/all_users.pek", .{
        .aquila_version = root.version,
        .page = "all_users",
        .title = "All Users",
        .user = try _internal.getUserOp(response, request),
        .list = try db.User.all(alloc, .asc),
    });
}

pub fn packages(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    std.debug.assert(captures == null);

    const alloc = request.arena;

    try ox.writePageResponse(alloc, response, request, "/all_packages.pek", .{
        .aquila_version = root.version,
        .page = "all_packages",
        .title = "All Packages",
        .user = try _internal.getUserOp(response, request),
        .list = try db.Package.all(alloc, .desc),
    });
}
