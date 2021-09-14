const std = @import("std");
const string = []const u8;

const _db = @import("./_db.zig");
const User = _db.User;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const ULID = string;
const Time = string;

pub const Remote = struct {
    id: u64,
    uuid: ULID,
    @"type": Type,
    domain: string,

    pub const table_name = "remotes";

    pub const Type = enum {
        github,

        pub const BaseType = string;
    };

    usingnamespace _internal.ByKeyGen(Remote);

    pub fn findUserByName(self: Remote, alloc: *std.mem.Allocator, name: string) !?User {
        return try db.first(alloc, User, "select * from users where provider = ? and name = ?", .{
            .provider = self.id,
            .name = name,
        });
    }
};
