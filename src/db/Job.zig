const Self = @This();
pub const table_name = "jobs";

const std = @import("std");
const string = []const u8;
const extras = @import("extras");
const runner = @import("../runner.zig");

const _db = @import("./_db.zig");
const Package = _db.Package;
const Version = _db.Version;

const ox = @import("ox").sql;
const db = &ox.db;

id: u64 = 0,
uuid: ox.ULID,
package: u64,
commit: string,
state: State,
arch: Arch,
os: Os,

pub const State = enum {
    queued,
    pending,
    success,
    failure,

    pub const BaseType = string;

    usingnamespace extras.TagNameJsonStringifyMixin(@This());
};

pub const Arch = struct {
    tag: Tag,

    pub const Tag = enum {
        x86_64,

        comptime {
            extras.ensureFieldSubset(@This(), std.Target.Cpu.Arch);
        }
    };
    pub const BaseType = string;

    pub fn readField(alloc: std.mem.Allocator, value: BaseType) error{}!Arch {
        _ = alloc;
        return Arch{ .tag = std.meta.stringToEnum(Tag, value).? };
    }

    pub fn bindField(self: Arch, alloc: std.mem.Allocator) error{}!BaseType {
        _ = alloc;
        return @tagName(self.tag);
    }

    pub fn toString(self: Arch, alloc: std.mem.Allocator) error{}!BaseType {
        _ = alloc;
        return @tagName(self.tag);
    }

    pub fn jsonStringify(self: Arch, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@tagName(self.tag), options, out_stream);
    }

    pub fn format(self: Arch, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        return try writer.writeAll(@tagName(self.tag));
    }
};

pub const Os = struct {
    tag: Tag,

    pub const Tag = enum {
        debian,

        comptime {
            extras.ensureFieldSubset(Tag, _db.OnlyPubDeclEnum(@import("../targets.zig")));
        }
    };
    pub const BaseType = string;

    pub fn readField(alloc: std.mem.Allocator, value: BaseType) error{}!Os {
        _ = alloc;
        return Os{ .tag = std.meta.stringToEnum(Tag, value).? };
    }

    pub fn bindField(self: Os, alloc: std.mem.Allocator) error{}!BaseType {
        _ = alloc;
        return @tagName(self.tag);
    }

    pub fn toString(self: Os, alloc: std.mem.Allocator) error{}!BaseType {
        _ = alloc;
        return @tagName(self.tag);
    }

    pub fn jsonStringify(self: Os, options: std.json.StringifyOptions, out_stream: anytype) !void {
        try std.json.stringify(@tagName(self.tag), options, out_stream);
    }

    pub fn format(self: Os, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        return try writer.writeAll(@tagName(self.tag));
    }
};

pub fn create(alloc: std.mem.Allocator, package: Package, commit: string, arch: Arch.Tag, os: Os.Tag) !Self {
    db.mutex.lock();
    defer db.mutex.unlock();

    const j = try ox.insert(alloc, &Self{
        .uuid = ox.factory.newULID(),
        .package = package.id,
        .commit = commit,
        .state = .queued,
        .arch = Arch{ .tag = arch },
        .os = Os{ .tag = os },
    });
    return j;
}

usingnamespace ox.TableTypeMixin(Self);
usingnamespace ox.ByKeyGen(Self);
