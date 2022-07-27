const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const extras = @import("extras");
const root = @import("root");
const zigmod = @import("zigmod");
const git = @import("git");
const ox = @import("ox").www;

const db = @import("./../db/_db.zig");
const cmisc = @import("./../cmisc.zig");

const _internal = @import("./_internal.zig");

pub const Args: ?type = null;

pub fn get(_: void, response: *http.Response, request: http.Request, captures: ?*const anyopaque) !void {
    _ = captures;
    try ox.assert(!root.disable_import_repo, response, .forbidden, "error: importing a repository is temporarily disabled.", .{});

    const alloc = request.arena;
    const u = try _internal.getUser(response, request);

    const q = try request.context.uri.queryParameters(alloc);
    const repo = q.get("repo") orelse return error.HttpNoOp;

    for (try u.packages(alloc)) |item| {
        try ox.assert(!std.mem.eql(u8, item.remote_name, repo), response, .bad_request, "error: repository '{s}' has already been initialized.", .{repo});
    }

    const r = try u.remote(alloc);

    //

    const details = r.getRepo(alloc, repo) catch return ox.fail(response, .internal_server_error, "error: fetching repo from remote failed", .{});
    try ox.assert(std.mem.eql(u8, details.owner, u.name), response, .forbidden, "error: you do not have the authority to manage this package", .{});

    var path = std.mem.span(cmisc.mkdtemp(try alloc.dupeZ(u8, "/tmp/XXXXXX")));

    const result1 = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .cwd = path,
        .argv = &.{ "git", "clone", "--recursive", details.clone_url, "." },
        .max_output_bytes = std.math.maxInt(usize),
    });
    try ox.assert(result1.term == .Exited, response, .bad_request, "error: executing git clone failed: {}", .{result1.term});
    try ox.assert(result1.term.Exited == 0, response, .bad_request, "error: executing tar failed with exit code: {d}\n{s}", .{ result1.term.Exited, result1.stderr });

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    const modfile = zigmod.ModFile.from_dir(alloc, dir) catch |err| return ox.fail(response, .bad_request, "error: parsing zig.mod failed: {s}", .{@errorName(err)});
    const name = modfile.name;
    const license = modfile.yaml.get_string("license");
    const mdesc = modfile.yaml.get("description");
    const desc = if (mdesc) |_| mdesc.?.string else details.description;
    const deps = modfile.deps;
    const rootdeps = modfile.rootdeps;
    const builddeps = modfile.builddeps;

    const commit = try git.getHEAD(alloc, dir);
    try dir.deleteTree(".git");
    const unpackedsize = try extras.dirSize(alloc, dir);

    const cachepath = try std.fs.path.join(alloc, &.{ path, ".zigmod", "deps" });
    zigmod.commands.ci.do(alloc, cachepath, dir) catch |err| return ox.fail(response, .internal_server_error, "error: zigmod ci failed: {s}", .{@errorName(err)});
    try dir.deleteFile("deps.zig");
    const totalsize = try extras.dirSize(alloc, dir);
    try dir.deleteTree(".zigmod");

    const filelist = try extras.fileList(alloc, dir);
    try ox.assert(filelist.len > 0, response, .internal_server_error, "error: found no files in repo", .{});

    const tarpath = try std.mem.concat(alloc, u8, &.{ path, ".tar.gz" });

    // TODO use zig to do .tar.gz
    // TODO migrate to using .zip
    const argv = try _internal.mergeSlices(alloc, string, &.{ "tar", "-czf", tarpath }, filelist);

    const result2 = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .argv = argv,
        .cwd = path,
    });
    try ox.assert(result2.term == .Exited, response, .internal_server_error, "error: executing tar failed: {}", .{result2.term});
    try ox.assert(result2.term.Exited == 0, response, .internal_server_error, "error: executing tar failed with exit code: {d}\n{s}", .{ result2.term.Exited, result2.stderr });

    const tarfile = try std.fs.cwd().openFile(tarpath, .{});
    defer tarfile.close();

    const destdirpath = try std.fs.path.join(alloc, &.{ root.datadirpath, "packages", try u.uuid.toString(alloc), details.id });
    try std.fs.cwd().makePath(destdirpath);

    const destpath = try std.fs.path.join(alloc, &.{ destdirpath, try std.mem.concat(alloc, u8, &.{ "latest", ".tar.gz" }) });
    try _internal.rename(tarpath, destpath);
    const tarsize = try extras.fileSize(std.fs.cwd(), destpath);
    const tarhash = try extras.hashFile(alloc, std.fs.cwd(), destpath, .sha256);
    const readme = (_internal.readFileContents(dir, alloc, "README.md") catch null) orelse "";

    var p = try db.Package.create(alloc, u, name, r, details.id, repo, desc, license, details.star_count, details.clone_url);
    var v = try db.Version.create(alloc, p, commit, unpackedsize, totalsize, filelist, tarsize, tarhash, deps, rootdeps, builddeps, readme);

    try std.fs.cwd().deleteTree(path);

    //

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

    try ox.redirectTo(response, try std.mem.concat(alloc, u8, &.{ ".", desturl }));
}
