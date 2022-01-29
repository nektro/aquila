const Self = @This();

const std = @import("std");
const string = []const u8;
const time = @import("time");

const _internal = @import("./_internal.zig");

ctx: time.DateTime,

pub fn formatAlloc(self: Self, alloc: std.mem.Allocator, comptime fmt: string) !string {
    return self.ctx.formatAlloc(alloc, fmt);
}

pub const BaseType = string;

pub fn readField(alloc: std.mem.Allocator, value: BaseType) !Self {
    _ = alloc;
    return Self{
        .ctx = time.DateTime.init(
            try std.fmt.parseUnsigned(u16, value[0..4], 10),
            (try std.fmt.parseUnsigned(u16, value[5..7], 10)) - 1,
            (try std.fmt.parseUnsigned(u16, value[8..10], 10)) - 1,
            try std.fmt.parseUnsigned(u16, value[11..13], 10),
            try std.fmt.parseUnsigned(u16, value[14..16], 10),
            try std.fmt.parseUnsigned(u16, value[17..19], 10),
        ),
    };
}

pub fn bindField(self: Self, alloc: std.mem.Allocator) !BaseType {
    // modified RFC3339
    return try self.formatAlloc(alloc, "YYY-MM-DD HH:mm:ss");
}

pub fn toString(self: Self, alloc: std.mem.Allocator) !string {
    // RFC1123
    return try self.formatAlloc(alloc, "ddd, DD MMM YYY HH:mm:ss z");
}

pub fn now() Self {
    return .{ .ctx = time.DateTime.now() };
}
