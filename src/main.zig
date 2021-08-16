const std = @import("std");
const builtin = @import("builtin");
const options = @import("build_options");
const http = @import("apple_pie");

const string = []const u8;
const git = @import("./git.zig");
const docker = @import("./docker.zig");
const signal = @import("./signal.zig");
const handler = @import("./handler/_.zig");
const db = @import("./db/_.zig");

pub const name = "Aquila";
pub var version: string = "";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;

    const rev: []const string = if (git.rev_HEAD(alloc) catch null) |h| &.{ ".", h[0..9] } else &.{ "", "" };
    const con: string = if (docker.amInside(alloc) catch false) ".docker" else "";
    version = try std.fmt.allocPrint(alloc, "v{s}{s}{s}{s}.zig{}", .{ options.version, rev[0], rev[1], con, builtin.zig_version });
    version = version[0..std.mem.indexOfScalar(u8, version, '+').?];
    std.log.info("Starting {s} {s}", .{ name, version });

    //

    try db.connect(alloc, "data/access.db");

    //

    signal.listenFor(std.c.SIGINT, handle_sig);
    signal.listenFor(std.c.SIGTERM, handle_sig);

    //

    const port = 8000;
    std.log.info("starting server on port {d}", .{port});
    try http.listenAndServe(
        alloc,
        try std.net.Address.parseIp("127.0.0.1", port),
        {},
        comptime handler.getHandler(),
    );
}

fn handle_sig() void {
    db.close();
    std.os.exit(0);
}

pub fn pek_get_user_path(alloc: *std.mem.Allocator, ulid: []const u8) ![]const u8 {
    const user = try db.User.byUID(alloc, ulid);
    return try std.fmt.allocPrint(alloc, "{d}/{s}", .{ user.?.provider, user.?.name });
}

pub fn pek_version_pkg_path(alloc: *std.mem.Allocator, vers: db.Version) ![]const u8 {
    const pkg = try db.Package.byUID(alloc, vers.p_for);
    const user = try db.User.byUID(alloc, pkg.?.owner);
    return try std.fmt.allocPrint(alloc, "{d}/{s}/{s}", .{ user.?.provider, user.?.name, pkg.?.name });
}

pub fn pek_version_pkg_stars(alloc: *std.mem.Allocator, vers: db.Version) !u64 {
    const pkg = try db.Package.byUID(alloc, vers.p_for);
    return pkg.?.star_count;
}

pub fn pek_version_str(alloc: *std.mem.Allocator, vers: db.Version) ![]const u8 {
    return try std.fmt.allocPrint(alloc, "v{d}.{d}", .{ vers.real_major, vers.real_minor });
}

pub fn pek_version_pkg_description(alloc: *std.mem.Allocator, vers: db.Version) ![]const u8 {
    const pkg = try db.Package.byUID(alloc, vers.p_for);
    return pkg.?.description;
}
