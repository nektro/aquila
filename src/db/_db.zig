const std = @import("std");
const string = []const u8;
const extras = @import("extras");

const ox = @import("ox").sql;
const db = &ox.db;
const Engine = ox.Engine;

pub const Remote = @import("./Remote.zig");
pub const User = @import("./User.zig");
pub const Package = @import("./Package.zig");
pub const Version = @import("./Version.zig");
pub const Time = @import("./Time.zig");

pub fn connect(alloc: std.mem.Allocator, path: string) !void {
    const abspath = try std.fs.path.resolve(alloc, &.{path});

    // sqlite no longer does this for us
    if (!try extras.doesFileExist(null, abspath)) {
        const f = try std.fs.cwd().createFile(abspath, .{});
        f.close();
    }

    db.* = try Engine.connect(try alloc.dupeZ(u8, abspath));

    try ox.createTableT(alloc, db, Remote);
    try ox.createTableT(alloc, db, User);
    try ox.createTableT(alloc, db, Package);
    try ox.createTableT(alloc, db, Version);
}

pub fn close() void {
    db.close();
}

pub const CountStat = struct {
    ulid: string,
    count: u64,
};

// deps per pkg
pub fn chart1(alloc: std.mem.Allocator) ![]const CountStat {
    return try db.collect(alloc, CountStat, "select p_for, min(length(deps),(length(deps)-length(replace(deps,'\n',''))+1)) from (select * from versions order by id desc) group by p_for", .{});
}

// pkg size
pub fn chart2(alloc: std.mem.Allocator) ![]const CountStat {
    return try db.collect(alloc, CountStat, "select p_for, tar_size from (select * from versions order by id desc) group by p_for", .{});
}

// releases per pkg
pub fn chart3(alloc: std.mem.Allocator) ![]const CountStat {
    return try db.collect(alloc, CountStat, "select p_for, count(p_for) from versions group by p_for", .{});
}

// pkgs per user
pub fn chart4(alloc: std.mem.Allocator) ![]const CountStat {
    return try db.collect(alloc, CountStat, "select owner, count(owner) from packages group by owner", .{});
}

pub const TimeStat = struct {
    ulid: string,
    time: string,
};

// time since first release
pub fn chart5(alloc: std.mem.Allocator) ![]const TimeStat {
    return try db.collect(alloc, TimeStat, "select p_for, created_on from versions group by p_for", .{});
}

// time since latest release
pub fn chart6(alloc: std.mem.Allocator) ![]const TimeStat {
    return try db.collect(alloc, TimeStat, "select p_for, created_on from (select * from versions order by id desc) group by p_for", .{});
}
