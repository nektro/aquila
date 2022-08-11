const std = @import("std");
const string = []const u8;
const builtin = @import("builtin");
const db = @import("./db/_db.zig");
const job_doer = @import("./job_doer.zig");

pub var should_run = true;
pub var sem_pickup = std.Thread.Semaphore{ .permits = 0 };
pub var sem_runner = std.Thread.Semaphore{ .permits = 0 };


pub fn start(allocator: std.mem.Allocator) void {
    while (should_run) {
        sem_pickup.wait();
        sem_runner.wait();

        // find queued jobs and launch them
        // TODO add integration with docker swarm and checking available workers
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const alloc = arena.allocator();

        const candidate = db.Job.byKey(alloc, .state, .queued) catch continue;
        const dupe = candidate.?.dupe(allocator) catch continue;
        (std.Thread.spawn(.{}, job_doer.start, .{ allocator, dupe, &sem_runner }) catch continue).detach();
    }
}

pub fn wait() void {
    while (sem_runner.permits > 0) {
        sem_runner.wait();
    }
}
