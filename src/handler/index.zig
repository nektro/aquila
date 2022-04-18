const http = @import("apple_pie");
const ox = @import("ox").www;
const root = @import("root");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub const Args: ?type = null;

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    _ = captures;
    const alloc = request.arena;

    try ox.writePageResponse(alloc, response, request, "/index.pek", .{
        .aquila_version = root.version,
        .page = "index",
        .title = "Zig Package Index",
        .user = try _internal.getUserOp(response, request),
        .latest_packages = try db.Package.latest(alloc),
        .latest_versions = try db.Version.latest(alloc),
        .top_starred = try db.Package.topStarred(alloc),
        .user_count = try db.User.size(alloc),
        .pkg_count = try db.Package.size(alloc),
    });
}
