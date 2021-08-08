const std = @import("std");
const builtin = @import("builtin");
const options = @import("build_options");
const http = @import("apple_pie");

const string = []const u8;
const git = @import("./git.zig");
const docker = @import("./docker.zig");
const signal = @import("./signal.zig");

pub const name = "Aquila";
pub var version: string = "";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;

    const rev: []const string = if (git.rev_HEAD(alloc) catch null) |h| &.{ ".", h[0..9] } else &.{ "", "" };
    const con: string = if (docker.amInside(alloc) catch false) ".docker" else "";
    version = try std.fmt.allocPrint(alloc, "v{s}{s}{s}{s}.zig{}", .{ options.version, rev[0], rev[1], con, builtin.zig_version });
    std.log.info("Starting {s} {s}", .{ name, version });

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
        index,
    );
}

fn handle_sig() void {
    std.os.exit(0);
}

fn index(_: void, response: *http.Response, request: http.Request) anyerror!void {
    _ = request;
    try response.writer().writeAll("TODO handler!");
}
