const std = @import("std");
const string = []const u8;
const stringL = []const string;
const stringLL = []const stringL;
const db = @import("./db/_db.zig");
const UrlValues = @import("UrlValues");
const zfetch = @import("zfetch");
const root = @import("root");
const docker = @import("./docker.zig");
const WaitGroup = @import("./WaitGroup.zig");

// https://hub.docker.com/r/nektro/qemu-system/tags
// https://github.com/nektro/docker-qemu-system/blob/master/Dockerfile
fn getImageName(arch: db.Job.Arch.Tag) string {
    return switch (arch) {
        .x86_64 => "nektro/qemu-system:x86_64@sha256:0b1ca00607c57d3c8d515a8af9abbbf7ae504c733d75cdb768dcfef1ac491f3d",
    };
}

pub const Mount = struct {
    Type: string = "bind",
    Source: string,
    Destination: string,
    Mode: string = "ro",
    RW: bool = false,
    Propagation: string = "rprivate",
};

pub const DeviceMapping = struct {
    PathOnHost: string,
    PathInContainer: string,
    CgroupPermissions: string = "rwm",
};

// pub fn start(allocator: std.mem.Allocator, job: *const db.Job) Error!void {
pub fn start(allocator: std.mem.Allocator, job: *db.Job, run_tracker: *std.Thread.Semaphore) !void {
    defer job.destroy(allocator);
    defer run_tracker.post();
    std.log.info("started job {} for {d} - {s} - {s}", .{ job.uuid, job.package, job.arch, job.os });

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    try job.update(alloc, .state, .pending);

    // get host path of /images mount
    const host_images_path: string = blk: {
        const own_id = try ownDockerId(alloc);
        const json = try docker.containerInspect(alloc, own_id);
        const mounts = json.root.Object.get("Mounts").?.Array;
        for (mounts.items) |item| {
            if (std.mem.eql(u8, item.Object.get("Destination").?.String, "/images")) {
                break :blk item.Object.get("Source").?.String;
            }
        }
        @panic("/images mount not found");
    };

    // start qemu-system docker container, get id
    const image = getImageName(job.arch.tag);
    const env = try std.fmt.allocPrint(alloc, "image=/images/{s}/{s}/stage4.qcow2", .{ @tagName(job.arch.tag), @tagName(job.os.tag) });
    const bind = try std.fmt.allocPrint(alloc, "{s}:/images:ro", .{host_images_path});
    const id = blk: {
        const tree = try docker.containerCreate(alloc, .{
            .Image = image,
            .Env = &[_]string{env},
            .Volumes = .{
                .@"/images" = .{},
            },
            .HostConfig = .{
                .Binds = &[_]string{bind},
                .Devices = &[_]DeviceMapping{.{ .PathOnHost = "/dev/kvm", .PathInContainer = "/dev/kvm" }},
            },
            .Mounts = &[_]Mount{.{ .Source = host_images_path, .Destination = "/images" }},
        });
        break :blk tree.root.Object.get("Id").?.String;
    };

    // start container
    try docker.containerStart(alloc, id);

    // connect container to aquila network
    //
    {
        const own_id = try ownDockerId(alloc);
        const json = try docker.containerInspect(alloc, own_id);
        const network_id = json.root.Object.get("NetworkSettings").?.Object.get("Networks").?.Object.values()[0].Object.get("NetworkID").?.String;
        try docker.networkConnect(alloc, network_id, id);
    }

    // wait for ssh to be available
    {
        // TODO do this better
        std.time.sleep(std.time.ns_per_s * 15);
    }

    // ssh into system and store results
    {
        var data_dir = try std.fs.cwd().openDir(root.datadirpath, .{});
        defer data_dir.close();

        // TODO put this file in a better place
        var job_file = try data_dir.createFile("job.jsonl", .{});
        defer job_file.close();
        const w = job_file.writer();

        const pkg = try db.Package.byKey(alloc, .id, job.package);
        const clone_url = try pkg.?.cloneUrl(alloc);
        const folder_name = std.mem.splitBackwards(u8, clone_url, "/").next();
        const work_name = try std.fmt.allocPrint(alloc, "workspace/{s}", .{folder_name});
        const host_name = id[0..12];

        try jsonWriteLine(w, .{ .package = job.package });
        try jsonWriteLine(w, .{ .at = job.commit });
        try jsonWriteLine(w, .{ .arch = job.arch });
        try jsonWriteLine(w, .{ .os = job.os });

        // TODO fail job if a command exits with non-0
        for (printSysInfoCmd(job.os)) |item| {
            try doJobLine(allocator, w, host_name, item);
        }
        try doJobLine(allocator, w, host_name, &.{ "cd", "llvm-project", "&&", "git", "describe", "--tags" });
        try doJobLine(allocator, w, host_name, &.{ "cd", "zig", "&&", "git", "describe", "--tags" });
        try doJobLine(allocator, w, host_name, &.{ "cd", "workspace", "&&", "git", "clone", clone_url });
        try doJobLine(allocator, w, host_name, &.{ "cd", work_name, "&&", "~/zigmod", "ci" });
        try doJobLine(allocator, w, host_name, &.{ "cd", work_name, "&&", "~/zig/build/zig", "build" });
        try doJobLine(allocator, w, host_name, &.{ "cd", work_name, "&&", "~/zig/build/zig", "build", "test" });
        _ = try execRemoteCmd(allocator, host_name, poweroffCmd(job.os), null);
    }

    // remove container
    try docker.containerDelete(alloc, id);

    // we're done!
    try job.update(alloc, .state, .success);

    std.log.info("job done: {s}", .{job.uuid});
}

fn ownDockerId(alloc: std.mem.Allocator) !string {
    var file = try std.fs.cwd().openFile("/etc/hostname", .{});
    defer file.close();
    const content = try file.reader().readAllAlloc(alloc, std.math.maxInt(usize));
    return std.mem.trimRight(u8, content, "\n");
}

fn jsonWriteLine(writer: std.fs.File.Writer, value: anytype) !void {
    try std.json.stringify(value, .{ .whitespace = .{ .indent = .None, .separator = false } }, writer);
    try writer.writeByte('\n');
}

fn printSysInfoCmd(os: db.Job.Os) stringLL {
    return switch (os.tag) {
        .debian => &.{
            &.{ "uname", "-a" },
            &.{"free"},
        },
    };
}

fn poweroffCmd(os: db.Job.Os) stringL {
    return switch (os.tag) {
        .debian => &[_]string{ "shutdown", "-h", "now" },
    };
}

fn doJobLine(allocator: std.mem.Allocator, writer: std.fs.File.Writer, host_name: string, args: stringL) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var list = std.ArrayList(u8).init(alloc);
    errdefer list.deinit();

    try jsonWriteLine(writer, .{ .cmd = args });
    const cmd = try execRemoteCmd(alloc, host_name, args, &list);

    // TODO print output as it happens
    // TODO send lines to websocket
    var fbs = std.io.fixedBufferStream(list.toOwnedSlice());
    const r = fbs.reader();
    while (try r.readUntilDelimiterOrEofAlloc(alloc, '\n', std.math.maxInt(usize))) |line| {
        // TODO filter out ansi escapse
        // TODO skip if line length is >0 before and =0 after transform
        // TODO filter out `Warning: Permanently added '[5332fa241874]:2222' (ED25519) to the list of known hosts.` messages
        try jsonWriteLine(writer, [_]string{std.mem.trimRight(u8, line, "\r")});
    }
    try jsonWriteLine(writer, cmd);
}

const CmdResult = struct {
    exit: u32,
    duration: u64,
};

fn execRemoteCmd(allocator: std.mem.Allocator, host_name: string, args: stringL, stdout: ?*std.ArrayList(u8)) !CmdResult {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // construct args
    var list = std.ArrayList(string).init(alloc);
    errdefer list.deinit();
    try list.ensureTotalCapacityPrecise(16 + args.len);
    list.appendSliceAssumeCapacity(&.{"ssh"});
    list.appendSliceAssumeCapacity(&.{ "-o", "StrictHostKeychecking=no" });
    list.appendSliceAssumeCapacity(&.{ "-o", "ConnectionAttempts=1" });
    list.appendSliceAssumeCapacity(&.{ "-o", "RequestTTY=no" });
    list.appendSliceAssumeCapacity(&.{ "-o", "PreferredAuthentications=publickey" });
    list.appendSliceAssumeCapacity(&.{ "-o", "UserKnownHostsFile=/dev/null" });
    list.appendSliceAssumeCapacity(&.{ "-o", "BatchMode=yes" });
    list.appendSliceAssumeCapacity(&.{ "-p", "2222" });
    list.appendAssumeCapacity(try std.fmt.allocPrint(alloc, "root@{s}", .{host_name}));
    list.appendSliceAssumeCapacity(args);

    // exec ssh
    const begin = @intCast(u64, std.time.milliTimestamp());
    var child = std.ChildProcess.init(list.toOwnedSlice(), alloc);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // collect output
    if (stdout) |_| {
        try collectOutputPosix(child, stdout.?, stdout.?, std.math.maxInt(usize));
    }
    const term = try child.wait();
    const end = @intCast(u64, std.time.milliTimestamp());
    return CmdResult{
        .exit = @intCast(u32, term.Exited),
        .duration = (end - begin) / 1000,
    };
}

// picked out from std.ChildProcess internal code
fn collectOutputPosix(child: std.ChildProcess, stdout: *std.ArrayList(u8), stderr: *std.ArrayList(u8), max_output_bytes: usize) !void {
    const os = std.os;
    var poll_fds = [_]os.pollfd{
        .{ .fd = child.stdout.?.handle, .events = os.POLL.IN, .revents = undefined },
        .{ .fd = child.stderr.?.handle, .events = os.POLL.IN, .revents = undefined },
    };

    var dead_fds: usize = 0;
    // We ask for ensureTotalCapacity with this much extra space. This has more of an
    // effect on small reads because once the reads start to get larger the amount
    // of space an ArrayList will allocate grows exponentially.
    const bump_amt = 512;

    const err_mask = os.POLL.ERR | os.POLL.NVAL | os.POLL.HUP;

    while (dead_fds < poll_fds.len) {
        const events = try os.poll(&poll_fds, std.math.maxInt(i32));
        if (events == 0) continue;

        var remove_stdout = false;
        var remove_stderr = false;
        // Try reading whatever is available before checking the error
        // conditions.
        // It's still possible to read after a POLL.HUP is received, always
        // check if there's some data waiting to be read first.
        if (poll_fds[0].revents & os.POLL.IN != 0) {
            // stdout is ready.
            const new_capacity = std.math.min(stdout.items.len + bump_amt, max_output_bytes);
            try stdout.ensureTotalCapacity(new_capacity);
            const buf = stdout.unusedCapacitySlice();
            if (buf.len == 0) return error.StdoutStreamTooLong;
            const nread = try os.read(poll_fds[0].fd, buf);
            stdout.items.len += nread;

            // Remove the fd when the EOF condition is met.
            remove_stdout = nread == 0;
        } else {
            remove_stdout = poll_fds[0].revents & err_mask != 0;
        }

        if (poll_fds[1].revents & os.POLL.IN != 0) {
            // stderr is ready.
            const new_capacity = std.math.min(stderr.items.len + bump_amt, max_output_bytes);
            try stderr.ensureTotalCapacity(new_capacity);
            const buf = stderr.unusedCapacitySlice();
            if (buf.len == 0) return error.StderrStreamTooLong;
            const nread = try os.read(poll_fds[1].fd, buf);
            stderr.items.len += nread;

            // Remove the fd when the EOF condition is met.
            remove_stderr = nread == 0;
        } else {
            remove_stderr = poll_fds[1].revents & err_mask != 0;
        }

        // Exclude the fds that signaled an error.
        if (remove_stdout) {
            poll_fds[0].fd = -1;
            dead_fds += 1;
        }
        if (remove_stderr) {
            poll_fds[1].fd = -1;
            dead_fds += 1;
        }
    }
}
