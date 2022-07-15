const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const ox = @import("ox").www;
const extras = @import("extras");

const _internal = @import("./_internal.zig");

pub const Args = struct { remote: u64, user: string };

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    const args = extras.ptrCastConst(Args, captures.?);

    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try _internal.reqRemote(request, response, args.remote);
    const o = try _internal.reqUser(request, response, r, args.user);
    const p = try o.packages(alloc);

    try ox.writePageResponse(alloc, response, request, "/user.pek", .{
        .aquila_version = @import("root").version,
        .page = "user",
        .title = try std.fmt.allocPrint(alloc, "{d}/{s}", .{ r.id, o.name }),
        .user = u,
        .repo = r,
        .owner = o,
        .pkgs = p,
    });
}
