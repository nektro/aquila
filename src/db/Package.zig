const std = @import("std");

const _db = @import("./_.zig");

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const string = []const u8;
const ULID = string;
const Time = string;

pub const Package = struct {
    id: u64,
    uuid: ULID,
    owner: ULID,
    name: string,
    created_on: Time,
    remote: u64,
    remote_id: string,
    remote_name: string,
    description: string,
    license: string,
    latest_version: string,
    hook_secret: string,
    star_count: u64,

    pub fn latest(alloc: *std.mem.Allocator) ![]const Package {
        return try db.collect(alloc, Package, "select * from packages order by id desc limit 15", .{});
    }

    pub fn topStarred(alloc: *std.mem.Allocator) ![]const Package {
        return try db.collect(alloc, Package, "select * from packages order by star_count desc limit 15", .{});
    }

    pub fn byUID(alloc: *std.mem.Allocator, ulid: ULID) !?Package {
        return try db.first(alloc, Package, "select * from packages where uuid = ?", .{
            .uuid = ulid,
        });
    }
};
