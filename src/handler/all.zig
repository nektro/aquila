const http = @import("apple_pie");
const root = @import("root");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn users(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;
    const alloc = request.arena;

    try _internal.writePageResponse(alloc, response, request, "/all_users.pek", .{
        .aquila_version = root.version,
        .page = "all_users",
        .title = "All Users",
        .user = try _internal.getUserOp(response, request),
        .list = try db.User.all(alloc, .asc),
    });
}

pub fn packages(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;
    const alloc = request.arena;

    try _internal.writePageResponse(alloc, response, request, "/all_packages.pek", .{
        .aquila_version = root.version,
        .page = "all_packages",
        .title = "All Packages",
        .user = try _internal.getUserOp(response, request),
        .list = try db.Package.all(alloc, .desc),
    });
}
