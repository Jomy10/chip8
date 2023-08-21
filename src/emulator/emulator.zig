const std = @import("std");
const fs = std.fs;

const build_options = @import("build_options");

const CHIP8 = @import("chip8.zig").CHIP8;
const Platform = @import("platform.zig").Platform;

pub fn Emulator(comptime RenderType: type, comptime CHIP8Type: type, comptime DisplayBufferType: type) type {
    comptime var Timer: type = undefined;
    comptime if (build_options.exe_build_type == .web) {
        Timer = void; // @import("platforms/web/timer.zig").WebTimer;
    } else {
        Timer = std.time.Timer;
    };

    return struct {
        chip8: CHIP8Type,
        platform: Platform(RenderType, DisplayBufferType),
        /// The frame time in nanoseconds
        cycleDelay: u32,
        timer: Timer,

        const Self = @This();

        pub fn init(chip8: CHIP8Type, platform: Platform(RenderType, DisplayBufferType), cycleDelay: u32) !Self {
            var emulator = Self{
                .chip8 = chip8,
                .platform = platform,
                .cycleDelay = @floatToInt(u32, (1.0 / @intToFloat(f64, cycleDelay)) * 1_000_000_000), // *1_000_000_000: s to ns
                .timer = undefined,
            };
            if (build_options.exe_build_type != .web) {
                emulator.timer = try Timer.start();
            }

            return emulator;
        }

        pub fn run(self: *Self) !void {
            if (build_options.exe_build_type != .web) {
                self.timer.reset();

                var quit: bool = false;

                while (!quit) {
                    const dt: u64 = self.timer.read();

                    if (dt >= self.cycleDelay) {
                        self.timer.reset();
                        quit = try self.platform.handleInput(self.platform.platform, &self.chip8.keypad);

                        self.chip8.cycle();
                        if (self.chip8.drawFlag) {
                            try self.platform.renderBuffer(self.platform.platform, &self.chip8.displayMemory);
                            self.chip8.drawFlag = false;
                        }
                    }
                }
            }
        }

        pub fn loadROM(self: *Self, dir: fs.Dir, filename: []const u8) !void {
            try self.chip8.loadROM(dir, filename);
        }

        pub fn loadROMBytes(self: *Self, rom: []const u8) void {
            self.chip8.loadROMBytes(rom);
        }
    };
}
