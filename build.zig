const std = @import("std");

const ExeBuildType = enum { cli, launcher };

// good resource: https://ikrima.dev/dev-notes/zig/zig-build/
pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    //===============
    // Build options
    //===============

    var lib_build_options = b.addOptions();
    lib_build_options.addOption(bool, "debugops", b.option(bool, "debugops", "print debugging information on operations") orelse false);
    lib_build_options.addOption(bool, "testplatformchars", b.option(bool, "test-platform-chars", "print characaters on the test platform instead of 1's and 0's") orelse false);
    lib_build_options.addOption(?[]const u8, "platform", b.option([]const u8, "platform", "The platform to compile for") orelse null);

    const cli_build_options = b.addOptions();

    // const launcher_build_options = b.addOptions();

    const exe_to_build: ExeBuildType = std.meta.stringToEnum(ExeBuildType, b.option([]const u8, "exe-type", "The type of exe to run ('cli' or 'launcher')") orelse "cli") orelse .cli;

    //=============
    // Libs & exes
    //=============
    const pkgs = struct {
        var chip8_lib: std.build.Pkg = std.build.Pkg{
            .name = "chip8",
            .source = .{ .path = "src/emulator/lib.zig" },
        };
    };
    pkgs.chip8_lib.dependencies = &[_]std.build.Pkg{lib_build_options.getPackage("build_options")};

    const cli_exe = cliExe(b, target, mode, pkgs, cli_build_options);
    // cli_exe.addOptions("build_options2", cli_build_options);
    // TODO: const launcher_exe = launcherExe(b, target, mode, pkgs, launcher_build_options);

    //=====
    // CLI
    //=====
    // cli_exe.linkLibrary(chip8_lib);
    // SDL
    // cli_exe.linkLibC();
    // cli_exe.linkSystemLibrary("SDL2");
    // cli_exe.linkSystemLibrary("c");

    // cli_exe.addOptions("build_options", build_options);

    switch (exe_to_build) {
        .cli => cli_exe.install(), // create build artifact in zig-cache
        .launcher => std.debug.print("Not yet configured\n", .{}),
    }

    //==========
    // Commands
    //==========

    const run_cmd: *std.build.RunStep = switch (exe_to_build) {
        .cli, .launcher => cli_exe.run(),
        // .launcher => std.debug.print("Not yet configured\n", .{}),
    };
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    //=======
    // Steps
    //=======

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    ////
    // const exe_tests = b.addTest("src/main.zig");
    // exe_tests.setTarget(target);
    // exe_tests.setBuildMode(mode);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&exe_tests.step);
}

// fn chip8Lib(build_options: *std.build.OptionsStep) std.build.Pkg {
//     const chip8_lib = std.build.Pkg{
//         .name = "chip8",
//         .source = .{ .path = "src/emulator/lib.zig" },
//         .dependencies = &[_]std.build.Pkg{build_options.getPackage("build_options")},
//     };
//     return chip8_lib;
// }

fn cliExe(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, comptime pkgs: type, build_options: *std.build.OptionsStep) *std.build.LibExeObjStep {
    const cli_exe = b.addExecutable("chip8", "src/cli/main.zig");
    cli_exe.setTarget(target);
    cli_exe.setBuildMode(mode);
    cli_exe.addPackage(pkgs.chip8_lib);
    // // TODO: only if platform=sdl
    cli_exe.linkLibC();
    cli_exe.linkSystemLibrary("SDL2");
    cli_exe.addOptions("build_options", build_options);
    return cli_exe;
}
