const std = @import("std");
const string = []const u8;
const ulid = @import("ulid");
const zigmod = @import("zigmod");

const _db = @import("./_db.zig");
const Time = _db.Time;
const User = _db.User;
const Package = _db.Package;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

pub const Version = struct {
    id: u64 = 0,
    uuid: ulid.ULID,
    p_for: ulid.ULID,
    created_on: Time,
    commit_to: string,
    unpacked_size: u64,
    total_size: u64,
    files: string,
    tar_size: u64,
    tar_hash: string,
    approved_by: string, // TODO remove this column, app design changed
    real_major: u32,
    real_minor: u32,
    deps: DepList, // TODO remove this column, no longer used in upstream Zigmod
    dev_deps: DepList,
    root_deps: DepList,
    build_deps: DepList,

    pub const table_name = "versions";

    pub fn create(alloc: *std.mem.Allocator, pkg: Package, commit: string, unpackedsize: u64, totalsize: u64, files: []const string, tarsize: u64, tarhash: string, deps: []const zigmod.Dep, rootdeps: []const zigmod.Dep, builddeps: []const zigmod.Dep) !Version {
        db.mutex.lock();
        defer db.mutex.unlock();

        return try _internal.insert(alloc, &Version{
            .uuid = _internal.factory.newULID(),
            .p_for = pkg.uuid,
            .created_on = Time.now(),
            .commit_to = commit,
            .unpacked_size = unpackedsize,
            .total_size = totalsize,
            .files = try _internal.safeJoin(alloc, "\n", files),
            .tar_size = tarsize,
            .tar_hash = tarhash,
            .approved_by = "",
            .real_major = 0,
            .real_minor = 0,
            .deps = DepList{ .deps = deps },
            .dev_deps = DepList{ .deps = &.{} },
            .root_deps = DepList{ .deps = rootdeps },
            .build_deps = DepList{ .deps = builddeps },
        });
    }

    usingnamespace _internal.ByKeyGen(Version);

    pub fn latest(alloc: *std.mem.Allocator) ![]const Version {
        return try db.collect(alloc, Version, "select * from versions order by id desc limit 15", .{});
    }

    pub fn format(self: Version, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("v{d}.{d}", .{ self.real_major, self.real_minor });
    }

    pub fn setVersion(self: Version, alloc: *std.mem.Allocator, approver: User, major: u32, minor: u32) !void {
        try self.updateColumn(alloc, .approved_by, try approver.uuid.toString(alloc));
        try self.updateColumn(alloc, .real_major, major);
        try self.updateColumn(alloc, .real_minor, minor);
    }
};

const DepList = struct {
    deps: []const zigmod.Dep,

    const Self = @This();
    pub const BaseType = string;

    pub fn readField(alloc: *std.mem.Allocator, value: BaseType) !Self {
        var res = std.ArrayList(zigmod.Dep).init(alloc);
        var iter = std.mem.split(u8, value, "\n");
        while (iter.next()) |line| {
            if (line.len == 0) continue;
            var seq = std.mem.split(u8, line, " ");
            try res.append(.{
                .type = std.meta.stringToEnum(zigmod.DepType, seq.next().?).?,
                .path = seq.next().?,
                .version = seq.next().?,
                //
                .alloc = alloc,
                .id = "",
                .name = "",
                .main = "",
                .deps = &.{},
                .yaml = null,
            });
        }
        return DepList{ .deps = res.toOwnedSlice() };
    }

    pub fn bindField(self: Self, alloc: *std.mem.Allocator) !BaseType {
        var res = std.ArrayList(u8).init(alloc);
        defer res.deinit();
        const w = res.writer();
        // since list.items is initialized with `&[_]T{}`
        // this and the `[1..]` at the end are blocked on https://github.com/ziglang/zig/issues/6706
        // this workaround forces `.ptr` to not be `@0` when no other data has been written
        try w.writeAll("w");

        for (self.deps) |item, i| {
            if (i > 0) try w.writeAll("\n");
            try w.print("{s} {s} {s}", .{ @tagName(item.type), item.path, item.version });
        }
        return res.toOwnedSlice()[1..];
    }
};
