const std = @import("std");
const string = []const u8;
const ulid = @import("ulid");
const extras = @import("extras");
const zfetch = @import("zfetch");
const json = @import("json");

const _handler = @import("../handler/_handler.zig");

const _db = @import("./_db.zig");
const User = _db.User;
const Package = _db.Package;

const _internal = @import("./_internal.zig");
const db = &_internal.db;

const Remote = @This();

id: u64 = 0,
uuid: ulid.ULID,
type: Type,
domain: string,

pub const table_name = "remotes";

usingnamespace _internal.TableTypeMixin(Remote);

pub var all_remotes: []const Remote = &.{};

pub const Type = enum {
    github,
    gitea,

    pub const BaseType = string;
};

pub const Repo = struct {
    id: string,
    name: string,
    added: bool,
};

pub const RepoDetails = struct {
    id: string,
    name: string,
    clone_url: string,
    description: string,
    default_branch: string,
    star_count: u32,
    owner: string,
};

pub const findUserBy = _internal.FindByGen(Remote, User, .provider, .id).first;

pub fn byKey(alloc: std.mem.Allocator, comptime key: std.meta.FieldEnum(Remote), value: extras.FieldType(Remote, key)) !?Remote {
    for (try all(alloc)) |item| {
        const a = @field(item, @tagName(key));
        if (@TypeOf(value) == string and std.mem.eql(u8, a, value)) {
            return item;
        }
        if (std.meta.eql(a, value)) {
            return item;
        }
    }
    return null;
}

pub fn all(alloc: std.mem.Allocator) ![]const Remote {
    if (all_remotes.len > 0) return all_remotes;
    return try db.collect(alloc, Remote, "select * from " ++ table_name ++ " order by id asc", .{});
}

pub fn create(alloc: std.mem.Allocator, ty: Type, domain: string) !Remote {
    db.mutex.lock();
    defer db.mutex.unlock();

    return _internal.insert(alloc, &Remote{
        .uuid = _internal.factory.newULID(),
        .type = ty,
        .domain = domain,
    });
}

pub fn listUserRepos(self: Remote, alloc: std.mem.Allocator, user: User) ![]const Repo {
    var list = std.ArrayList(Repo).init(alloc);
    const pkgs = try user.packages(alloc);

    switch (self.type) {
        .github => blk: {
            const val = try self.apiRequest(alloc, user, "/user/repos?per_page=100&sort=updated&visibility=public");
            if (val == null) break :blk;
            for (val.?.Array) |item| {
                if (std.mem.eql(u8, item.getT("language", .String) orelse "", "Zig")) {
                    const id = try std.fmt.allocPrint(alloc, "{d}", .{item.get("id").?.Int});
                    const name = item.get("full_name").?.String;
                    try list.append(.{ .id = id, .name = name, .added = containsPackage(pkgs, id) });
                }
            }
        },
        .gitea => blk: {
            const endpoint = try std.fmt.allocPrint(alloc, "/repos/search?uid={s}&limit=100&sort=updated&private=false", .{user.snowflake});
            const resp = (try self.apiRequest(alloc, user, endpoint)) orelse break :blk;
            const val = resp.getT("data", .Array) orelse break :blk;
            for (val) |item| {
                // NOTE: this filter will not have an effect until Gitea 1.17.0 lands (#18395)
                if (std.mem.eql(u8, item.getT("language", .String) orelse "Zig", "Zig")) {
                    const id = try std.fmt.allocPrint(alloc, "{d}", .{item.getT("id", .Int).?});
                    const name = item.getT("full_name", .String).?;
                    try list.append(.{ .id = id, .name = name, .added = containsPackage(pkgs, id) });
                }
            }
        },
    }
    return list.toOwnedSlice();
}

fn apiRequest(self: Remote, alloc: std.mem.Allocator, user: ?User, endpoint: string) !?json.Value {
    const url = try std.mem.concat(alloc, u8, &.{ try self.apiRoot(alloc), endpoint });
    defer alloc.free(url);

    const req = try zfetch.Request.init(alloc, url, null);
    defer req.deinit();

    var headers = zfetch.Headers.init(alloc);
    defer headers.deinit();

    if (user) |_| {
        if (_handler.getAccessToken(try user.?.uuid.toString(alloc))) |token| {
            switch (self.type) {
                .github => try headers.appendValue("Authorization", try std.mem.join(alloc, " ", &.{ "Bearer", token })),
                .gitea => try headers.appendValue("Authorization", try std.mem.join(alloc, " ", &.{ "token", token })),
            }
        }
    }

    try req.do(.GET, headers, null);
    const r = req.reader();
    const body_content = try r.readAllAlloc(alloc, std.math.maxInt(usize));
    const val = try json.parse(alloc, body_content);

    if (req.status.code >= 400) {
        std.log.err("{s} {s} {d} {}", .{ @tagName(self.type), endpoint, req.status.code, val });
        return null;
    }
    return val;
}

fn apiRoot(self: Remote, alloc: std.mem.Allocator) !string {
    return switch (self.type) {
        .github => "https://api.github.com",
        .gitea => try std.fmt.allocPrint(alloc, "https://{s}/api/v1", .{self.domain}),
    };
}

pub fn getRepo(self: Remote, alloc: std.mem.Allocator, repo: string) !RepoDetails {
    return self.parseDetails(
        alloc,
        (try self.apiRequest(
            alloc,
            null,
            try std.mem.join(alloc, "/", switch (self.type) {
                .github => &.{ "", "repos", repo },
                .gitea => &.{ "", "repos", repo },
            }),
        )) orelse return error.ApiRequestFail,
    );
}

pub fn parseDetails(self: Remote, alloc: std.mem.Allocator, raw: json.Value) !RepoDetails {
    return switch (self.type) {
        .github => .{
            .id = try std.fmt.allocPrint(alloc, "{}", .{raw.getT("id", .Int).?}),
            .name = raw.getT("name", .String).?,
            .clone_url = raw.getT("clone_url", .String).?,
            .description = raw.getT("description", .String) orelse "",
            .default_branch = raw.getT("default_branch", .String).?,
            .star_count = @intCast(u32, raw.getT("stargazers_count", .Int).?),
            .owner = raw.getT(.{ "owner", "login" }, .String).?,
        },
        .gitea => .{
            .id = try std.fmt.allocPrint(alloc, "{}", .{raw.getT("id", .Int).?}),
            .name = raw.getT("name", .String).?,
            .clone_url = raw.getT("clone_url", .String).?,
            .description = raw.getT("description", .String).?,
            .default_branch = raw.getT("default_branch", .String).?,
            .star_count = @intCast(u32, raw.getT("stars_count", .Int).?),
            .owner = raw.getT(.{ "owner", "login" }, .String).?,
        },
    };
}

pub fn installWebhook(self: Remote, alloc: std.mem.Allocator, user: User, rm_id: string, rm_name: string, hookurl: string) !?json.Value {
    _ = rm_id;
    return switch (self.type) {
        .github => try self.apiPost(alloc, user, try std.mem.concat(alloc, u8, &.{ "/repos/", rm_name, "/hooks" }), GithubWebhookData{
            .config = .{ .url = hookurl },
        }),
        .gitea => try self.apiPost(alloc, user, try std.mem.concat(alloc, u8, &.{ "/repos/", rm_name, "/hooks" }), GiteaCreateHookBody{
            .config = .{ .url = hookurl },
        }),
    };
}

fn apiPost(self: Remote, alloc: std.mem.Allocator, user: ?User, endpoint: string, data: anytype) !?json.Value {
    const url = try std.mem.concat(alloc, u8, &.{ try self.apiRoot(alloc), endpoint });
    defer alloc.free(url);

    const req = try zfetch.Request.init(alloc, url, null);
    defer req.deinit();

    var headers = zfetch.Headers.init(alloc);
    defer headers.deinit();

    if (user) |_| {
        if (_handler.getAccessToken(try user.?.uuid.toString(alloc))) |token| {
            try headers.appendValue("Authorization", try std.mem.join(alloc, " ", &.{ "Bearer", token }));
        }
    }
    try headers.appendValue("Content-Type", "application/json");
    try headers.appendValue("Accept", "application/vnd.github.v3+json");

    var payload = std.ArrayList(u8).init(alloc);
    defer payload.deinit();
    try std.json.stringify(data, .{}, payload.writer());

    try req.do(.POST, headers, payload.toOwnedSlice());
    const r = req.reader();
    const body_content = try r.readAllAlloc(alloc, std.math.maxInt(usize));
    const val = try json.parse(alloc, body_content);

    if (req.status.code >= 400) {
        std.log.err("{s} {s} {d} {}", .{ @tagName(self.type), endpoint, req.status.code, val });
        return null;
    }
    return val;
}

fn containsPackage(haystack: []const Package, id: string) bool {
    for (haystack) |item| {
        if (std.mem.eql(u8, item.remote_id, id)) {
            return true;
        }
    }
    return false;
}

const GithubWebhookData = struct {
    name: string = "web",
    config: struct {
        url: string,
        events: []const string = &.{"push"},
        content_type: string = "json",
        active: bool = true,
    },
};

const GiteaCreateHookBody = struct {
    active: bool = true,
    config: struct {
        url: string,
        content_type: string = "json",
    },
    events: []const string = &.{"push"},
    type: string = "gitea",
};
