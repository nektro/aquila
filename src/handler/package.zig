const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const db = @import("./../db/_.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string, package: string }) !void {
    const alloc = request.arena;
    const r = try db.Remote.byID(alloc, args.remote);
    const o = try r.?.findUserByName(alloc, args.user);
    const p = try o.?.findPackageByName(alloc, args.package);
    const v = try p.?.versions(alloc);

    try _internal.writePageResponse(alloc, response, request, "/package.pek", .{
        .aquila_version = @import("root").version,
        .logged_in = false,
        .repo = r.?,
        .owner = o.?,
        .pkg = p.?,
        .versions = v,
    });
}
