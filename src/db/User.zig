const std = @import("std");

const _db = @import("./_.zig");
const Package = _db.Package;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const string = []const u8;
const ULID = string;
const Time = string;

pub const User = struct {
    id: u64,
    uuid: ULID,
    provider: u64,
    snowflake: string,
    name: string,
    joined_on: Time,

    pub fn byUID(alloc: *std.mem.Allocator, ulid: ULID) !?User {
        return try db.first(alloc, User, "select * from users where uuid = ?", .{
            .uuid = ulid,
        });
    }

    pub fn packages(self: User, alloc: *std.mem.Allocator) ![]const Package {
        return try db.collect(alloc, Package, "select * from packages where owner = ?", .{
            .owner = self.uuid,
        });
    }
};