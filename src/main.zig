const std = @import("std");
const string = []const u8;
const builtin = @import("builtin");
const http = @import("apple_pie");
const extras = @import("extras");
const oauth2 = @import("oauth2");
const flag = @import("flag");
const zfetch = @import("zfetch");
const zigmod = @import("zigmod");
const git = @import("git");
const ox = @import("ox");
const docker = @import("docker");
const signal = @import("signal");

const handler = @import("./handler/_handler.zig");
const db = @import("./db/_db.zig");
const runner = @import("./runner.zig");

pub const build_options = @import("build_options");
pub const files = @import("self/files");

pub const name = "Aquila";
pub const log_level: std.log.Level = .debug;
pub const oxwww_allowjson = true;

pub var version: string = "";
pub var datadirpath: string = "";
pub var domain: string = "";
pub var disable_import_repo = false;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    const alloc = gpa.allocator();

    {
        var sbuilder = std.ArrayList(u8).init(alloc);
        const w = sbuilder.writer();
        try w.writeAll(build_options.version);

        if (std.mem.eql(u8, build_options.version, "dev")) {
            if (git.getHEAD(alloc, std.fs.cwd()) catch null) |h| {
                try w.print(".{s}", .{h[0..9]});
            }
        }
        if (docker.amInside() catch false) try w.writeAll(".docker");
        try w.print(".zig{}", .{builtin.zig_version});
        version = sbuilder.toOwnedSlice();
    }

    std.log.info("Starting {s} {s}", .{ name, version });

    oauth2.providers.github.id = "github.com";
    oauth2.providers.github.scope = try std.mem.join(alloc, " ", &.{ oauth2.providers.github.scope, "write:repo_hook" });

    //

    flag.init(alloc);
    defer flag.deinit();

    try flag.addSingle("domain");
    try flag.addSingle("db");
    try flag.addSingle("port");
    try flag.addMulti("oauth2-client");
    try flag.addSingle("disable-import-repo");
    try flag.addSingle("ci");

    _ = try flag.parse(.double);
    try flag.parseEnv();

    //

    const dbpath = flag.getSingle("db") orelse "aquila.db";
    if (!(try extras.doesFileExist(std.fs.cwd(), dbpath))) {
        (try std.fs.cwd().createFile(dbpath, .{})).close();
    }
    datadirpath = try std.fs.cwd().realpathAlloc(alloc, dbpath);
    datadirpath = std.fs.path.dirname(datadirpath).?;
    try db.connect(alloc, dbpath);

    domain = flag.getSingle("domain") orelse @panic("missing required --domain flag");
    disable_import_repo = parseBoolFlag("disable-import-repo", false);

    //

    signal.listenFor(std.os.linux.SIG.INT, handle_sig);
    signal.listenFor(std.os.linux.SIG.TERM, handle_sig);

    //

    try zfetch.init();
    defer zfetch.deinit();

    try zigmod.init();
    defer zigmod.deinit();

    try handler.init(alloc);

    var clients = std.ArrayList(oauth2.Client).init(alloc);
    for (flag.getMulti("oauth2-client") orelse @panic("missing required --oauth2-client flag")) |item| {
        var iter = std.mem.split(u8, item, "|");
        const pid = iter.next().?;
        try clients.append(.{
            .provider = (try oauth2.providerById(alloc, pid)) orelse std.debug.panic("could not find provider by id: {s}", .{pid}),
            .id = iter.next().?,
            .secret = iter.next().?,
        });
    }

    const oa2 = oauth2.Handlers(struct {
        pub const Ctx = void;
        pub const isLoggedIn = ox.www.isLoggedIn;
        pub const doneUrl = "/dashboard";
        pub const saveInfo = handler.saveInfo;
    });
    oa2.clients = clients.toOwnedSlice();
    oa2.callbackPath = "/callback";

    {
        const current = try db.Remote.all(alloc, .asc);
        var map = std.StringHashMap(db.Remote).init(alloc);
        defer map.deinit();

        for (current) |item| {
            try map.put(item.domain, item);
        }
        for (oa2.clients) |_, i| {
            const idp = oa2.clients[i].provider;
            const entry = try map.getOrPut(idp.domain());
            if (entry.found_existing) {
                std.log.info("Remote #{d} is now live with {s}", .{ entry.value_ptr.id, idp.id });
                continue;
            }
            std.log.info("Remote +{d} is now live with {s}", .{ current.len + i + 1, idp.id });
            entry.value_ptr.* = try db.Remote.create(alloc, oa2IdToRemoTy(idp.id), idp.domain());
        }
    }

    //

    if (std.fmt.parseInt(u1, flag.getSingle("ci") orelse "0", 2)) {
        std.debug.assert(try docker.amInside());
        (try std.Thread.spawn(.{}, runner.start, .{alloc})).detach();
    }

    const port = try std.fmt.parseUnsigned(u16, flag.getSingle("port") orelse "8000", 10);
    std.log.info("starting server on port {d}", .{port});
    // TODO make this a Server instance and implement proper stop
    try http.listenAndServe(
        alloc,
        try std.net.Address.parseIp("0.0.0.0", port),
        {},
        comptime handler.getHandler(oa2),
    );
}

fn handle_sig() void {
    std.log.info("ensuring all CI jobs are in stopped state...", .{});
    runner.should_run = false;
    runner.control.wait();

    std.log.info("closing database connection...", .{});
    db.close();

    std.log.info("exiting safely...", .{});
    std.os.exit(0);
}

fn parseBoolFlag(comptime flagName: string, default: bool) bool {
    const v = flag.getSingle(flagName);
    const d = if (default) "1" else "0";
    const n = std.fmt.parseInt(u1, v orelse d, 10) catch @panic("failed to parse --" ++ flagName ++ " flag");
    return n == 1;
}

fn oa2IdToRemoTy(id: string) db.Remote.Type {
    if (std.mem.eql(u8, id, "github.com")) return .github;

    if (std.mem.indexOfScalar(u8, id, ',')) |ind| {
        if (std.meta.stringToEnum(db.Remote.Type, id[0..ind])) |t| {
            return t;
        }
        std.debug.panic("unsupported client provider: {s}", .{id[0..ind]});
    }

    std.debug.panic("unsupported client provider: {s}", .{id});
}

pub fn pek_get_user_path(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, uid: ox.sql.ULID) !void {
    const user = try db.User.byKey(alloc, .uuid, uid);
    try writer.print("{d}/{s}", .{ user.?.provider, user.?.name });
}

pub fn pek_version_pkg_path(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, vers: db.Version) !void {
    const pkg = try db.Package.byKey(alloc, .uuid, vers.p_for);
    const user = try db.User.byKey(alloc, .uuid, pkg.?.owner);
    try writer.print("{d}/{s}/{s}", .{ user.?.provider, user.?.name, pkg.?.name });
}

pub fn pek_version_pkg_stars(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, vers: db.Version) !void {
    const pkg = try db.Package.byKey(alloc, .uuid, vers.p_for);
    try writer.print("{d}", .{pkg.?.star_count});
}

pub fn pek_version_pkg_description(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, vers: db.Version) !void {
    const pkg = try db.Package.byKey(alloc, .uuid, vers.p_for);
    try writer.writeAll(pkg.?.description);
}

pub fn pek_tree_url(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, remo: db.Remote, repo: string, commit: string) !void {
    _ = alloc;
    return switch (remo.type) {
        .github => try writer.print("https://github.com/{s}/tree/{s}", .{ repo, commit }),
        .gitea => try writer.print("https://{s}/{s}/src/commit/{s}", .{ remo.domain, repo, commit }),
    };
}

pub fn pek_fix_bytes(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, size: u64) !void {
    _ = alloc;
    try writer.writeAll(try extras.fmtByteCountIEC(alloc, size));
}

pub fn pek_fix_dep(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, d: zigmod.Dep) !void {
    _ = alloc;
    try writer.writeAll(@tagName(d.type));
    try writer.print(" {s}", .{d.path});
    if (d.version.len > 0) try writer.print(" {s}", .{d.version});
}

pub fn pek_json_cstat(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, s: []const db.CountStat) !void {
    _ = alloc;
    try std.json.stringify(s, .{}, writer);
}

pub fn pek_json_tstat(alloc: std.mem.Allocator, writer: std.ArrayList(u8).Writer, s: []const db.TimeStat) !void {
    _ = alloc;
    try std.json.stringify(s, .{}, writer);
}
