const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string }) !void {
    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try _internal.reqRemote(request, response, args.remote);
    const o = try _internal.reqUser(request, response, r, args.user);
    const p = try o.packages(alloc);

    try _internal.writePageResponse(alloc, response, request, "/user.pek", .{
        .aquila_version = @import("root").version,
        .title = try std.fmt.allocPrint(alloc, "{d}/{s}", .{ r.id, o.name }),
        .user = u,
        .repo = r,
        .owner = o,
        .pkgs = p,
    });
}
