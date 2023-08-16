const std = @import("std");
const stdout = std.io.getStdOut();

const PlatformError = @import("../platform.zig").PlatformError;

const ansi = @import("terminal/ansi.zig");
const term = @import("terminal/term.zig");
const UncookSettins = term.UncookSettings;
const Term = term.Term;

const constants = @import("../constants.zig");
const VIDEO_WIDTH = constants.VIDEO_WIDTH;
const VIDEO_HEIGHT = constants.VIDEO_HEIGHT;
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;

const FMT_BUF_SIZE = 5 + 2 + 2 + 3;

const KeyboardLayout = enum(u8) {
    QWERTY,
    AZERTY,
};

pub const TerminalPlatform = struct {
    stdout: std.io.BufferedWriter(4096, @TypeOf(std.io.getStdOut().writer())),
    terminal: Term,
    kbMap: [4 * 4]u8,
    fmtBuf: [FMT_BUF_SIZE]u8,

    const Self = @This();

    pub fn init(_: std.mem.Allocator, _: u32, opts: *void) !Self {
        const kbl_ptr: *align(@alignOf(KeyboardLayout)) void = @alignCast(@alignOf(KeyboardLayout), opts);
        const kbl: KeyboardLayout = @ptrCast(*KeyboardLayout, kbl_ptr).*;
        // const kbl: KeyboardLayout = @ptrCast(*KeyboardLayout, opts).*;

        //o: KeyboardLayout) !Self {
        var writer = stdout.writer();
        var bufferedWriter = std.io.bufferedWriter(writer);
        // var buf: [FMT_BUF_SIZE]u8 = undefined;
        var t = Self{
            .stdout = bufferedWriter,
            .terminal = try Term.uncook(writer, .{
                .DisableCanonicalInputMode = true,
                // min bytes to read = 0, so together with canonical input mode, doesn't wait for input
                .minBytes = 0,
            }),
            .kbMap = Self.inputLayout(kbl),
            .fmtBuf = undefined,
        };
        // t.fmtBuf = t.__f[0..FMT_BUF_SIZE];
        return t;
    }

    pub fn deinit(self: *Self, _: std.mem.Allocator) void {
        self.terminal.close(&self.stdout) catch |err| std.debug.print("{}", .{err});
    }

    /// Returns true if the application should quit
    pub fn handleInput(self: *Self, keypad: []bool) PlatformError!bool {
        var buf: [1]u8 = undefined;
        const bytesRead: usize = self.terminal.read(1, &buf) catch return PlatformError.ReadingInputFailed;

        if (bytesRead != 1) {
            return false;
        }

        inline for (self.kbMap) |char, i| {
            if (char == buf[0]) {
                keypad[i] = true;
                return false;
            }
        }

        if (buf[0] == '@') {
            return true;
        }

        return false;
    }

    fn inputLayout(kbLayout: KeyboardLayout) [4 * 4]u8 {
        return switch (kbLayout) {
            // zig fmt: off
            .QWERTY => .{
                '1', '2', '3', '4',
                'q', 'w', 'e', 'r',
                'a', 's', 'd', 'f',
                'z', 'x', 'c', 'v',
            },
            // zig fmt: off
            .AZERTY => .{
                '&', 'é', '"', '\'',
                'a', 'z', 'e', 'r',
                'q', 's', 'd', 'f',
                'w', 'x', 'c', 'v',
            },
        };
    }

    pub fn renderBuffer(self: *Self, buffer: *[DISPLAY_MEM_SIZE]u1) PlatformError!void {
        // try ansi.resetCursor(&self.stdout);
        var x: i32 = 0;
        var y: i32 = 0;
        for (buffer) |pixel| {
            // std.debug.print("Pixel: ({}, {}) = {}\n", .{x, y, pixel});
            if (x == 0) {
                try ansi.setCursor(&self.stdout, y, x, &self.fmtBuf); // catch return PlatformError.RenderingFailed;
            }

            switch (pixel) {
                0 => _ = try self.stdout.write(" "),
                1 => _ = try self.stdout.write("#"),
            }

            x += 1;
            if (x == VIDEO_WIDTH) {
                x = 0;
                y += 1;
            }
        }
        try self.stdout.flush();
        // std.debug.print("render complete {any}\n", .{buffer});
    }
};
