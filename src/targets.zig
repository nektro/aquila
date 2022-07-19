const std = @import("std");
const Arch = std.Target.Cpu.Arch;

pub const debian = std.ComptimeStringMap(?Arch, .{
    .{ "amd64", .x86_64 },
});

pub const alpine = std.ComptimeStringMap(?Arch, .{
    .{ "x86_64", .x86_64 },
});

pub const freebsd = std.ComptimeStringMap(?Arch, .{
    .{ "amd64", .x86_64 },
});

pub const netbsd = std.ComptimeStringMap(?Arch, .{
    .{ "amd64", .x86_64 },
});
