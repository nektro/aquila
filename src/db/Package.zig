const std = @import("std");
const string = []const u8;

const _db = @import("./_db.zig");
const Version = _db.Version;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

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

    pub const table_name = "packages";

    usingnamespace _internal.ByKeyGen(Package);

    pub fn latest(alloc: *std.mem.Allocator) ![]const Package {
        return try db.collect(alloc, Package, "select * from packages order by id desc limit 15", .{});
    }

    pub fn topStarred(alloc: *std.mem.Allocator) ![]const Package {
        return try db.collect(alloc, Package, "select * from packages order by star_count desc limit 15", .{});
    }

    pub fn versions(self: Package, alloc: *std.mem.Allocator) ![]const Version {
        return try Version.byKeyAll(alloc, .p_for, self.uuid);
    }
};
