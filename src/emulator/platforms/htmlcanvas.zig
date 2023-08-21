const std = @import("std");

const PlatformError = @import("../platform.zig").PlatformError;
const constants = @import("../constants.zig");
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;
const KeyPress = @import("../chip8.zig").KeyPress;

const js = struct {
    // pub extern fn renderBuffer(buffer: [*]const u8) void;
    // pub extern fn handleInput(keypad: [*]bool) bool;
    pub extern fn initScreen(u32) void;
    pub extern fn deinitScreen() void;
};

pub const HTMLCanvasPlatform = struct {
    const Self = @This();

    pub fn init(_: std.mem.Allocator, videoScale: u32, _: *void) !Self {
        js.initScreen(videoScale);
        return Self{};
    }

    pub fn deinit(_: *Self, _: std.mem.Allocator) void {
        js.deinitScreen();
    }

    // handled from js
    pub fn handleInput(_: *Self, _: []KeyPress) PlatformError!bool {
        // return js.handleInput(keypad.ptr);
        return true;
    }

    pub fn renderBuffer(_: *Self, _: *std.PackedIntArray(u1, DISPLAY_MEM_SIZE)) PlatformError!void {

        // const bytes = &(buffer.bytes[0]);
        // return js.renderBuffer(@ptrCast([*]const u8, bytes));
    }
};
