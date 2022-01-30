const http = @import("apple_pie");
const root = @import("root");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);
    const r = try u.remote(alloc);
    const l = try r.listUserRepos(alloc, u);

    try _internal.writePageResponse(alloc, response, request, "/import.pek", .{
        .aquila_version = root.version,
        .title = "Import a Repository",
        .user = @as(?db.User, u),
        .disabled = root.disable_import_repo,
        .remote = r,
        .list = l,
    });
}
