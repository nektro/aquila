const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const koino = @import("koino");
const ox = @import("ox").www;

const db = @import("../db/_db.zig");

pub var access_tokens: std.StringHashMap(string) = undefined;
pub var token_liveness: std.StringHashMap(i64) = undefined;
pub var token_expires: std.StringHashMap(i64) = undefined;
pub var last_check: i64 = 0;

pub fn getUser(response: *http.Response, request: http.Request) !db.User {
    const x = ox.token.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => |e| {
            try response.headers.put("X-Jwt-Fail", @errorName(e));
            try ox.redirectTo(response, "./login");
            return error.HttpNoOp;
        },
        else => return err,
    };
    const alloc = request.arena;
    const y = try db.User.byKey(alloc, .uuid, try ox.up.sql.ULID.parse(alloc, x));
    return y.?;
}

pub fn getUserOp(response: *http.Response, request: http.Request) !?db.User {
    _ = response;

    const x = ox.token.veryifyRequest(request) catch |err| switch (err) {
        error.NoTokenFound, error.InvalidSignature => return null,
        else => return err,
    };
    const alloc = request.arena;
    const y = try db.User.byKey(alloc, .uuid, try ox.up.sql.ULID.parse(alloc, x));
    return y.?;
}

pub fn cleanMaps() !void {
    if (std.time.timestamp() - last_check < std.time.s_per_hour) return;
    defer last_check = std.time.timestamp();

    var iter = token_expires.iterator();
    while (iter.next()) |entry| {
        const now = std.time.timestamp();
        const uid = entry.key_ptr.*;
        const then = token_liveness.get(uid).?;
        const token = access_tokens.get(uid).?;
        if (then - now > entry.value_ptr.*) {
            _ = access_tokens.remove(uid);
            _ = token_liveness.remove(uid);
            _ = token_expires.remove(uid);
            access_tokens.allocator.free(uid);
            access_tokens.allocator.free(token);
        }
    }
}

pub fn mergeSlices(alloc: std.mem.Allocator, comptime T: type, side_a: []const T, side_b: []const T) ![]const T {
    var list = std.ArrayList(T).init(alloc);
    defer list.deinit();
    try list.ensureTotalCapacity(side_a.len + side_b.len);
    try list.appendSlice(side_a);
    try list.appendSlice(side_b);
    return list.toOwnedSlice();
}

pub fn reqRemote(request: http.Request, response: *http.Response, id: u64) !db.Remote {
    const alloc = request.arena;
    const r = try db.Remote.byKey(alloc, .id, id);
    return r orelse ox.fail(response, .not_found, "error: remote by id '{d}' not found", .{id});
}

pub fn reqUser(request: http.Request, response: *http.Response, r: db.Remote, name: string) !db.User {
    const alloc = request.arena;
    const u = try r.findUserBy(alloc, .name, name);
    return u orelse ox.fail(response, .not_found, "error: user by name '{s}' not found", .{name});
}

pub fn reqPackage(request: http.Request, response: *http.Response, u: db.User, name: string) !db.Package {
    const alloc = request.arena;
    const p = try u.findPackageBy(alloc, .name, name);
    return p orelse ox.fail(response, .not_found, "error: package by name '{s}' not found", .{name});
}

pub fn reqVersion(request: http.Request, response: *http.Response, p: db.Package, major: u32, minor: u32) !db.Version {
    const alloc = request.arena;
    const v = try p.findVersionAt(alloc, major, minor);
    return v orelse ox.fail(response, .not_found, "error: version by id 'v{d}.{d}' not found", .{ major, minor });
}

pub fn parseInt(comptime T: type, input: ?string, response: *http.Response, comptime fmt: string, args: anytype) !T {
    const str = input orelse return ox.fail(response, .bad_request, fmt, args);
    return std.fmt.parseUnsigned(T, str, 10) catch ox.fail(response, .bad_request, fmt, args);
}

pub fn rename(old_path: string, new_path: string) !void {
    std.fs.cwd().rename(old_path, new_path) catch |err| switch (err) {
        error.RenameAcrossMountPoints => {
            try std.fs.copyFileAbsolute(old_path, new_path, .{});
            try std.fs.cwd().deleteFile(old_path);
        },
        else => |e| return e,
    };
}

pub fn readFileContents(dir: std.fs.Dir, alloc: std.mem.Allocator, path: string) !?string {
    const file = dir.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        error.IsDir => return null,
        else => |e| return e,
    };
    defer file.close();
    return try file.reader().readAllAlloc(alloc, 1024 * 1024 * 2); // 2mb
}

pub fn renderREADME(alloc: std.mem.Allocator, v: db.Version) !string {
    var p = try koino.parser.Parser.init(alloc, .{
        .extensions = .{
            .table = true,
            .strikethrough = true,
            .autolink = true,
            .tagfilter = true,
        },
    });
    try p.feed(v.readme);
    var doc = try p.finish();
    var list = std.ArrayList(u8).init(alloc);
    errdefer list.deinit();
    try koino.html.print(list.writer(), alloc, .{}, doc);
    return list.toOwnedSlice();
}
