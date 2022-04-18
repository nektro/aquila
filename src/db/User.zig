const User = @This();
pub const table_name = "users";

const std = @import("std");
const string = []const u8;

const _db = @import("./_db.zig");
const Package = _db.Package;
const Remote = _db.Remote;
const Time = _db.Time;

const ox = @import("ox").sql;
const db = &ox.db;

id: u64 = 0,
uuid: ox.ULID,
provider: u64,
snowflake: string,
name: string,
joined_on: Time,

pub fn create(alloc: std.mem.Allocator, provider: u64, snowflake: string, name: string) !User {
    db.mutex.lock();
    defer db.mutex.unlock();

    return try ox.insert(alloc, &User{
        .uuid = ox.factory.newULID(),
        .provider = provider,
        .snowflake = snowflake,
        .name = name,
        .joined_on = Time.now(),
    });
}

usingnamespace ox.TableTypeMixin(User);
usingnamespace ox.ByKeyGen(User);
usingnamespace ox.JsonStructSkipMixin(@This(), &.{"id"});

pub const findPackageBy = ox.FindByGen(User, Package, .owner, .uuid).first;

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
