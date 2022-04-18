const http = @import("apple_pie");
const root = @import("root");
const ox = @import("ox").www;

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub const Args: ?type = null;

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    _ = captures;

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);
    const r = try u.remote(alloc);
    const l = try r.listUserRepos(alloc, u);

    try ox.writePageResponse(alloc, response, request, "/import.pek", .{
        .aquila_version = root.version,
        .page = "import",
        .title = "Import a Repository",
        .user = @as(?db.User, u),
        .disabled = root.disable_import_repo,
        .remote = r,
        .list = l,
    });
}
