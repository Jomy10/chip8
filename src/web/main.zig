const std = @import("std");
const Allocator = std.mem.Allocator;

const chip8_pkg = @import("chip8");
const CHIP8 = chip8_pkg.chip8.CHIP8;
const Platform = chip8_pkg.platform.Platform;
const Emulator = chip8_pkg.emulator.Emulator;

const PlatformType = chip8_pkg.platform.PlatformType;
const PlatformOptType = chip8_pkg.platform.PlatformOptType;
const getPlatformOptions = chip8_pkg.platform.getPlatformOptions;
const DisplayBufferType = chip8_pkg.platform.DisplayBufferType;
const DISPLAY_BUFFER_ON = chip8_pkg.platform.DISPLAY_BUFFER_ON;
const DISPLAY_BUFFER_OFF = chip8_pkg.platform.DISPLAY_BUFFER_OFF;

// const Timer = @import("timer.zig").WebTimer;

extern fn wasmlog(?[*]const u8, usize) void;
extern fn wasmlogerr(?[*]const u8, usize) void;

fn log(msg: []const u8) void {
    wasmlog(msg.ptr, msg.len);
}

fn logf(comptime fmt: []const u8, args: anytype) void {
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
    const str = std.fmt.allocPrint(allocator, fmt, args) catch {
        log("couldn't format");
        return;
    };
    logErr(str);
    allocator.free(str);
}

const allocator = std.heap.page_allocator;
var allocated = std.AutoHashMap(*const u8, usize).init(allocator);
export fn alloc(bytes: u32) ?[*]const u8 {
    var mem: []u8 = allocator.alloc(u8, bytes) catch return null;
    allocated.put(&mem.ptr[0], mem.len) catch {
        logErr("Unable to insert ptr key");
        allocator.free(mem);
        return null;
    };
    return mem.ptr;
}

export fn free(ptr: ?[*]const u8) void {
    const len = allocated.get(@ptrCast(*const u8, ptr.?));
    if (len == null) {
        logErr("Unable to free");
        return;
    }
    const arr: []const u8 = ptr.?[0..len.?];
    allocator.free(arr);
}

const CHIP8Type = CHIP8(DisplayBufferType, DISPLAY_BUFFER_ON, DISPLAY_BUFFER_OFF);
const EmulatorType = Emulator(PlatformType, CHIP8Type, DisplayBufferType);
// var timer: Timer = undefined;

/// Returns a pointer to the emulator on success, null otherwise
export fn initEmulator(clockSpeed: u32, displaySize: u32) ?*EmulatorType {
    return initEmulatorImpl(clockSpeed, displaySize) catch {
        logErr("Error instantiating emulator");
        return null;
    };
}

export var keypadPtr: *bool = undefined;
// export var drawflag: *bool = undefined;
export fn drawFlag(emulator: ?*EmulatorType) bool {
    return emulator.?.*.chip8.drawFlag;
}
export var displayMemPtr: *u8 = undefined;

inline fn initEmulatorImpl(clockSpeed: u32, displaySize: u32) !*EmulatorType {
    // const a = std.heap.page_allocator;
    // log("Hello world\n") catch {};
    // return 257;

    // timer = Timer.start();

    var opts: void = undefined;
    var p = try PlatformType.init(allocator, displaySize, &opts);
    const platform: Platform(PlatformType, DisplayBufferType) = try Platform(PlatformType, DisplayBufferType).init(&p, &PlatformType.handleInput, &PlatformType.renderBuffer);

    var chip8 = CHIP8Type.init();

    var emulator: *EmulatorType = try allocator.create(EmulatorType);
    emulator.* = try EmulatorType.init(chip8, platform, clockSpeed);

    keypadPtr = &emulator.*.chip8.keypad[0];
    displayMemPtr = &emulator.*.chip8.displayMemory.bytes[0];

    return emulator;
}

export fn deinitEmulator(emulator: *EmulatorType) void {
    emulator.*.platform.platform.deinit(allocator);
    allocator.destroy(emulator);
    allocated.deinit();
}

/// Returns 1 if the emulator is null, 0 otherwise
export fn loadROM(emulator: ?*EmulatorType, rom: [*]const u8, romSize: u32) u32 {
    if (emulator == null) {
        log("error: emulator is null in `loadROM`");
        return 1;
    }
    const array: []const u8 = rom[0..romSize];
    emulator.?.*.loadROMBytes(array);
    return 0;
}

// Returns 1 on error, 0 on OK
// export fn run(emulator: ?*EmulatorType) u32 {
//     if (emulator == null) {
//         log("error: emulator is null");
//         return 1;
//     }
//     emulator.?.*.run() catch return 1;
//     return 0; // OK
// }

/// Returns true if the application should quit
export fn tick(_emulator: ?*EmulatorType) void {
    if (_emulator == null) {
        logErr("Emulator is null in tick");
        unreachable;
    }
    var emulator = _emulator.?;
    // timer.reset();
    emulator.*.chip8.cycle();
    // if (emulator.*.chip8.drawFlag) {
    //     try emulator.*.platform.renderBuffer(emulator.*.platform.platform, &emulator.*.chip8.displayMemory);
    //     emulator.*.chip8.drawFlag = false;
    // }
}
