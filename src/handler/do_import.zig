const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const extras = @import("extras");
const root = @import("root");
const zigmod = @import("zigmod");

const db = @import("./../db/_db.zig");
const git = @import("./../git.zig");

const _internal = @import("./_internal.zig");

extern "c" fn mkdtemp(template: [*:0]const u8) [*:0]u8;

pub fn get(_: void, response: *http.Response, request: http.Request, args: struct {}) !void {
    _ = args;

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);

    const q = try request.context.url.queryParameters(alloc);
    const repo = q.get("repo") orelse return error.HttpNoOp;

    for (try u.packages(alloc)) |item| {
        try _internal.assert(!std.mem.eql(u8, item.remote_name, repo), response, "error: repository '{s}' has already been initialized.", .{repo});
    }

    const r = try u.remote(alloc);
    const details = r.getRepo(alloc, repo) catch return _internal.fail(response, "error: fetching repo from remote failed\n", .{});

    var path = std.mem.span(mkdtemp(try alloc.dupeZ(u8, "/tmp/XXXXXX")));

    const result1 = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .cwd = path,
        .argv = &.{ "git", "clone", "--recursive", details.clone_url, "." },
        .max_output_bytes = std.math.maxInt(usize),
    });
    try _internal.assert(result1.term == .Exited, response, "error: executing git clone failed: {}\n", .{result1.term});
    try _internal.assert(result1.term.Exited == 0, response, "error: executing tar failed with exit code: {d}\n{s}", .{ result1.term.Exited, result1.stderr });

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    const modfile = zigmod.ModFile.from_dir(alloc, dir) catch |err| return _internal.fail(response, "error: parsing zig.mod failed: {s}\n", .{@errorName(err)});
    const name = modfile.name;
    const license = modfile.yaml.get_string("license");
    const mdesc = modfile.yaml.get("description");
    const desc = if (mdesc) |_| mdesc.?.string else details.description;
    const deps = modfile.deps;
    const rootdeps = modfile.rootdeps;
    const builddeps = modfile.builddeps;

    const commit = try git.rev_HEAD(alloc, dir);
    try dir.deleteTree(".git");
    const unpackedsize = try _internal.dirSize(alloc, path);

    try _internal.assert(try extras.doesFileExist(dir, "zigmod.lock"), response, "error: repository '{s}' does not contain a zigmod.lock file.\n", .{repo});
    const cachepath = try std.fs.path.join(alloc, &.{ ".zigmod", "deps" });
    zigmod.commands.ci.do(cachepath, dir) catch |err| return _internal.fail(response, "error: zigmod ci failed: {s}\n", .{@errorName(err)});
    try dir.deleteFile("deps.zig");
    const totalsize = try _internal.dirSize(alloc, path);
    try dir.deleteTree(".zigmod");

    const filelist = try _internal.fileList(alloc, path);
    try _internal.assert(filelist.len > 0, response, "error: found no files in repo\n", .{});

    const tarpath = try std.mem.concat(alloc, u8, &.{ path, ".tar.gz" });

    // TODO use zig to do .tar.gz
    const argv = try _internal.mergeSlices(alloc, string, &.{ "tar", "-czf", tarpath }, filelist);
    std.log.warn("{s}", .{argv});

    const result2 = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .argv = argv,
        .cwd = path,
    });
    try _internal.assert(result2.term == .Exited, response, "error: executing tar failed: {}\n", .{result2.term});
    try _internal.assert(result2.term.Exited == 0, response, "error: executing tar failed with exit code: {d}\n{s}", .{ result2.term.Exited, result2.stderr });

    const tarfile = try std.fs.cwd().openFile(tarpath, .{});
    defer tarfile.close();

    const destdirpath = try std.fs.path.join(alloc, &.{ root.datadirpath, "packages", try u.uuid.toString(alloc), details.id });
    try std.fs.cwd().makePath(destdirpath);

    const destpath = try std.fs.path.join(alloc, &.{ destdirpath, try std.mem.concat(alloc, u8, &.{ commit, ".tar.gz" }) });
    try std.fs.cwd().rename(tarpath, destpath);
    try std.fs.cwd().deleteTree(path);
    const tarsize = try extras.fileSize(std.fs.cwd(), destpath);
    const tarhash = try extras.hashFile(alloc, std.fs.cwd(), destpath, .sha256);

    var p = try db.Package.create(alloc, u, name, r, details.id, repo, desc, license, details.star_count);
    var v = try db.Version.create(alloc, p, commit, unpackedsize, totalsize, filelist, tarsize, tarhash, deps, rootdeps, builddeps);
    try v.setVersion(alloc, u, 0, 1);
    try p.setLatest(alloc, v);

    const desturl = try std.mem.concat(alloc, u8, &.{ "/", try std.fmt.allocPrint(alloc, "{d}", .{r.id}), "/", u.name, "/", name });

    _ = try r.installWebhook(
        alloc,
        u,
        details.id,
        repo,
        try std.mem.concat(alloc, u8, &.{ "https://", root.domain, desturl, "/hook?secret=", p.hook_secret }),
    );

    try response.headers.put("Location", try std.mem.concat(alloc, u8, &.{ ".", desturl }));
    try response.writeHeader(.found);
}
