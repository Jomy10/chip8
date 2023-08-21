const std = @import("std");

const ExeBuildType = enum { cli, launcher, web };
const PlatformType = enum { terminal, testPlatform, sdl, htmlCanvas };

// good resource: https://ikrima.dev/dev-notes/zig/zig-build/
pub fn build(b: *std.build.Builder) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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

    const exe_to_build_opt = b.option([]const u8, "exe-type", "The type of exe to run ('cli' or 'launcher')");
    if (exe_to_build_opt == null) {
        std.debug.print("Please provide a valid exe type", .{});
        return;
    }
    const exe_to_build: ExeBuildType = std.meta.stringToEnum(ExeBuildType, exe_to_build_opt.?).?;
    const platform_opt = b.option([]const u8, "platform", "The platform to compile for");
    if (platform_opt == null) {
        std.debug.print("Please provide a valid platform", .{});
        return;
    }
    const platform: PlatformType = std.meta.stringToEnum(PlatformType, platform_opt.?).?;

    var lib_build_options = b.addOptions();
    lib_build_options.addOption(bool, "debugops", b.option(bool, "debugops", "print debugging information on operations") orelse false);
    lib_build_options.addOption(bool, "testplatformchars", b.option(bool, "test-platform-chars", "print characaters on the test platform instead of 1's and 0's") orelse false);
    lib_build_options.addOption(PlatformType, "platform", platform);
    lib_build_options.addOption(ExeBuildType, "exe_build_type", exe_to_build);
    lib_build_options.addOption(bool, "terminal_full_pixel", b.option(bool, "terminal-full-pixel", "Color the whole pixel in the terminal platform") orelse false);

    const cli_build_options = b.addOptions();

    const launcher_build_options = b.addOptions();

    const wasm_build_options = b.addOptions();

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
    const launcher_exe = launcherExe(b, target, mode, pkgs, launcher_build_options);

    const wasm_lib = wasmLib(b, mode, pkgs, wasm_build_options);

    // install the correct binary
    switch (exe_to_build) {
        .cli => cli_exe.install(), // create build artifact in zig-cache
        .launcher => launcher_exe.install(),
        .web => {
            wasm_lib.install();
            b.installFile("src/web/index.html", "web/index.html");
            b.installFile("src/web/index.js", "web/index.js");
            b.installFile("src/web/emulator.js", "web/emulator.js");
            b.installFile("src/web/wasm.js", "web/wasm.js");
            // b.installFile("src/web/wasm-worker.js", "web/wasm-worker.js");
            // b.installFile("src/web/timer.js", "web/timer.js");
            const wasm_path = try std.fs.path.join(allocator, &[_][]const u8{ b.install_path, "lib", "chip8-wasm.wasm" });
            defer allocator.free(wasm_path);
            b.installFile(wasm_path, "web/chip8-wasm.wasm");

            switch (platform) {
                .htmlCanvas => b.installFile("src/emulator/platforms/htmlcanvas/render.js", "web/render.js"),
                else => std.debug.print("Not a web platform", .{}), //@compileError("Not a web platform " ++ p),
            }
        },
    }
    //==========
    // Commands
    //==========

    const run_cmd: *std.build.RunStep = switch (exe_to_build) {
        .cli, .web => cli_exe.run(),
        .launcher => launcher_exe.run(),
        // .web => {
        //     std.os.exit(22);
        //     // TODO:
        //     // const out_path = try std.fs.path.join(allocator, &[_][]const u8{ b.install_path, "web" });
        //     // defer allocator.free(out_path);
        //     // const argv = [_][]const u8{ "python3", "-m", "http.server", "-d", "zig-out/web" };
        //     // return try b.spawnChild(&argv);
        // },
    };
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(
            args,
        );
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

fn launcherExe(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, comptime pkgs: type, build_options: *std.build.OptionsStep) *std.build.LibExeObjStep {
    const exe = b.addExecutable("chip8-launcher", "src/launcher/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackage(pkgs.chip8_lib);
    // // TODO: only if platform=sdl
    exe.linkLibC();
    exe.linkSystemLibrary("SDL2");
    exe.addOptions("build_options", build_options);
    return exe;
}

fn wasmLib(b: *std.build.Builder, mode: std.builtin.Mode, comptime pkgs: type, build_options: *std.build.OptionsStep) *std.build.LibExeObjStep {
    _ = build_options;
    const wasm = b.addSharedLibrary("chip8-wasm", "src/web/main.zig", .unversioned);
    const wasm_target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
    wasm.setTarget(wasm_target);
    wasm.setBuildMode(mode);
    wasm.addPackage(pkgs.chip8_lib);
    // wasm.addSystemIncludePath("src/web"); // TODO: needed?
    // wasm.addOptions("build_options", build_options);
    return wasm;
}
