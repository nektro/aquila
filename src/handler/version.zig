const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string, package: string, version: string }) !void {
    try _internal.assert(args.version.len > 0, response, "error: empty version string", .{});
    try _internal.assert(std.mem.startsWith(u8, args.version, "v"), response, "error: bad version string format", .{});

    var viter = std.mem.split(u8, args.version[1..], ".");
    const major = try _internal.parseInt(u32, viter.next(), response, "error: invalid major version", .{});
    const minor = try _internal.parseInt(u32, viter.next(), response, "error: invalid minor version", .{});

    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try _internal.reqRemote(request, response, args.remote);
    const o = try _internal.reqUser(request, response, r, args.user);
    const p = try _internal.reqPackage(request, response, o, args.package);
    const v = try _internal.reqVersion(request, response, p, major, minor);

    if (viter.next()) |item2| {
        if (viter.next()) |item3| {
            if (viter.next()) |_| {
                // fail
                return _internal.fail(response, "Resource not found", .{});
            }
            try _internal.assert(std.mem.eql(u8, item2, "tar"), response, "Resource not found", .{});
            try _internal.assert(std.mem.eql(u8, item3, "gz"), response, "Resource not found", .{});

            // must be 'tar' and 'gz'
            // TODO do archive download
            return _internal.fail(response, "TODO .tar.gz download", .{});
        }
        // fail
        // TODO migrate to using .zip
        return _internal.fail(response, "Resource not found", .{});
    }

    // load version page

    try _internal.writePageResponse(alloc, response, request, "/version.pek", .{
        .aquila_version = @import("root").version,
        .user = u,
        .repo = r,
        .owner = o,
        .pkg = p,
        .version = v,
    });
}
