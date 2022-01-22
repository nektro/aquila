const std = @import("std");
const string = []const u8;
const builtin = @import("builtin");
const deps = @import("./deps.zig");

pub fn build(b: *std.build.Builder) void {
    var target = b.standardTargetOptions(.{});
    if (target.isGnuLibC()) target.setGnuLibCVersion(2, 28, 0);

    b.setPreferredReleaseMode(.ReleaseSafe);
    const mode = b.standardReleaseOptions();

    const use_full_name = b.option(bool, "use-full-name", "") orelse false;
    const with_os_arch = b.fmt("-{s}-{s}", .{ @tagName(target.os_tag orelse builtin.os.tag), @tagName(target.cpu_arch orelse builtin.cpu.arch) });
    const exe_name = b.fmt("{s}{s}", .{ "aquila-zig", if (use_full_name) with_os_arch else "" });

    const exe = b.addExecutable(exe_name, "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    const exe_options = b.addOptions();
    exe.addOptions("build_options", exe_options);
    exe_options.addOption(string, "version", b.option(string, "version", "") orelse "dev");

    exe.linkLibC();
    deps.addAllTo(exe);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
