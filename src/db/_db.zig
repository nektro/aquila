const std = @import("std");
const string = []const u8;
const extras = @import("extras");
const root = @import("root");
const ulid = @import("ulid");

const _internal = @import("./_internal.zig");
const db = &_internal.db;
const db_jobs = &_internal.db_jobs;
const Engine = _internal.Engine;

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

    try _internal.createTableT(alloc, db, Remote);
    try _internal.createTableT(alloc, db, User);
    try _internal.createTableT(alloc, db, Package);
    try _internal.createTableT(alloc, db, Version);

    {
        const jobspath = try std.fs.path.join(alloc, &.{ root.datadirpath, "aquila.jobs.db" });
        const f = try std.fs.cwd().createFile(abspath, .{ .truncate = false });
        f.close();
        db_jobs.* = try Engine.connect(try alloc.dupeZ(u8, jobspath));
    }
}

pub fn close() void {
    db.close();
    db_jobs.close();
}
