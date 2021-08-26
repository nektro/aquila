const std = @import("std");

const _db = @import("./_.zig");

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const string = []const u8;
const ULID = string;
const Time = string;

pub const Version = struct {
    id: u64,
    uuid: ULID,
    p_for: ULID,
    created_on: Time,
    commit_to: string,
    unpacked_size: u64,
    total_size: u64,
    files: string,
    tar_size: u64,
    tar_hash: string,
    approved_by: ULID,
    real_major: u32,
    real_minor: u32,
    deps: string,
    dev_deps: string,

    pub fn latest(alloc: *std.mem.Allocator) ![]const Version {
        return try db.collect(alloc, Version, "select * from versions order by id desc limit 15", .{});
    }
};