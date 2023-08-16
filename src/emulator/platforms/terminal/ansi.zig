const std = @import("std");

// https://tldp.org/HOWTO/Bash-Prompt-HOWTO/x361.html

const esc = "\x1B";
const csi = esc ++ "[";

pub fn setCursor(writer: anytype, row: i32, col: i32, buf: []u8) !void {
    const formatted: []u8 = try std.fmt.bufPrint(buf, csi ++ "{};{}H", .{ row, col });
    _ = try writer.write(formatted);
}
