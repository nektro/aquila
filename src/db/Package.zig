const Package = @This();
pub const table_name = "packages";

const std = @import("std");
const string = []const u8;
const extras = @import("extras");

const _db = @import("./_db.zig");
const Version = _db.Version;
const Time = _db.Time;
const User = _db.User;
const Remote = _db.Remote;

const ox = @import("ox").sql;
const db = &ox.db;

id: u64 = 0,
uuid: ox.ULID,
owner: ox.ULID,
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
clone_url: string,

pub fn create(alloc: std.mem.Allocator, owner: User, name: string, remote: Remote, rm_id: string, rm_name: string, desc: string, license: string, star_count: u64, clone_url: string) !Package {
    db.mutex.lock();
    defer db.mutex.unlock();

    return try ox.insert(alloc, &Package{
        .uuid = ox.factory.newULID(),
        .owner = owner.uuid,
        .name = name,
        .created_on = Time.now(),
        .remote = remote.id,
        .remote_id = rm_id,
        .remote_name = rm_name,
        .description = desc,
        .license = license,
        .latest_version = "",
        .hook_secret = try extras.randomSlice(alloc, std.crypto.random, u8, 16),
        .star_count = star_count,
        .clone_url = clone_url,
    });
}

pub usingnamespace ox.TableTypeMixin(Package);
pub usingnamespace ox.ByKeyGen(Package);
pub usingnamespace ox.JsonStructSkipMixin(@This(), &.{ "id", "hook_secret" });

pub const findVersionBy = ox.FindByGen(Package, Version, .p_for, .uuid).first;

pub fn latest(alloc: std.mem.Allocator) ![]const Package {
    return try db.collect(alloc, Package, "select * from packages order by id desc limit 15", .{});
}

pub fn topStarred(alloc: std.mem.Allocator) ![]const Package {
    return try db.collect(alloc, Package, "select * from packages order by star_count desc limit 15", .{});
}

pub fn versions(self: Package, alloc: std.mem.Allocator) ![]const Version {
    return try Version.byKeyAll(alloc, .p_for, self.uuid, .desc);
}

pub fn setLatest(self: *Package, alloc: std.mem.Allocator, vers: Version) !void {
    try self.update(alloc, .latest_version, try std.fmt.allocPrint(alloc, "{}", .{vers}));
}

pub fn getLatestValid(self: Package, alloc: std.mem.Allocator) !Version {
    return (try db.first(alloc, Version, "select * from versions where p_for = ? and (real_major > 0 or real_minor > 0) order by id desc", .{self.uuid})) orelse @panic("unreachable");
}

pub fn findVersionAt(self: Package, alloc: std.mem.Allocator, major: u32, minor: u32) !?Version {
    return try db.first(alloc, Version, "select * from versions where p_for = ? and real_major = ? and real_minor = ?", .{ self.uuid, major, minor });
}

pub fn cloneUrl(self: Package, alloc: std.mem.Allocator) !string {
    if (self.clone_url.len > 0) {
        return self.clone_url;
    }
    const repo = try _db.Remote.byKey(alloc, .id, self.remote);
    return try std.fmt.allocPrint(alloc, "https://{s}/{s}", .{ repo.?.domain, self.remote_name });
}
