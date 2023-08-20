const std = @import("std");

const KeyPress = @import("../chip8.zig").KeyPress;
const DisplayBufferType = @import("../platform.zig").DisplayBufferType;
const sdl = @import("sdl/wrap.zig");
const constants = @import("../constants.zig");
const VIDEO_WIDTH = constants.VIDEO_WIDTH;
const VIDEO_HEIGHT = constants.VIDEO_HEIGHT;
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;
const KEY_COUNT = constants.KEY_COUNT;

const PlatformError = @import("../platform.zig").PlatformError;

// TODO: bounds checking
const KEY_UP_QUEUE_SIZE = 16;

fn getKeymap() [KEY_COUNT]c_int {
    var key_map: [KEY_COUNT]c_int = .{};
    key_map[0x1] = sdl.Scancode.n1;
    key_map[0x2] = sdl.Scancode.n2;
    key_map[0x3] = sdl.Scancode.n3;
    key_map[0xC] = sdl.Scancode.n4;
    key_map[0x4] = sdl.Scancode.q;
    key_map[0x5] = sdl.Scancode.w;
    key_map[0x6] = sdl.Scancode.e;
    key_map[0xD] = sdl.Scancode.r;
    key_map[0x7] = sdl.Scancode.a;
    key_map[0x8] = sdl.Scancode.s;
    key_map[0x9] = sdl.Scancode.d;
    key_map[0xE] = sdl.Scancode.f;
    key_map[0xA] = sdl.Scancode.z;
    key_map[0x0] = sdl.Scancode.x;
    key_map[0xB] = sdl.Scancode.c;
    key_map[0xF] = sdl.Scancode.v;
    return key_map;
}

pub const SDLPlatform = struct {
    window: *sdl.Window,
    renderer: *sdl.Renderer,
    texture: *sdl.Texture,
    width: usize,
    height: usize,
    scale: u32,
    keyUpQueue: [KEY_UP_QUEUE_SIZE]usize,
    keyUpQueueIdx: usize,
    comptime keyMap: [KEY_COUNT]c_int = getKeymap(),

    pub fn init(_: std.mem.Allocator, videoScale: u32, _: *void) !SDLPlatform {
        try sdl.init(.initVideo);
        var platform: SDLPlatform = undefined;
        platform.width = VIDEO_WIDTH * videoScale;
        platform.height = VIDEO_HEIGHT * videoScale;
        platform.scale = videoScale;
        const _winName: *const [5:0]u8 = "CHIP8";
        const winName = @ptrCast(*const u8, _winName);
        platform.window = try sdl.createWindow(
            winName,
            sdl.WINDOWPOS_UNDEFINED,
            sdl.WINDOWPOS_UNDEFINED,
            @intCast(c_int, platform.width),
            @intCast(c_int, platform.height),
            sdl.WINDOW_SHOWN,
        );
        platform.renderer = try sdl.createRenderer(platform.window, -1, @enumToInt(sdl.RendererFlags.rendererAccelerated));
        platform.texture = try sdl.createTexture(platform.renderer, @enumToInt(sdl.PixelFormat.ABGR4444), @enumToInt(sdl.TextureAccess.textureAccessStreaming), VIDEO_WIDTH, VIDEO_HEIGHT);
        platform.keyUpQueue = .{};
        platform.keyUpQueueIdx = 0;

        return platform;
    }

    pub fn deinit(self: *SDLPlatform, _: std.mem.Allocator) void {
        sdl.destroyWindow(self.window);
        sdl.destroyRenderer(self.renderer);
        sdl.destroyTexture(self.texture);
        sdl.quit();
    }

    pub fn getError() *const u8 {
        return sdl.getError();
    }

    pub fn handleInput(self: *SDLPlatform, keypad: []KeyPress) PlatformError!bool {
        for (keypad) |key, idx| {
            if (key == .pressedThisFrame)
                keypad[idx] = .pressedPrevFrame;
        }

        while (self.keyUpQueueIdx > 0) {
            self.keyUpQueueIdx -= 1;
            const keyPress = keypad[self.keyUpQueue[self.keyUpQueueIdx]];
            if (keyPress == .pressedPrevFrame) {
                keypad[self.keyUpQueue[self.keyUpQueueIdx]] = .unpressed;
            }
        }

        var quit = false;
        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            switch (event.type) {
                @enumToInt(sdl.EventType.quit) => quit = true,
                @enumToInt(sdl.EventType.keyDown) => {
                    if (event.key.keysym.scancode == sdl.Scancode.esc) quit = true;
                    inline for (self.keyMap) |key, idx| {
                        if (key == event.key.keysym.scancode) {
                            keypad[idx] = .pressedThisFrame;
                            break;
                        }
                    }
                },
                @enumToInt(sdl.EventType.keyUp) => {
                    inline for (self.keyMap) |key, idx| {
                        if (key == event.key.keysym.scancode) {
                            if (keypad[idx] == .pressedThisFrame) {
                                self.keyUpQueue[self.keyUpQueueIdx] = idx;
                                self.keyUpQueueIdx += 1;
                            } else {
                                keypad[idx] = .unpressed;
                            }
                            break;
                        }
                    }
                },
                else => {},
            }
        }

        return quit;
    }

    pub fn renderBuffer(self: *SDLPlatform, buffer: *std.PackedIntArray(DisplayBufferType, DISPLAY_MEM_SIZE)) PlatformError!void { //*[VIDEO_WIDTH * VIDEO_HEIGHT]u16) PlatformError!void {
        try sdl.updateTexture(self.texture, null, @ptrCast(*const void, &buffer.*.bytes), VIDEO_WIDTH * @sizeOf(DisplayBufferType));
        try sdl.renderClear(self.renderer);
        try sdl.renderCopy(self.renderer, self.texture, null, null);
        sdl.renderPresent(self.renderer);
    }
};
