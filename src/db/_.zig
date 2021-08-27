const std = @import("std");
const zorm = @import("zorm");
const extras = @import("extras");

const _internal = @import("./_internal.zig");
const db = &_internal.db;
const Engine = _internal.Engine;

pub fn connect(alloc: *std.mem.Allocator, path: []const u8) !void {
    const abspath = try std.fs.realpathAlloc(alloc, path);
    const nulpath = try extras.addSentinel(alloc, u8, abspath, 0);
    db.* = try Engine.connect(nulpath);
}

pub fn close() void {
    db.close();
}

pub const Remote = @import("./Remote.zig").Remote;
pub const User = @import("./User.zig").User;
pub const Package = @import("./Package.zig").Package;
pub const Version = @import("./Version.zig").Version;
