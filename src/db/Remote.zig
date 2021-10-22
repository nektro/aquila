const std = @import("std");
const string = []const u8;
const ulid = @import("ulid");

const _db = @import("./_db.zig");
const User = _db.User;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

pub const Remote = struct {
    id: u64 = 0,
    uuid: ulid.ULID,
    type: Type,
    domain: string,

    pub const table_name = "remotes";

    pub var all_remotes: []const Remote = &.{};

    pub const Type = enum {
        github,

        pub const BaseType = string;
    };

    pub const findUserBy = _internal.FindByGen(Remote, User, .provider, .id).first;

    pub fn byKey(alloc: *std.mem.Allocator, comptime key: std.meta.FieldEnum(Remote), value: _internal.FieldType(Remote, @tagName(key))) !?Remote {
        for (try all(alloc)) |item| {
            const a = @field(item, @tagName(key));
            if (@TypeOf(value) == string and std.mem.eql(u8, a, value)) {
                return item;
            }
            if (std.meta.eql(a, value)) {
                return item;
            }
        }
        return null;
    }

    pub fn all(alloc: *std.mem.Allocator) ![]const Remote {
        if (all_remotes.len > 0) return all_remotes;
        return db.collect(alloc, Remote, "select * from " ++ table_name, .{});
    }

    pub fn create(alloc: *std.mem.Allocator, ty: Type, domain: string) !Remote {
        const held = db.mutex.acquire();
        defer held.release();

        return _internal.insert(alloc, &Remote{
            .uuid = _internal.factory.newULID(),
            .type = ty,
            .domain = domain,
        });
    }
};
