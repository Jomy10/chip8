const std = @import("std");

const stdout = std.io.getStdOut();

const PlatformError = @import("../platform.zig").PlatformError;
const constants = @import("../constants.zig");
const VIDEO_WIDTH = constants.VIDEO_WIDTH;

const build_options = @import("build_options");
const debugops = build_options.debugops;
const printChars = build_options.testplatformchars;

pub const TestPlatform = struct {
    writer: std.io.BufferedWriter(4096, @TypeOf(stdout.writer())),

    const Self = @This();

    pub fn init() Self {
        var bw: std.io.BufferedWriter(4096, @TypeOf(stdout.writer())) = std.io.bufferedWriter(stdout.writer());
        return Self{ .writer = bw };
    }

    pub fn deinit(_: *Self, _: std.mem.Allocator) void {}

    pub fn handleInput(self: *Self, _: []bool) PlatformError!bool {
        _ = self;
        return false;
    }

    pub fn renderBuffer(self: *Self, buf: []u1) PlatformError!void {
        if (!debugops) {
            var x: u32 = 0;
            var y: u32 = 0;
            var writer = self.writer.writer();
            for (buf) |elem| {
                if (printChars) {
                    switch (elem) {
                        1 => try writer.print("#", .{}),
                        0 => try writer.print(" ", .{}),
                    }
                } else {
                    try writer.print("{}", .{elem});
                }

                x += 1;
                if (x == VIDEO_WIDTH) {
                    x = 0;
                    y += 1;
                    try writer.print("\n", .{});
                }
            }

            var i: u32 = 0;
            while (i < VIDEO_WIDTH) : (i += 1) {
                try writer.print("=", .{});
            }
            try writer.print("\n", .{});

            try self.writer.flush();
        }
    }
};
