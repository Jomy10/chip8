const std = @import("std");

// https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x361.html

const esc = "\x1B";
const csi = esc ++ "[";
const clr_reset = csi ++ "0m";

pub const Color = enum {
    white,
    black,

    pub fn str(comptime self: *const Color) []const u8 {
        return comptime switch (self.*) {
            .black => csi ++ "40m",
            .white => csi ++ "47m",
        };
    }
};

pub fn setCursor(writer: anytype, row: i32, col: i32, buf: []u8) !void {
    const formatted: []u8 = try std.fmt.bufPrint(buf, csi ++ "{};{}H", .{ row, col });
    _ = try writer.write(formatted);
}

pub fn printBg(writer: anytype, comptime color: Color, comptime text: []const u8) !void {
    const clr_str = comptime color.str();
    _ = try writer.write(clr_str ++ text ++ clr_reset);
}
