const std = @import("std");

const __sighandler_t = ?fn (c_int) callconv(.C) void;
extern fn signal(__sig: c_int, __handler: __sighandler_t) __sighandler_t;

pub fn listenFor(sig: c_int, comptime f: fn () void) void {
    _ = signal(sig, Handler(f).handle);
}

fn Handler(comptime f: fn () void) type {
    return struct {
        pub fn handle(s: c_int) callconv(.C) void {
            std.debug.print("\n", .{});
            std.log.info("caught signal: {d}", .{s});
            f();
        }
    };
}
