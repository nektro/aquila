const std = @import("std");

const string = []const u8;

pub fn splitAlloc(alloc: *std.mem.Allocator, input: string, delim: string) ![]const string {
    const result = &std.ArrayList(string).init(alloc);
    defer result.deinit();
    var it = std.mem.split(u8, input, delim);
    while (it.next()) |item| {
        try result.append(item);
    }
    return result.toOwnedSlice();
}

pub const list = struct {
    //

    pub fn contains(haystack: []const string, needle: string) bool {
        for (haystack) |item| {
            if (std.mem.eql(u8, item, needle)) {
                return true;
            }
        }
        return false;
    }
};
