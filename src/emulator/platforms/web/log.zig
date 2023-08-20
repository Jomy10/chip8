// DEBUG ONLY

const std = @import("std");

extern fn wasmlog(?[*]const u8, usize) void;
extern fn wasmlogerr(?[*]const u8, usize) void;

pub fn log(msg: []const u8) void {
    wasmlog(msg.ptr, msg.len);
}

// DEBUG
pub fn logf(comptime fmt: []const u8, args: anytype) void {
    const allocator = std.heap.page_allocator;
    const str = std.fmt.allocPrint(allocator, fmt, args) catch {
        log("couldn't format");
        return;
    };
    log(str);
    allocator.free(str);
}

fn logErr(msg: []const u8) void {
    wasmlogerr(msg.ptr, msg.len);
}

fn logErrf(comptime fmt: []const u8, args: anytype) void {
    const allocator = std.heap.page_allocator;
    const str = std.fmt.allocPrint(allocator, fmt, args) catch {
        log("couldn't format");
        return;
    };
    logErr(str);
    allocator.free(str);
}
