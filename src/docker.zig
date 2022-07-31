//! https://docs.docker.com/engine/api/v1.41/

const std = @import("std");
const string = []const u8;
const UrlValues = @import("UrlValues");
const zfetch = @import("zfetch");
const job_doer = @import("./job_doer.zig");

const max_len = 1024 * 1024 * 5;

// temp workaround for stage1 bug
const ContainerCreate = struct {
    Image: string,
    Env: []const string,
    Volumes: struct { @"/images": struct {} },
    HostConfig: struct {
        Binds: []const string,
    },
    Mounts: []const job_doer.Mount,
};
/// https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerCreate
pub fn containerCreate(alloc: std.mem.Allocator, payload: ContainerCreate) !std.json.ValueTree {
    const url = "http://localhost/v1.41/containers/create";
    var docker_conn = try zfetch.Connection.connect(alloc, .{ .protocol = .unix, .hostname = "/var/run/docker.sock" });
    defer docker_conn.close();
    var req = try zfetch.Request.fromConnection(alloc, docker_conn, url);
    var headers = zfetch.Headers.init(alloc);
    try headers.appendValue("Content-Type", "application/json");
    try req.do(.POST, headers, try std.json.stringifyAlloc(alloc, payload, .{}));
    const r = req.reader();
    const body_content = try r.readAllAlloc(alloc, max_len);
    std.log.debug("{d}: {s}", .{ req.status.code, url });
    if (req.status.code != 201) std.log.debug("{s}", .{body_content});
    return try std.json.Parser.init(alloc, false).parse(body_content);
}

/// https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerStart
pub fn containerStart(alloc: std.mem.Allocator, id: string) !void {
    const url = try std.fmt.allocPrint(alloc, "http://localhost/v1.41/containers/{s}/start", .{id});
    var docker_conn = try zfetch.Connection.connect(alloc, .{ .protocol = .unix, .hostname = "/var/run/docker.sock" });
    defer docker_conn.close();
    var req = try zfetch.Request.fromConnection(alloc, docker_conn, url);
    var headers = zfetch.Headers.init(alloc);
    try headers.appendValue("Content-Type", "application/json");
    try req.do(.POST, headers, "{}");
    std.log.debug("{d}: {s}", .{ req.status.code, url });
}

/// https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerInspect
pub fn containerInspect(alloc: std.mem.Allocator, id: string) !std.json.ValueTree {
    const url = try std.fmt.allocPrint(alloc, "http://localhost/v1.41/containers/{s}/json", .{id});
    var docker_conn = try zfetch.Connection.connect(alloc, .{ .protocol = .unix, .hostname = "/var/run/docker.sock" });
    defer docker_conn.close();
    var req = try zfetch.Request.fromConnection(alloc, docker_conn, url);
    try req.do(.GET, null, null);
    const r = req.reader();
    const body_content = try r.readAllAlloc(alloc, max_len);
    std.log.debug("{d}: {s}", .{ req.status.code, url });
    return try std.json.Parser.init(alloc, false).parse(body_content);
}

/// https://docs.docker.com/engine/api/v1.41/#tag/Network/operation/NetworkConnect
pub fn networkConnect(alloc: std.mem.Allocator, network_id: string, container_id: string) !void {
    const url = try std.fmt.allocPrint(alloc, "http://localhost/v1.41/networks/{s}/connect", .{network_id});
    var docker_conn = try zfetch.Connection.connect(alloc, .{ .protocol = .unix, .hostname = "/var/run/docker.sock" });
    defer docker_conn.close();
    var req = try zfetch.Request.fromConnection(alloc, docker_conn, url);
    var headers = zfetch.Headers.init(alloc);
    try headers.appendValue("Content-Type", "application/json");
    try req.do(.POST, headers, try std.json.stringifyAlloc(alloc, .{ .Container = container_id }, .{}));
    const r = req.reader();
    const body_content = try r.readAllAlloc(alloc, max_len);
    std.log.debug("{d}: {s}", .{ req.status.code, url });
    std.log.debug("{s}", .{body_content});
}

/// https://docs.docker.com/engine/api/v1.41/#tag/Container/operation/ContainerDelete
pub fn containerDelete(alloc: std.mem.Allocator, id: string) !void {
    const url = try std.fmt.allocPrint(alloc, "http://localhost/v1.41/containers/{s}", .{id});
    var docker_conn = try zfetch.Connection.connect(alloc, .{ .protocol = .unix, .hostname = "/var/run/docker.sock" });
    defer docker_conn.close();
    var req = try zfetch.Request.fromConnection(alloc, docker_conn, url);
    try req.do(.DELETE, null, null);
    std.log.debug("{d}: {s}", .{ req.status.code, url });
}
