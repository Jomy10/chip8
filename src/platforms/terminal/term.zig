const std = @import("std");
const fs = std.fs;
const os = std.os;

pub const UncookSettings = struct {
    // LFlags
    DisplayPressedKeys: bool = false,
    DisableCanonicalInputMode: bool = true,
    DisableSIGINT_SIGTSTP: bool = true,
    DisableInputProcessing: bool = true,

    // IFlags
    DisableSoftwareControlFlow: bool = true,
    DisableConvertingCarriageReturnToNewLine: bool = true,
    DisableSIGINTConversion: bool = true,
    DisableParityChecking: bool = true,
    DisableStripping8thBitOCharacters: bool = true,

    DisableOutputProcessing: bool = true,

    SetCharacterSizeTo8bitsPerByte: bool = true,

    timeout: u8 = 0,
    minBytes: u8 = 1,

    HideCursor: bool = true,
    EnableAlternativeBuffer: bool = true,
};

// const SavedUncookSettings = struct {
//     HideCursor: bool = true,
//     EnableAlternativeBuffer: bool = true,
// };

pub const Term = struct {
    original_termios: os.termios,
    tty: fs.File,
    input_len: u8,
    // saved_settings: SavedUncookSettings,

    /// Uncook the terminal
    pub fn uncook(stdout: anytype, comptime settings: UncookSettings) !Term {
        // Settings
        var lflag: os.system.tcflag_t = 0;
        comptime if (settings.DisplayPressedKeys) {
            lflag |= os.system.ECHO;
        };
        comptime if (settings.DisableCanonicalInputMode) {
            lflag |= os.system.ICANON;
        };
        comptime if (settings.DisableSIGINT_SIGTSTP) {
            lflag |= os.system.ISIG;
        };
        comptime if (settings.DisableInputProcessing) {
            lflag |= os.system.IEXTEN;
        };

        var iflag: os.system.tcflag_t = 0;
        comptime if (settings.DisableSoftwareControlFlow) {
            iflag |= os.system.IXON;
        };
        comptime if (settings.DisableConvertingCarriageReturnToNewLine) {
            iflag |= os.system.ICRNL;
        };
        comptime if (settings.DisableSIGINTConversion) {
            iflag |= os.system.BRKINT;
        };
        comptime if (settings.DisableParityChecking) {
            iflag |= os.system.INPCK;
        };
        comptime if (settings.DisableStripping8thBitOCharacters) {
            iflag |= os.system.ISTRIP;
        };

        var oflag: os.system.tcflag_t = comptime if (settings.DisableOutputProcessing) os.system.OPOST else 0;

        var cflag: os.system.tcflag_t = comptime if (settings.SetCharacterSizeTo8bitsPerByte) os.system.CS8 else 0;

        // tty
        var tty: fs.File = try fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });

        // termios
        const original_termios = try os.tcgetattr(tty.handle);
        var raw = original_termios;

        // apply settings flags
        raw.lflag &= ~lflag;
        raw.iflag &= ~iflag;
        raw.oflag &= ~oflag;
        raw.cflag |= cflag;

        // set timeot after which the syscall will return
        raw.cc[os.system.V.TIME] = settings.timeout;
        // minimum amount of bytes it reads before returning
        raw.cc[os.system.V.MIN] = settings.minBytes;

        // commit changes
        try os.tcsetattr(tty.handle, .FLUSH, raw);

        // Escape codes //
        if (settings.HideCursor) {
            _ = try stdout.write("\x1B[?25l"); // Hide the cursor.
        }
        _ = try stdout.write("\x1B[s"); // Save cursor position.
        _ = try stdout.write("\x1B[?47h"); // Save screen.
        if (settings.EnableAlternativeBuffer) {
            _ = try stdout.write("\x1B[?1049h"); // Enable alternative buffer.
        }
        // stdout.flush();

        return Term{
            .original_termios = original_termios,
            .tty = tty,
            .input_len = settings.minBytes,
            // .saved_settings = SavedUncookSettings{
            //     .HideCursor = settings.HideCursor,
            //     .EnableAlternativeBuffer = settings.EnableAlternativeBuffer,
            // },
        };
    }

    /// Read input and return the amount of bytes read. Input length is defined by
    /// `minBytes` from the `UncookSettings` passed to `uncook`.
    pub fn read(self: Term, comptime len: usize, buffer: *[len]u8) !usize {
        return self.tty.read(buffer);
    }

    pub fn close(self: Term, stdout: anytype) !void {
        try os.tcsetattr(self.tty.handle, .FLUSH, self.original_termios);
        _ = try stdout.write("\x1B[?1049l"); // Disable alternative buffer.
        _ = try stdout.write("\x1B[?47l"); // Restore screen.
        _ = try stdout.write("\x1B[u"); // Restore cursor position.
        _ = try stdout.write("\x1B[?25h"); // Show the cursor.
        try stdout.flush();

        self.tty.close();
    }
};

// pub fn __uncook() !void {
//     // get the terminal interface
//     var tty: fs.File = try fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
//     defer tty.close();

//     // uncook the terminal
//     const original_termios = try os.tcgetattr(tty.handle);
//     var raw = original_termios;

//     raw.lflag &= ~@as(os.system.tcflag_t,
//     // stop displaying pressed keys
//     os.system.ECHO
//     // disable cooked input mode (read byte-wise instead oline-wise)
//     | os.system.ICANON
//     // Disable Ctrl-X and Ctrl-Z
//     // | os.system.ISIG
//     // Disable input preprocessing (handle Ctrl-V e.g.)
//     | os.system.IEXTEN);

//     raw.iflag &= ~@as(
//         os.system.tcflag_t,
//         os.system.IXON | os.system.ICRNL | os.system.BRKINT | os.system.INPCK | os.system.ISTRIP,
//     );

//     raw.oflag &= ~@as(os.system.tcflag_t, os.system.OPOST);

//     // Set character size to 8 bits per byte.
//     raw.cflag |= os.system.CS8;

//     // set timeout after which the syscall will return
//     raw.cc[os.system.V.TIME] = 0;
//     // minimum amount of bytes it reads before returning
//     raw.cc[os.system.V.MIN] = 1;

//     // commit changes
//     try os.tcsetattr(tty.handle, .FLUSH, raw);

//     // Escape codes //
//     const writer = std.io.getStdOut().writer();
//     try writer.writeAll("\x1B[?25l"); // Hide the cursor.
//     try writer.writeAll("\x1B[s"); // Save cursor position.
//     try writer.writeAll("\x1B[?47h"); // Save screen.
//     try writer.writeAll("\x1B[?1049h"); // Enable alternative buffer.
//     // writer.flush();

//     while (true) {
//         var buffer: [1]u8 = undefined;
//         _ = try tty.read(&buffer);

//         if (buffer[0] == 'q') {
//             break;
//         } else if (buffer[0] == 'z') {
//             std.debug.print("UUUUP", .{});
//         }
//     }

//     // Clean up
//     try os.tcsetattr(tty.handle, .FLUSH, original_termios);
//     try writer.writeAll("\x1B[?1049l"); // Disable alternative buffer.
//     try writer.writeAll("\x1B[?47l"); // Restore screen.
//     try writer.writeAll("\x1B[u"); // Restore cursor position.
// }
