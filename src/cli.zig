const std = @import("std");
const stderr = std.io.getStdErr();

pub fn printHelp(name: []const u8) !void {
    var bw = std.io.bufferedWriter(stderr.writer());
    _ = try bw.write("Usage: ");
    _ = try bw.write(name);
    _ = try bw.write(" <ROM> <Scale> <Delay>\n");
    try bw.flush();
}
