const std = @import("std");
const string = []const u8;
const http = @import("apple_pie");
const json = @import("json");
const extras = @import("extras");
const root = @import("root");
const zigmod = @import("zigmod");
const git = @import("git");

const db = @import("./../db/_db.zig");
const cmisc = @import("./../cmisc.zig");

const _internal = @import("./_internal.zig");

pub fn post(_: void, response: *http.Response, request: http.Request, args: struct { remote: u64, user: string, package: string }) !void {
    const alloc = request.arena;
    const r = try _internal.reqRemote(request, response, args.remote);
    const u = try _internal.reqUser(request, response, r, args.user);
    var p = try _internal.reqPackage(request, response, u, args.package);

    const q = try request.context.uri.queryParameters(alloc);
    const secret = q.get("secret") orelse return _internal.fail(response, .not_found, "secret query parameter not found", .{});
    try _internal.assert(std.mem.eql(u8, secret, p.hook_secret), response, .forbidden, "error: webhook secret does not match", .{});

    const body = request.body();
    try _internal.assert(body.len > 0, response, .bad_request, "error: no body", .{});
    const val = try json.parse(alloc, body);

    const headers = try request.headers(alloc);
    switch (r.type) {
        .github => {
            const event_type = headers.get("X-GitHub-Event") orelse "";
            if (std.mem.eql(u8, event_type, "ping")) return try response.writer().writeAll("Pong!\n");
            try _internal.assert(std.mem.eql(u8, event_type, "push"), response, .bad_request, "error: unknown webhook event type: {s}", .{event_type});

            const ref = val.getT("ref", .String) orelse return _internal.fail(response, .bad_request, "error: webhook json key not found: ref", .{});
            const branch = val.getT(.{ "repository", "default_branch" }, .String) orelse return _internal.fail(response, .bad_request, "error: webhook json key not found: repository.default_branch", .{});
            try _internal.assert(std.mem.eql(u8, ref, try std.fmt.allocPrint(alloc, "refs/heads/{s}", .{branch})), response, .bad_request, "error: push even was not to default branch: {s}", .{ref});
        },
        .gitea => {
            const event_type = headers.get("X-Gitea-Event") orelse "";
            try _internal.assert(std.mem.eql(u8, event_type, "push"), response, .bad_request, "error: unknown webhook event type: {s}", .{event_type});

            const ref = val.getT("ref", .String) orelse return _internal.fail(response, .bad_request, "error: webhook json key not found: ref", .{});
            const branch = val.getT(.{ "repository", "default_branch" }, .String) orelse return _internal.fail(response, .bad_request, "error: webhook json key not found: repository.default_branch", .{});
            try _internal.assert(std.mem.eql(u8, ref, try std.fmt.allocPrint(alloc, "refs/heads/{s}", .{branch})), response, .bad_request, "error: push even was not to default branch: {s}", .{ref});
        },
    }

    const details: db.Remote.RepoDetails = switch (r.type) {
        .github => try r.parseDetails(alloc, val.get("repository") orelse return _internal.fail(response, .internal_server_error, "error: webhook json key not found: repository", .{})),
        .gitea => try r.parseDetails(alloc, val.get("repository") orelse return _internal.fail(response, .internal_server_error, "error: webhook json key not found: repository", .{})),
    };
    try _internal.assert(std.mem.eql(u8, details.owner, u.name), response, .forbidden, "error: you do not have the authority to manage this package", .{});

    var path = std.mem.span(cmisc.mkdtemp(try alloc.dupeZ(u8, "/tmp/XXXXXX")));
    const result1 = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .cwd = path,
        .argv = &.{ "git", "clone", "--recursive", details.clone_url, "." },
        .max_output_bytes = std.math.maxInt(usize),
    });
    try _internal.assert(result1.term == .Exited, response, .internal_server_error, "error: executing git clone failed: {}", .{result1.term});
    try _internal.assert(result1.term.Exited == 0, response, .internal_server_error, "error: executing tar failed with exit code: {d}\n{s}", .{ result1.term.Exited, result1.stderr });

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    const modfile = zigmod.ModFile.from_dir(alloc, dir) catch |err| return _internal.fail(response, .bad_request, "error: parsing zig.mod failed: {s}", .{@errorName(err)});
    const deps = modfile.deps;
    const rootdeps = modfile.rootdeps;
    const builddeps = modfile.builddeps;

    const commit = try git.getHEAD(alloc, dir);
    try _internal.assert((try p.findVersionBy(alloc, .commit_to, commit)) == null, response, .bad_request, "error: Version at this commit already created", .{});

    try dir.deleteTree(".git");
    const unpackedsize = try extras.dirSize(alloc, dir);

    const cachepath = try std.fs.path.join(alloc, &.{ path, ".zigmod", "deps" });
    zigmod.commands.ci.do(alloc, cachepath, dir) catch |err| return _internal.fail(response, .internal_server_error, "error: zigmod ci failed: {s}", .{@errorName(err)});
    try dir.deleteFile("deps.zig");
    const totalsize = try extras.dirSize(alloc, dir);
    try dir.deleteTree(".zigmod");

    const filelist = try extras.fileList(alloc, dir);
    try _internal.assert(filelist.len > 0, response, .internal_server_error, "error: found no files in repo", .{});

    const tarpath = try std.mem.concat(alloc, u8, &.{ path, ".tar.gz" });

    // TODO use zig to do .tar.gz
    // TODO migrate to using .zip
    const argv = try _internal.mergeSlices(alloc, string, &.{ "tar", "-czf", tarpath }, filelist);

    const result2 = try std.ChildProcess.exec(.{
        .allocator = alloc,
        .argv = argv,
        .cwd = path,
    });
    try _internal.assert(result2.term == .Exited, response, .internal_server_error, "error: executing tar failed: {}", .{result2.term});
    try _internal.assert(result2.term.Exited == 0, response, .internal_server_error, "error: executing tar failed with exit code: {d}\n{s}", .{ result2.term.Exited, result2.stderr });

    const tarfile = try std.fs.cwd().openFile(tarpath, .{});
    defer tarfile.close();

    const destdirpath = try std.fs.path.join(alloc, &.{ root.datadirpath, "packages", try u.uuid.toString(alloc), details.id });
    try std.fs.cwd().makePath(destdirpath);

    const destpath = try std.fs.path.join(alloc, &.{ destdirpath, try std.mem.concat(alloc, u8, &.{ commit, ".tar.gz" }) });
    try _internal.rename(tarpath, destpath);
    try std.fs.cwd().deleteTree(path);
    const tarsize = try extras.fileSize(std.fs.cwd(), destpath);
    const tarhash = try extras.hashFile(alloc, std.fs.cwd(), destpath, .sha256);
    const readme = (_internal.readFileContents(dir, alloc, "README.md") catch null) orelse "";

    var v = try db.Version.create(alloc, p, commit, unpackedsize, totalsize, filelist, tarsize, tarhash, deps, rootdeps, builddeps, readme);
    try p.update(alloc, .license, modfile.yaml.get_string("license"));
    try p.update(alloc, .description, modfile.yaml.get_string("description"));
    try p.update(alloc, .star_count, details.star_count);

    const old_v = try p.getLatestValid(alloc);
    try v.setVersion(alloc, u, old_v.real_major, old_v.real_minor + 1);
    try p.setLatest(alloc, v);

    try response.writer().print("https://{s}/{d}/{s}/{s}/v{d}.{d} is now live!\n", .{ root.domain, r.id, u.name, p.name, v.real_major, v.real_minor });
}
