const std = @import("std");

const _db = @import("./_.zig");
const User = _db.User;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const string = []const u8;
const ULID = string;
const Time = string;

pub const Remote = struct {
    id: u64,
    uuid: ULID,
    @"type": Type,
    domain: string,

    pub const Type = enum {
        github,

        pub const BaseType = string;
    };

    pub fn byID(alloc: *std.mem.Allocator, id: u64) !?Remote {
        return try db.first(alloc, Remote, "select * from remotes where id = ?", .{
            .id = id,
        });
    }

    pub fn findUserByName(self: Remote, alloc: *std.mem.Allocator, name: string) !?User {
        return try db.first(alloc, User, "select * from users where provider = ? and name = ?", .{
            .provider = self.id,
            .name = name,
        });
    }
};