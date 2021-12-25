const std = @import("std");
const string = []const u8;

/// Returns the result of running `git rev-parse HEAD`
pub fn rev_HEAD(alloc: std.mem.Allocator, dir: std.fs.Dir) !string {
    const max = std.math.maxInt(usize);
    const dirg = try dir.openDir(".git", .{});
    const h = std.mem.trim(u8, try dirg.readFileAlloc(alloc, "HEAD", max), "\n");
    const r = std.mem.trim(u8, try dirg.readFileAlloc(alloc, h[5..], max), "\n");
    return r;
}
