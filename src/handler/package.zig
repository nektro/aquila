const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string, package: string }) !void {
    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try db.Remote.byKey(alloc, .id, args.remote);
    const o = try r.?.findUserBy(alloc, .name, args.user);
    const p = try o.?.findPackageBy(alloc, .name, args.package);
    const v = try p.?.versions(alloc);

    try _internal.writePageResponse(alloc, response, request, "/package.pek", .{
        .aquila_version = @import("root").version,
        .user = u,
        .repo = r.?,
        .owner = o.?,
        .pkg = p.?,
        .versions = v,
    });
}
