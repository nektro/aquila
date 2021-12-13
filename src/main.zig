const std = @import("std");
const string = []const u8;
const builtin = @import("builtin");
const options = @import("build_options");
const http = @import("apple_pie");
const extras = @import("extras");
const oauth2 = @import("oauth2");
const flag = @import("flag");
const ulid = @import("ulid");
const zfetch = @import("zfetch");

const git = @import("./git.zig");
const docker = @import("./docker.zig");
const signal = @import("./signal.zig");
const handler = @import("./handler/_handler.zig");
const db = @import("./db/_db.zig");

pub const name = "Aquila";
pub var version: string = "";
pub const log_level: std.log.Level = .debug;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = &gpa.allocator;

    const rev: []const string = if (git.rev_HEAD(alloc, std.fs.cwd()) catch null) |h| &.{ ".", h[0..9] } else &.{ "", "" };
    const con: string = if (docker.amInside(alloc) catch false) ".docker" else "";
    version = try std.fmt.allocPrint(alloc, "{s}{s}{s}{s}.zig{}", .{ options.version, rev[0], rev[1], con, builtin.zig_version });
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

    try db.connect(alloc, flag.getSingle("db") orelse "aquila.db");

    //

    signal.listenFor(std.os.linux.SIG.INT, handle_sig);
    signal.listenFor(std.os.linux.SIG.TERM, handle_sig);

    //

    try zfetch.init();
    defer zfetch.deinit();

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

    {
        const current = try db.Remote.all(alloc);
        std.debug.assert(oa2.clients.len >= current.len);
        var i: usize = 0;
        while (i < current.len) : (i += 1) {
            std.debug.assert(std.mem.eql(u8, oa2.clients[i].provider.domain(), current[i].domain));
        }
        while (i < oa2.clients.len) : (i += 1) {
            const idp = oa2.clients[i].provider;
            _ = try db.Remote.create(alloc, oa2IdToRemoTy(idp.id), idp.domain());
        }
    }

    const port = try std.fmt.parseUnsigned(u16, flag.getSingle("port") orelse "8000", 10);
    std.log.info("starting server on port {d}", .{port});
    try http.listenAndServe(
        alloc,
        try std.net.Address.parseIp("0.0.0.0", port),
        {},
        comptime handler.getHandler(oa2),
    );
}

fn handle_sig() void {
    db.close();
    std.os.exit(0);
}

fn oa2IdToRemoTy(id: string) db.Remote.Type {
    if (std.mem.eql(u8, id, "github.com")) return .github;

    std.debug.panic("unsupported client provider: {s}", .{id});
}

pub fn pek_get_user_path(alloc: *std.mem.Allocator, uid: ulid.ULID) !string {
    const user = try db.User.byKey(alloc, .uuid, uid);
    return try std.fmt.allocPrint(alloc, "{d}/{s}", .{ user.?.provider, user.?.name });
}

pub fn pek_version_pkg_path(alloc: *std.mem.Allocator, vers: db.Version) !string {
    const pkg = try db.Package.byKey(alloc, .uuid, vers.p_for);
    const user = try db.User.byKey(alloc, .uuid, pkg.?.owner);
    return try std.fmt.allocPrint(alloc, "{d}/{s}/{s}", .{ user.?.provider, user.?.name, pkg.?.name });
}

pub fn pek_version_pkg_stars(alloc: *std.mem.Allocator, vers: db.Version) !u64 {
    const pkg = try db.Package.byKey(alloc, .uuid, vers.p_for);
    return pkg.?.star_count;
}

pub fn pek_version_pkg_description(alloc: *std.mem.Allocator, vers: db.Version) !string {
    const pkg = try db.Package.byKey(alloc, .uuid, vers.p_for);
    return pkg.?.description;
}

pub fn pek_tree_url(alloc: *std.mem.Allocator, remo: db.Remote, repo: string, commit: string) !string {
    return switch (remo.type) {
        .github => try std.fmt.allocPrint(alloc, "https://github.com/{s}/tree/{s}", .{ repo, commit }),
    };
}

pub fn pek_fix_bytes(alloc: *std.mem.Allocator, size: u64) !string {
    return try extras.fmtByteCountIEC(alloc, size);
}
