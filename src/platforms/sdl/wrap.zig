const sdl = @cImport({
    @cInclude("SDL2/SDL.h");
});

const PlatformError = @import("../../platform.zig").PlatformError;

pub const Window = sdl.SDL_Window;
pub const Surface = sdl.SDL_Surface;

pub const InitType = enum(c_uint) {
    initVideo = sdl.SDL_INIT_VIDEO,
};
pub fn init(t: InitType) PlatformError!void {
    if (sdl.SDL_Init(@enumToInt(t)) < 0) {
        return PlatformError.SDLError;
    }
}
pub const getError = sdl.SDL_GetError;
// pub const createWindow = sdl.SDL_CreateWindow;
pub fn createWindow(title: *const u8, x: c_int, y: c_int, w: c_int, h: c_int, flags: u32) PlatformError!*Window {
    var win: ?*Window = sdl.SDL_CreateWindow(title, x, y, w, h, flags);
    // switch (win) {
    if (win == null)
        return PlatformError.SDLError;
    return win.?;
}

// WINDOW //
pub fn getWindowSurface(win: *Window) PlatformError!*Surface {
    var surf: ?*Surface = sdl.SLSDL_GetWindowSurface(win);
    switch (surf) {
        null => return PlatformError.SDLError,
        else => return surf.?,
    }
}
/// Copy the window surface to the screen
pub fn updateWindowSurface(win: *Window) PlatformError!void {
    if (sdl.SDSDL_UpdateWindowSurface(win) < 0) {
        return PlatformError.SDLError;
    }
}
pub const Renderer = sdl.SDL_Renderer;
pub fn createRenderer(window: *Window, index: c_int, flags: u32) PlatformError!*Renderer {
    var ren = sdl.SDL_CreateRenderer(window, index, flags);
    if (ren == null) {
        return PlatformError.SDLError;
    }
    return ren.?;
}
pub const RendererFlags = enum(c_int) {
    rendererAccelerated = sdl.SDL_RENDERER_ACCELERATED,
};

pub const Texture = sdl.SDL_Texture;
pub fn createTexture(renderer: *Renderer, format: u32, access: c_int, w: c_int, h: c_int) PlatformError!*Texture {
    var tex = sdl.SDL_CreateTexture(renderer, format, access, w, h);
    if (tex == null) {
        return PlatformError.SDLError;
    }
    return tex.?;
}

pub const PixelFormat = enum(c_int) {
    RGBA8888 = sdl.SDL_PIXELFORMAT_RGBA8888,
    ABGR4444 = sdl.SDL_PIXELFORMAT_ABGR4444,
};

pub const TextureAccess = enum(c_int) {
    textureAccessStreaming = sdl.SDL_TEXTUREACCESS_STREAMING,
};

pub const destroyTexture = sdl.SDL_DestroyTexture;

pub const Rect = sdl.SDL_Rect;
pub fn updateTexture(texture: *Texture, rect: ?*Rect, pixels: *const void, pitch: c_int) PlatformError!void {
    if (sdl.SDL_UpdateTexture(texture, rect, pixels, pitch) < 0) {
        return PlatformError.SDLError;
    }
}

pub fn renderClear(renderer: *Renderer) PlatformError!void {
    if (sdl.SDL_RenderClear(renderer) < 0) {
        return PlatformError.SDLError;
    }
}

pub fn renderCopy(renderer: *Renderer, texture: *Texture, srcrect: ?*Rect, dstrect: ?*Rect) PlatformError!void {
    if (sdl.SDL_RenderCopy(renderer, texture, srcrect, dstrect) < 0) {
        return PlatformError.SDLError;
    }
}
pub const renderPresent = sdl.SDL_RenderPresent;

pub const destroyRenderer = sdl.SDL_DestroyRenderer;

pub const WINDOWPOS_UNDEFINED = sdl.SDL_WINDOWPOS_UNDEFINED;
pub const WINDOW_SHOWN = sdl.SDL_WINDOW_SHOWN;

// Input //
pub const Event = sdl.SDL_Event;
pub fn pollEvent(event: *Event) bool {
    return sdl.SDL_PollEvent(event) == 1;
}

pub const EventType = enum(c_int) {
    quit = sdl.SDL_QUIT,
    keyDown = sdl.SDL_KEYDOWN,
    keyUp = sdl.SDL_KEYUP,
};

pub const KeySym = enum(c_int) {
    esc = sdl.SDLK_ESCAPE,
};

// Deinit //
pub const freeSurface = sdl.SDL_FreeSurface;
pub const destroyWindow = sdl.SDL_DestroyWindow;
pub const quit = sdl.SDL_Quit;
