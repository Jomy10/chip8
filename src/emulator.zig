const std = @import("std");
const fs = std.fs;
const time = std.time;

const CHIP8 = @import("chip8.zig").CHIP8;
const Platform = @import("platform.zig").Platform;

pub fn Emulator(comptime RenderType: type, comptime CHIP8Type: type, comptime DisplayBufferType: type) type {
    return struct {
        chip8: CHIP8Type,
        platform: Platform(RenderType, DisplayBufferType),
        /// The frame time in nanoseconds
        cycleDelay: u32,
        timer: time.Timer,

        const Self = @This();

        pub fn init(chip8: CHIP8Type, platform: Platform(RenderType, DisplayBufferType), cycleDelay: u32) !Self {
            var emulator = Self{
                .chip8 = chip8,
                .platform = platform,
                .cycleDelay = @floatToInt(u32, (1.0 / @intToFloat(f64, cycleDelay)) * 1_000_000_000), // *1_000_000_000: s to ns
                .timer = try time.Timer.start(),
            };

            std.debug.print("{}\n", .{emulator.cycleDelay});

            return emulator;
        }

        pub fn run(self: *Self) !void {
            self.timer.reset();

            var quit: bool = false;

            std.debug.print("running\n", .{});

            while (!quit) {
                quit = try self.platform.handleInput(self.platform.platform, &self.chip8.keypad);
                const dt: u64 = self.timer.read(); // / 1_000_000; // in nanoseconds to millis

                if (dt >= self.cycleDelay) {
                    // std.debug.print("{}\n", .{self.cycleDelay});
                    self.timer.reset();

                    self.chip8.cycle();
                    try self.platform.renderBuffer(self.platform.platform, &self.chip8.displayMemory);
                }
            }
        }

        pub fn loadROM(self: *Self, dir: fs.Dir, filename: []const u8) !void {
            try self.chip8.loadROM(dir, filename);
        }
    };
}
