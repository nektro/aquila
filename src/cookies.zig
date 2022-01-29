const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

pub const Jar = std.StringHashMap(string);

pub fn parse(alloc: std.mem.Allocator, headers: http.Request.Headers) !Jar {
    var map = Jar.init(alloc);
    // extra check caused by https://github.com/Luukdegram/apple_pie/issues/70
    const h = headers.get("Cookie") orelse headers.get("cookie");
    if (h == null) return map;

    var iter = std.mem.split(u8, h.?, ";");
    while (iter.next()) |item| {
        const i = std.mem.indexOfScalar(u8, item, '=');
        if (i == null) continue;
        const k = item[0..i.?];
        const v = item[i.? + 1 ..];

        if (map.contains(k)) continue;
        try map.put(k, v);
    }
    return map;
}
