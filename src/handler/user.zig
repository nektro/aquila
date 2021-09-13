const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const db = @import("./../db/_.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string }) !void {
    const alloc = request.arena;
    const r = try db.Remote.byKey(alloc, .id, args.remote);
    const o = try r.?.findUserByName(alloc, args.user);
    const p = try o.?.packages(alloc);

    try _internal.writePageResponse(alloc, response, request, "/user.pek", .{
        .aquila_version = @import("root").version,
        .logged_in = false,
        .repo = r.?,
        .owner = o.?,
        .pkgs = p,
    });
}
