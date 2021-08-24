const std = @import("std");
const zorm = @import("zorm");

const Engine = zorm.engine(.sqlite3);
var db: Engine = undefined;

pub fn connect(alloc: *std.mem.Allocator, path: []const u8) !void {
    const abspath = try std.fs.realpathAlloc(alloc, path);
    const nulpath = try addSentinel(alloc, u8, abspath, 0);
    db = try Engine.connect(nulpath);
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
};

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
