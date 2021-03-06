const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const ox = @import("ox").www;
const extras = @import("extras");

const _internal = @import("./_internal.zig");

pub const Args = struct { remote: u64, user: string, package: string, version: string };

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    const args = extras.ptrCastConst(Args, captures.?);

    try ox.assert(args.version.len > 0, response, .bad_request, "error: empty version string", .{});
    try ox.assert(std.mem.startsWith(u8, args.version, "v"), response, .bad_request, "error: bad version string format", .{});

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
                return ox.fail(response, .not_found, "Resource not found", .{});
            }
            try ox.assert(std.mem.eql(u8, item2, "tar"), response, .not_found, "Resource not found", .{});
            try ox.assert(std.mem.eql(u8, item3, "gz"), response, .not_found, "Resource not found", .{});

            // must be 'tar' and 'gz'
            // TODO do archive download
            return ox.fail(response, .ok, "TODO .tar.gz download", .{});
        }
        // fail
        // TODO migrate to using .zip
        return ox.fail(response, .not_found, "Resource not found", .{});
    }

    // load version page

    // calling inline yields 'error: cannot store runtime value in compile time variable'
    const readme = _internal.renderREADME(alloc, v) catch "";

    try ox.writePageResponse(alloc, response, request, "/version.pek", .{
        .aquila_version = @import("root").version,
        .page = "version",
        .title = try std.fmt.allocPrint(alloc, "{d}/{s}/{s} @ v{d}.{d}", .{ r.id, o.name, p.name, v.real_major, v.real_minor }),
        .user = u,
        .repo = r,
        .owner = o,
        .package = p,
        .versions = try p.versions(alloc),
        .version = v,
        .readme = readme,
    });
}
