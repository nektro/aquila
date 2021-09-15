const std = @import("std");
const http = @import("apple_pie");

const db = @import("./../db/_db.zig");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;

    try _internal.writePageResponse(request.arena, response, request, "/index.pek", .{
        .aquila_version = @import("root").version,
        .user = try _internal.getUserOp(response, request),
        .latest_packages = try db.Package.latest(request.arena),
        .latest_versions = try db.Version.latest(request.arena),
        .top_starred = try db.Package.topStarred(request.arena),
    });
}
