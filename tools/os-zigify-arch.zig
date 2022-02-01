const std = @import("std");
const string = []const u8;
const shared = @import("./shared.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const alloc = arena.allocator();

    const proc_args = try std.process.argsAlloc(alloc);
    const args = proc_args[1..];

    const E = std.meta.DeclEnum(shared.targets);
    const os = std.meta.stringToEnum(E, args[0]) orelse @panic("Unsupported OS");

    return switch (os) {
        // https://github.com/ziglang/zig/issues/10731
        .std, .Arch => {},

        .debian => try print(shared.targets.debian.kvs, args[1]),
        .alpine => try print(shared.targets.alpine.kvs, args[1]),
        .freebsd => try print(shared.targets.freebsd.kvs, args[1]),
        .netbsd => try print(shared.targets.netbsd.kvs, args[1]),
    };
}

fn print(kvs: anytype, arch: string) !void {
    const out = std.io.getStdOut().writer();

    for (kvs) |item| {
        if (item.value == null) continue;
        if (!std.mem.eql(u8, item.key, arch)) continue;
        try out.print("{s}", .{@tagName(item.value.?)});
        break;
    }
}
