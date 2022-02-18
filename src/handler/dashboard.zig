const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub const Args: ?type = null;

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    _ = captures;

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);
    const r = try u.remote(alloc);
    const p = try u.packages(alloc);

    try _internal.writePageResponse(alloc, response, request, "/dashboard.pek", .{
        .aquila_version = @import("root").version,
        .page = "dashboard",
        .title = "Dashboard",
        .user = @as(?db.User, u),
        .owner = u,
        .repo = r,
        .pkgs = p,
    });
}
