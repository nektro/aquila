const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string, package: string }) !void {
    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try _internal.reqRemote(request, response, args.remote);
    const o = try _internal.reqUser(request, response, r, args.user);
    const p = try _internal.reqPackage(request, response, o, args.package);
    const v = try p.versions(alloc);

    try _internal.writePageResponse(alloc, response, request, "/package.pek", .{
        .aquila_version = @import("root").version,
        .user = u,
        .repo = r,
        .owner = o,
        .pkg = p,
        .versions = v,
    });
}
