const std = @import("std");
const builtin = @import("builtin");
const options = @import("build_options");
const http = @import("apple_pie");
const extras = @import("extras");
const oauth2 = @import("oauth2");
const flag = @import("flag");

const string = []const u8;
const git = @import("./git.zig");
const docker = @import("./docker.zig");
const signal = @import("./signal.zig");
const handler = @import("./handler/_.zig");
const db = @import("./db/_.zig");

pub const name = "Aquila";
pub var version: string = "";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;

    const rev: []const string = if (git.rev_HEAD(alloc) catch null) |h| &.{ ".", h[0..9] } else &.{ "", "" };
    const con: string = if (docker.amInside(alloc) catch false) ".docker" else "";
    version = try std.fmt.allocPrint(alloc, "v{s}{s}{s}{s}.zig{}", .{ options.version, rev[0], rev[1], con, builtin.zig_version });
    version = version[0..std.mem.indexOfScalar(u8, version, '+').?];
    std.log.info("Starting {s} {s}", .{ name, version });

    oauth2.providers.github.id = "github.com";
    oauth2.providers.github.scope = try std.mem.join(alloc, " ", &.{ oauth2.providers.github.scope, "write:repo_hook" });

    //

    flag.init(alloc);

    try flag.addSingle("domain");
    try flag.addSingle("db");
    try flag.addSingle("port");
    try flag.addMulti("oauth2-client");

    _ = try flag.parse(.double);
    try flag.parseEnv();

    //

    try db.connect(alloc, flag.getSingle("db") orelse "data/access.db");

    //

    signal.listenFor(std.os.linux.SIG.INT, handle_sig);
    signal.listenFor(std.os.linux.SIG.TERM, handle_sig);

    //

    try handler.init(alloc);

    var clients = std.ArrayList(oauth2.Client).init(alloc);
    for (flag.getMulti("oauth2-client").?) |item| {
        var iter = std.mem.split(u8, item, "|");
        try clients.append(.{
            .provider = oauth2.providerById(iter.next().?).?,
            .id = iter.next().?,
            .secret = iter.next().?,
        });
    }

    const oa2 = oauth2.Handlers(struct {
        pub const Ctx = void;
        pub const isLoggedIn = handler.isLoggedIn;
        pub const doneUrl = "/dashboard";
        pub const saveInfo = handler.saveInfo;
    });
    oa2.clients = clients.toOwnedSlice();
    oa2.callbackPath = "/callback";

    const port = 8000;
    std.log.info("starting server on port {d}", .{port});
    try http.listenAndServe(
        alloc,
        try std.net.Address.parseIp("127.0.0.1", port),
        {},
        comptime handler.getHandler(oa2),
    );
}

fn handle_sig() void {
    db.close();
    std.os.exit(0);
}

pub fn pek_get_user_path(alloc: *std.mem.Allocator, ulid: string) !string {
    const user = try db.User.byUID(alloc, ulid);
    return try std.fmt.allocPrint(alloc, "{d}/{s}", .{ user.?.provider, user.?.name });
}

pub fn pek_version_pkg_path(alloc: *std.mem.Allocator, vers: db.Version) !string {
    const pkg = try db.Package.byUID(alloc, vers.p_for);
    const user = try db.User.byUID(alloc, pkg.?.owner);
    return try std.fmt.allocPrint(alloc, "{d}/{s}/{s}", .{ user.?.provider, user.?.name, pkg.?.name });
}

pub fn pek_version_pkg_stars(alloc: *std.mem.Allocator, vers: db.Version) !u64 {
    const pkg = try db.Package.byUID(alloc, vers.p_for);
    return pkg.?.star_count;
}

pub fn pek_version_str(alloc: *std.mem.Allocator, vers: db.Version) !string {
    return try std.fmt.allocPrint(alloc, "v{d}.{d}", .{ vers.real_major, vers.real_minor });
}

pub fn pek_version_pkg_description(alloc: *std.mem.Allocator, vers: db.Version) !string {
    const pkg = try db.Package.byUID(alloc, vers.p_for);
    return pkg.?.description;
}

/// TODO RFC3339 -> RFC1123
pub fn pek_fix_date(alloc: *std.mem.Allocator, in: string) !string {
    _ = alloc;
    return in;
}

pub fn pek_tree_url(alloc: *std.mem.Allocator, remo: db.Remote, repo: string, commit: string) !string {
    return switch (remo.@"type") {
        .github => try std.fmt.allocPrint(alloc, "https://github.com/{s}/tree/{s}", .{ repo, commit }),
    };
}

pub fn pek_fix_bytes(alloc: *std.mem.Allocator, size: u64) !string {
    return try extras.fmtByteCountIEC(alloc, size);
}
