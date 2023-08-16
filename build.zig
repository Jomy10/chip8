const std = @import("std");

const Test = enum([]const u8) { terminal = "terminal" };

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const build_options = b.addOptions();
    build_options.addOption(bool, "debugops", b.option(bool, "debugops", "print debugging information on operations") orelse false);
    build_options.addOption(bool, "testplatformchars", b.option(bool, "test-platform-chars", "print characaters on the test platform instead of 1's and 0's") orelse false);
    build_options.addOption(?[]const u8, "platform", b.option([]const u8, "platform", "The platform to compile for") orelse null);

    const exe = b.addExecutable("chip8-zig", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    // exe.addPackagePath("zig-ansi", "libs/zig-ansi/src/lib.zig");
    // exe.addPackagePath("ansi-term", "libs/ansi-term/src/main.zig");
    // exe.addLibraryPath("libs/sdl");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("c");

    exe.addOptions("build_options", build_options);

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // const exe_tests = b.addTest("src/main.zig");
    // exe_tests.setTarget(target);
    // exe_tests.setBuildMode(mode);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&exe_tests.step);
}
