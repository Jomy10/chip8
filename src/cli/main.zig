const std = @import("std");
const fs = std.fs;
const exit = std.os.exit;
const Allocator = std.mem.Allocator;

// const CHIP8 = @import("chip8").CHIP8;
// const platform_pkg = @import("platform.zig");
// const Platform = platform_pkg.Platform;
// const Emulator = @import("emulator.zig").Emulator;
// const cli = @import("cli.zig");
const chip8_pkg = @import("chip8");
const CHIP8 = chip8_pkg.chip8.CHIP8;
const Platform = chip8_pkg.platform.Platform;
const Emulator = chip8_pkg.emulator.Emulator;
const cli = @import("cli.zig");

const PlatformType = chip8_pkg.platform.PlatformType;
const PlatformOptType = chip8_pkg.platform.PlatformOptType;
const getPlatformOptions = chip8_pkg.platform.getPlatformOptions;
const DisplayBufferType = chip8_pkg.platform.DisplayBufferType;
const DISPLAY_BUFFER_ON = chip8_pkg.platform.DISPLAY_BUFFER_ON;
const DISPLAY_BUFFER_OFF = chip8_pkg.platform.DISPLAY_BUFFER_OFF;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 4) {
        try cli.printHelp(args[0]);
        exit(1);
    }

    // TODO: argument parser: -kbl=AZERTY and -kbl=QWERTY (if platform == terminal)

    const romFile: []const u8 = args[1];
    const videoScale: u32 = try std.fmt.parseInt(u32, args[2], 10);
    const cycleDelay: u32 = try std.fmt.parseInt(u32, args[3], 10);

    var opts: PlatformOptType = undefined;
    getPlatformOptions(@ptrCast(*void, &opts));
    var p = try PlatformType.init(allocator, videoScale, @ptrCast(*void, &opts));
    defer p.deinit(allocator);
    const platform: Platform(PlatformType, DisplayBufferType) = try Platform(PlatformType, DisplayBufferType).init(&p, &PlatformType.handleInput, &PlatformType.renderBuffer);

    var chip8 = CHIP8(DisplayBufferType, DISPLAY_BUFFER_ON, DISPLAY_BUFFER_OFF).init();

    var emulator: Emulator(PlatformType, @TypeOf(chip8), DisplayBufferType) = try Emulator(PlatformType, @TypeOf(chip8), DisplayBufferType).init(chip8, platform, cycleDelay);
    try emulator.loadROM(fs.cwd(), romFile);
    try emulator.run();
}
