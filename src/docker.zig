const std = @import("std");

const strings = @import("./strings.zig");

pub fn amInside(alloc: *std.mem.Allocator) !bool {
    const max = std.math.maxInt(usize);
    const c = try std.fs.cwd().readFileAlloc(alloc, "/proc/1/cgroup", max);
    var it = std.mem.split(u8, c, "\n");
    while (it.next()) |item| {
        const line = try strings.splitAlloc(alloc, item, ":");
        if (line.len < 3) {
            continue;
        }
        if (!strings.list.contains(&.{ "/", "/init.scope" }, line[2])) {
            return true;
        }
    }
    return false;
}
