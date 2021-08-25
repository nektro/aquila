const std = @import("std");
const zorm = @import("zorm");

const _internal = @import("./_internal.zig");
const db = &_internal.db;
const Engine = _internal.Engine;

pub fn connect(alloc: *std.mem.Allocator, path: []const u8) !void {
    const abspath = try std.fs.realpathAlloc(alloc, path);
    const nulpath = try addSentinel(alloc, u8, abspath, 0);
    db.* = try Engine.connect(nulpath);
}

pub fn close() void {
    db.close();
}

fn addSentinel(alloc: *std.mem.Allocator, comptime T: type, input: []const T, comptime sentinel: T) ![:sentinel]const T {
    var list = try std.ArrayList(T).initCapacity(alloc, input.len + 1);
    try list.appendSlice(input);
    try list.append(sentinel);
    const str = list.toOwnedSlice();
    return str[0 .. str.len - 1 :sentinel];
}

pub const Remote = @import("./Remote.zig").Remote;
pub const User = @import("./User.zig").User;
pub const Package = @import("./Package.zig").Package;
pub const Version = @import("./Version.zig").Version;
