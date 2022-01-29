const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;
    const alloc = request.arena;

    try _internal.writePageResponse(alloc, response, request, "/index.pek", .{
        .aquila_version = @import("root").version,
        .title = "Zig Package Index",
        .user = try _internal.getUserOp(response, request),
        .latest_packages = try db.Package.latest(alloc),
        .latest_versions = try db.Version.latest(alloc),
        .top_starred = try db.Package.topStarred(alloc),
        .user_count = try db.User.size(alloc),
        .pkg_count = try db.Package.size(alloc),
    });
}
