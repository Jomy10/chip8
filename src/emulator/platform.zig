const std = @import("std");
const Allocator = std.mem.Allocator;

const KeyPress = @import("chip8.zig").KeyPress;
const constants = @import("constants.zig");
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;

pub const PlatformError = error{
// generic
ReadingInputFailed, RenderingFailed,
// Printing
AccessDenied, BrokenPipe, ConnectionResetByPeer, DiskQuota, FileTooBig, InputOutput, LockViolation, NoSpaceLeft, NotOpenForWriting, OperationAborted, SystemResources, Unexpected, WouldBlock,
// SDL
SDLError };

pub fn Platform(comptime T: type, comptime _DisplayBufferType: type) type {
    return struct {
        platform: *T,
        handleInput: *const fn (*T, []KeyPress) PlatformError!bool,
        renderBuffer: *const fn (*T, *std.PackedIntArray(_DisplayBufferType, DISPLAY_MEM_SIZE)) PlatformError!void,

        const Self = @This();

        pub fn init(
            platform: *T,
            handleInput: *const fn (*T, []KeyPress) PlatformError!bool,
            renderBuffer: *const fn (*T, *std.PackedIntArray(_DisplayBufferType, DISPLAY_MEM_SIZE)) PlatformError!void,
        ) !Self {
            // zig fmt: off
            return Self {
                .platform = platform,
                .handleInput = handleInput,
                .renderBuffer = renderBuffer
            };
        }
    };
}

//===============
// build options
//===============

const build_options = @import("build_options");
// const opt_platform: ?[]const u8 = build_options.platform;

const PlatformTypeE = @TypeOf(build_options.platform);
//  enum {
//     terminal,
//     testPlatform,
//     sdl,
//     htmlCanvas
// };

fn platformType() PlatformTypeE {
    // comptime return std.meta.stringToEnum(PlatformTypeE, opt_platform.?) orelse @compileError("Unknown platform specified: '" ++ opt_platform.? ++ "'");
    comptime return build_options.platform;
}

fn getPlatformType() type {
    return switch (platformType()) {
        .terminal => @import("platforms/terminal.zig").TerminalPlatform,
        .testPlatform => @import("platforms/test_platform.zig").TestPlatform,
        .sdl => @import("platforms/sdl.zig").SDLPlatform,
        .htmlCanvas => @import("platforms/htmlcanvas.zig").HTMLCanvasPlatform,
    };
}

fn getPlatformOptType() type {
    return switch (platformType()) {
        .terminal => u8,
        .testPlatform => void,
        .sdl => void,
        .htmlCanvas => void,
    };
}

pub const PlatformType: type = getPlatformType();
pub const PlatformOptType: type = getPlatformOptType();
pub fn getPlatformOptions(opts: *void) void {
    switch (platformType()) {
        .terminal => {
            const aligned_ptr: *align(@alignOf(u8)) void = @alignCast(@alignOf(u8), opts);
            const kbl_ptr: *u8 = @ptrCast(*u8, aligned_ptr);
            kbl_ptr.* = 0;
        },
        .testPlatform, .sdl, .htmlCanvas => {}, 
    }
}

pub const DisplayBufferType: type = switch (platformType()) {
    .terminal, .testPlatform, .htmlCanvas => u1,
    .sdl => u16,
};

pub const DISPLAY_BUFFER_ON: DisplayBufferType = switch (platformType()) {
    .terminal, .testPlatform, .sdl, .htmlCanvas => std.math.maxInt(DisplayBufferType),
};

pub const DISPLAY_BUFFER_OFF: DisplayBufferType = switch (platformType()) {
    .terminal, .testPlatform, .sdl, .htmlCanvas => 0
};
