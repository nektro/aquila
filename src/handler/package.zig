const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");

const _internal = @import("./_internal.zig");

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string, package: string }) !void {
    const alloc = request.arena;
    const u = try _internal.getUserOp(response, request);
    const r = try _internal.reqRemote(request, response, args.remote);
    const o = try _internal.reqUser(request, response, r, args.user);
    const p = try _internal.reqPackage(request, response, o, args.package);
    const v = try p.versions(alloc);

    const h = try request.headers(alloc);
    if (std.mem.eql(u8, h.get("accept") orelse "", "application/json")) {
        // stub for `zigmod aq add x/y/z`
        // TODO fill out json api
        try response.headers.put("Content-Type", "application/json");
        try std.json.stringify(
            JsonStub{ .repo = .{ .domain = r.domain }, .pkg = .{ .RemoteName = p.remote_name, .remote_name = p.remote_name } },
            .{},
            response.writer(),
        );
        return;
    }

    try _internal.writePageResponse(alloc, response, request, "/package.pek", .{
        .aquila_version = @import("root").version,
        .user = u,
        .repo = r,
        .owner = o,
        .pkg = p,
        .versions = v,
    });
}

// Fill in since stage1 messes up on nested anonymous structs
const JsonStub = struct {
    repo: struct { domain: string },
    pkg: struct { RemoteName: string, remote_name: string },
};
