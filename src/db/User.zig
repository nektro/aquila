const User = @This();
pub const table_name = "users";

const std = @import("std");
const string = []const u8;
const ulid = @import("ulid");

const _db = @import("./_db.zig");
const Package = _db.Package;
const Remote = _db.Remote;
const Time = _db.Time;

const _internal = @import("ox").sql;
const db = &_internal.db;

id: u64 = 0,
uuid: ulid.ULID,
provider: u64,
snowflake: string,
name: string,
joined_on: Time,

pub fn create(alloc: std.mem.Allocator, provider: u64, snowflake: string, name: string) !User {
    db.mutex.lock();
    defer db.mutex.unlock();

    return try _internal.insert(alloc, &User{
        .uuid = _internal.factory.newULID(),
        .provider = provider,
        .snowflake = snowflake,
        .name = name,
        .joined_on = Time.now(),
    });
}

usingnamespace _internal.TableTypeMixin(User);
usingnamespace _internal.ByKeyGen(User);
usingnamespace _internal.JsonStructSkipMixin(@This(), &.{"id"});

pub const findPackageBy = _internal.FindByGen(User, Package, .owner, .uuid).first;

pub fn packages(self: User, alloc: std.mem.Allocator) ![]const Package {
    return try Package.byKeyAll(alloc, .owner, self.uuid, .asc);
}

pub fn remote(self: User, alloc: std.mem.Allocator) !Remote {
    for (try Remote.all(alloc, .asc)) |item| {
        if (item.id == self.provider) {
            return item;
        }
    }
    unreachable;
}
