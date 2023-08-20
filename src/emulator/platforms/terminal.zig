const std = @import("std");
const stdout = std.io.getStdOut();

const KeyPress = @import("../chip8.zig").KeyPress;
const DisplayBufferType = @import("../platform.zig").DisplayBufferType;
const PlatformError = @import("../platform.zig").PlatformError;

const ansi = @import("terminal/ansi.zig");
const term = @import("terminal/term.zig");
const UncookSettins = term.UncookSettings;
const Term = term.Term;

const constants = @import("../constants.zig");
const VIDEO_WIDTH = constants.VIDEO_WIDTH;
const VIDEO_HEIGHT = constants.VIDEO_HEIGHT;
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;

const build_options = @import("build_options");

const FMT_BUF_SIZE = 5 + 2 + 2 + 3;

const KeyboardLayout = enum(u8) {
    QWERTY,
    AZERTY,
};

// TODO: disable keyboard output
pub const TerminalPlatform = struct {
    stdout: std.io.BufferedWriter(4096, @TypeOf(std.io.getStdOut().writer())),
    terminal: Term,
    kbMap: [4 * 4]u8,
    fmtBuf: [FMT_BUF_SIZE]u8,

    const Self = @This();

    pub fn init(_: std.mem.Allocator, _: u32, opts: *void) !Self {
        // const kbl_ptr: *align(@alignOf(KeyboardLayout)) void = @alignCast(@alignOf(KeyboardLayout), opts);
        // const kbl: KeyboardLayout = @ptrCast(*KeyboardLayout, kbl_ptr).*;
        // TODO:
        _ = opts;
        const kbl = .AZERTY;

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
    pub fn handleInput(self: *Self, keypad: []KeyPress) PlatformError!bool {
        var buf: [1]u8 = undefined;
        const bytesRead: usize = self.terminal.read(1, &buf) catch return PlatformError.ReadingInputFailed;

        if (bytesRead != 1) {
            return false;
        }

        inline for (self.kbMap) |char, i| {
            // Release key
            if (keypad[i] != .unpressed) keypad[i] = .unpressed;

            if (char == buf[0]) {
                keypad[i] = .pressedThisFrame;
                return false;
            }
        }

        if (buf[0] == '@') {
            return true;
        }

        return false;
    }

    fn inputLayout(kbLayout: KeyboardLayout) [4 * 4]u8 {
        var key_map: [4 * 4]u8 = .{};
        const keys = switch (kbLayout) {
            // zig fmt: off
            .QWERTY => [4*4]u8{
                '1', '2', '3', '4',
                'q', 'w', 'e', 'r',
                'a', 's', 'd', 'f',
                'z', 'x', 'c', 'v',
            },
            // zig fmt: off
            .AZERTY => [4*4]u8{
                '&', 'é', '"', '\'',
                'a', 'z', 'e', 'r',
                'q', 's', 'd', 'f',
                'w', 'x', 'c', 'v',
            },
        };
        key_map[0x1] = keys[0];
        key_map[0x2] = keys[1];
        key_map[0x3] = keys[2];
        key_map[0xC] = keys[3];
        key_map[0x4] = keys[4];
        key_map[0x5] = keys[5];
        key_map[0x6] = keys[6];
        key_map[0xD] = keys[7];
        key_map[0x7] = keys[8];
        key_map[0x7] = keys[9];
        key_map[0x9] = keys[10];
        key_map[0xE] = keys[11];
        key_map[0xA] = keys[12];
        key_map[0x0] = keys[13];
        key_map[0xB] = keys[14];
        key_map[0xF] = keys[15];
        return key_map;
    }

    pub fn renderBuffer(self: *Self, buffer: *std.PackedIntArray(DisplayBufferType, DISPLAY_MEM_SIZE)) PlatformError!void {
        var x: i32 = 0;
        var y: i32 = 0;
        var i: usize = 0;
        // for (buffer) |pixel| {
        while (i < buffer.len) {
            const pixel: DisplayBufferType = buffer.*.get(i);
            if (x == 0) {
                try ansi.setCursor(&self.stdout, y, x, &self.fmtBuf); // catch return PlatformError.RenderingFailed;
            }

            switch (pixel) {
                0 => _ = if (build_options.terminal_full_pixel)
                        try ansi.printBg(&self.stdout, .white, " ")
                    else
                        try self.stdout.write(" "),
                1 => _ = if (build_options.terminal_full_pixel)
                        try ansi.printBg(&self.stdout, .black, " ")
                    else
                        try self.stdout.write("#"),
            }

            x += 1;
            if (x == VIDEO_WIDTH) {
                x = 0;
                y += 1;
            }

            i += 1;
        }
        try self.stdout.flush();
    }
};
