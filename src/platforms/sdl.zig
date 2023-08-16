const std = @import("std");

const sdl = @import("sdl/wrap.zig");
const constants = @import("../constants.zig");
const VIDEO_WIDTH = constants.VIDEO_WIDTH;
const VIDEO_HEIGHT = constants.VIDEO_HEIGHT;
const DISPLAY_MEM_SIZE = constants.DISPLAY_MEM_SIZE;

const PlatformError = @import("../platform.zig").PlatformError;

var cnt: i32 = 0;

pub const SDLPlatform = struct {
    window: *sdl.Window,
    renderer: *sdl.Renderer,
    texture: *sdl.Texture,
    // screenSurface: *sdl.Surface,
    width: usize,
    height: usize,
    scale: u32,

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

    pub fn handleInput(self: *SDLPlatform, keypad: []bool) PlatformError!bool {
        _ = self;
        _ = keypad;
        var quit = false;
        var event: sdl.Event = undefined;
        while (sdl.pollEvent(&event)) {
            switch (event.type) {
                @enumToInt(sdl.EventType.quit) => quit = true,
                @enumToInt(sdl.EventType.keyDown) => switch (event.key.keysym.sym) {
                    @enumToInt(sdl.KeySym.esc) => quit = true,
                    else => {},
                },
                @enumToInt(sdl.EventType.keyUp) => switch (event.key.keysym.sym) {
                    else => {},
                },
                else => {},
            }
        }

        return quit;
    }

    pub fn renderBuffer(self: *SDLPlatform, buffer: *[VIDEO_WIDTH * VIDEO_HEIGHT]u16) PlatformError!void {
        // var testBuffer: [DISPLAY_MEM_SIZE]u16 = undefined;
        // var y: u32 = 0;
        // while (y < VIDEO_HEIGHT) : (y += 1) {
        //     var x: u32 = 0;
        //     while (x < VIDEO_WIDTH) : (x += 1) {
        //         testBuffer[y * VIDEO_WIDTH + x] = 0b1111_1111_1111_1111;
        //         if (x > 20)
        //             testBuffer[y * VIDEO_WIDTH + x] = 0;
        //     }
        // }
        try sdl.updateTexture(self.texture, null, @ptrCast(*const void, buffer), VIDEO_WIDTH * @sizeOf(@TypeOf(buffer[0])));
        try sdl.renderClear(self.renderer);
        try sdl.renderCopy(self.renderer, self.texture, null, null);
        sdl.renderPresent(self.renderer);

        // try sdl.updateWindowSurface(self.window);
    }
};
