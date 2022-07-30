const std = @import("std");
const string = []const u8;
const builtin = @import("builtin");
const WaitGroup = @import("./WaitGroup.zig");
const db = @import("./db/_db.zig");
const job_doer = @import("./job_doer.zig");

pub var should_run = true;
pub var control = WaitGroup{};
pub var pickup_tracker = WaitGroup{};

var run_tracker = WaitGroup{};

pub fn start(allocator: std.mem.Allocator) void {
    control.start();
    defer control.finish();

    while (should_run) {
        if (pickup_tracker.isDone()) {
            // no work found, sleep 5s so we're not hogging cpu
            std.time.sleep(std.time.ns_per_s * 5);
            continue;
        }

        // find queued jobs and launch them
        // TODO add a way to limit the number of jobs
        // TODO add integration with docker swarm and checking available workers
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const alloc = arena.allocator();

        const candidates = db.Job.byKeyAll(alloc, .state, .queued, .asc) catch continue;
        for (candidates) |item| {
            const dupe = allocator.create(db.Job) catch continue;
            dupe.* = item;
            (std.Thread.spawn(.{}, job_doer.start, .{ allocator, dupe, &run_tracker }) catch {
                allocator.destroy(dupe);
                continue;
            }).detach();
            run_tracker.start();
            pickup_tracker.finish();
        }
    }

    // wait for all running jobs to finish
    // TODO pause docker containers, resume again on startup
    run_tracker.wait();
}
