const std = @import("std");
const http = @import("apple_pie");

const db = @import("./../db/_.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request) !void {
    try _internal.writePageResponse(request.arena, response, request, "/index.pek", .{
        .aquila_version = @import("root").version,
        .logged_in = false,
        .latest_packages = try db.Package.latest(request.arena),
        .latest_versions = try db.Version.latest(request.arena),
        .top_starred = try db.Package.topStarred(request.arena),
    });
}
