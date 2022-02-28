const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const _internal = @import("./_internal.zig");

pub const Args = struct { remote: u64, user: string, package: string };

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    const args = @ptrCast(*const Args, @alignCast(@alignOf(Args), captures));

    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try _internal.reqRemote(request, response, args.remote);
    const o = try _internal.reqUser(request, response, r, args.user);
    const p = try _internal.reqPackage(request, response, o, args.package);
    const v = try p.versions(alloc);

    // calling inline yields 'error: cannot store runtime value in compile time variable'
    const readme = try _internal.renderREADME(alloc, v[0]);

    try _internal.writePageResponse(alloc, response, request, "/version.pek", .{
        .aquila_version = @import("root").version,
        .page = "version",
        .title = try std.fmt.allocPrint(alloc, "{d}/{s}/{s}", .{ r.id, o.name, p.name }),
        .user = u,
        .repo = r,
        .owner = o,
        .package = p,
        .versions = v,
        .version = v[0],
        .readme = readme,
    });
}
