const std = @import("std");
const string = []const u8;

const _db = @import("./_db.zig");
const Package = _db.Package;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const ULID = string;
const Time = string;

pub const User = struct {
    id: u64,
    uuid: ULID,
    provider: u64,
    snowflake: string,
    name: string,
    joined_on: Time,

    usingnamespace _internal.ByKeyGen(User, "users");

    pub fn packages(self: User, alloc: *std.mem.Allocator) ![]const Package {
        return try Package.byKeyAll(alloc, .owner, self.uuid);
    }

    pub fn findPackageByName(self: User, alloc: *std.mem.Allocator, name: string) !?Package {
        return try db.first(alloc, Package, "select * from packages where owner = ? and name = ?", .{
            .owner = self.uuid,
            .name = name,
        });
    }
};
