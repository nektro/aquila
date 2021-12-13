const std = @import("std");
const string = []const u8;
const ulid = @import("ulid");

const _db = @import("./_db.zig");
const Time = _db.Time;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

pub const Version = struct {
    id: u64,
    uuid: ulid.ULID,
    p_for: ulid.ULID,
    created_on: Time,
    commit_to: string,
    unpacked_size: u64,
    total_size: u64,
    files: string,
    tar_size: u64,
    tar_hash: string,
    approved_by: string, // TODO remove this column, app design changed
    real_major: u32,
    real_minor: u32,
    deps: string,
    dev_deps: string,

    pub const table_name = "versions";

    usingnamespace _internal.ByKeyGen(Version);

    pub fn latest(alloc: *std.mem.Allocator) ![]const Version {
        return try db.collect(alloc, Version, "select * from versions order by id desc limit 15", .{});
    }

    pub fn format(self: Version, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("v{d}.{d}", .{ self.real_major, self.real_minor });
    }

    pub fn setVersion(self: Version, alloc: *std.mem.Allocator, approver: User, major: u32, minor: u32) !void {
        try self.updateColumn(alloc, .approved_by, try approver.uuid.toString(alloc));
        try self.updateColumn(alloc, .real_major, major);
        try self.updateColumn(alloc, .real_minor, minor);
    }
};
