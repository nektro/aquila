const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);
    const r = try u.remote(alloc);
    const p = try u.packages(alloc);

    try _internal.writePageResponse(alloc, response, request, "/dashboard.pek", .{
        .aquila_version = @import("root").version,
        .title = "Dashboard",
        .user = @as(?db.User, u),
        .owner = u,
        .repo = r,
        .pkgs = p,
    });
}
