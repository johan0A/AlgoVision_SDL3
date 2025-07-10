const std = @import("std");
const sdl = @import("sdl3");
const ttf = @import("ttf")
const mixer = @import("mixer");
var exe_path: []const u8 = undefined;

///the use of c Libs for ttf and mixer
///requires constant checks for errors.
///this function meant to reduce code for such repetetive operation.
pub fn checkError(success: bool) sdl.errors.Error!void {
    if (success) return;
    if (sdl.errors.get()) |err| {
        std.log.debug("SDL error: {s}\n", .{err});
        return error.SdlError;
    }
}

///initiallize SDL3, a window and a renderer.
pub fn initSDL(allocator: std.mem.Allocator) !struct { sdl.video.Window, sdl.render.Renderer } {
    try sdl.init.init(.{
        .video = true,
        .audio = true,
    });
    try checkError(ttf.TTF_Init());
    //_ = mixer.Mix_Init(mixer.MIX_INIT_WAVPACK);
    //try checkError(mixer.Mix_OpenAudio(0x8010, 44100));
    const window = try sdl.video.Window.init(
        "my window",
        1920,
        1080,
        .{ .resizable = true, .maximized = false, .fullscreen = false, .vulkan = true },
    );
    const renderer = try sdl.render.Renderer.init(window, null);
    exe_path = try std.fs.selfExeDirPathAlloc(allocator);
    return .{ window, renderer };
}

///deinitiallize SDL3, a window and a renderer.
pub fn deinitSDL(window: sdl.video.Window, renderer: sdl.render.Renderer, allocator: std.mem.Allocator) void {
    allocator.free(exe_path);
    renderer.deinit();
    window.deinit();
    mixer.Mix_CloseAudio();
    mixer.Mix_Quit();
    ttf.TTF_Quit();
    sdl.init.quit(.{ .video = true, .audio = true });
}

pub fn loadImage(renderer: sdl.render.Renderer, relative_path: []const u8, allocator: std.mem.Allocator) !sdl.render.Texture {
    const full_path = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ exe_path, relative_path });
    defer allocator.free(full_path);

    const surf = try sdl.image.loadFile(full_path);
    return renderer.createTextureFromSurface(surf);
}

pub fn cloneTexture(texture: sdl.render.Texture, renderer: sdl.render.Renderer) !sdl.render.Texture {
    const last_target = renderer.getTarget();
    defer renderer.setTarget(last_target) catch {
        @panic("Failed to restore render target.");
    };

    const clone = try renderer.createTexture(sdl.pixels.Format.packed_rgba_8_8_8_8, .target, texture.getWidth(), texture.getHeight());
    try renderer.setTarget(clone);
    try renderer.renderTexture(texture, null, null);
    return clone;
}

pub fn loadWav(relative_path: []const u8, allocator: std.mem.Allocator) ![*c]mixer.Mix_Chunk {
    const full_path = try std.fmt.allocPrintZ("{s}/{s}", .{ exe_path, relative_path });
    defer allocator.free(full_path);
    return mixer.Mix_LoadWAV(full_path);
}

pub fn loadFont(relative_path: []const u8, allocator: std.mem.Allocator) !*ttf.TTF_Font {
    const full_path = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ exe_path, relative_path });
    defer allocator.free(full_path);
    return ttf.TTF_OpenFont(full_path, 100) orelse sdl.errors.Error.SdlError;
}

pub fn createTextureFromText(font: *ttf.TTF_Font, text: []const u8, color: sdl.pixels.Color, renderer: sdl.render.Renderer) !sdl.render.Texture {
    const surf = ttf.TTF_RenderText_Solid(font, @ptrCast(text), text.len, @bitCast(color));
    const surface: sdl.surface.Surface = .{ .value = @as(?*sdl.c.struct_SDL_Surface, @ptrCast(surf)) orelse return sdl.errors.Error.SdlError };
    defer surface.deinit();
    return renderer.createTextureFromSurface(surface);
}

pub fn centrelizedRect(rect_type: type, rect: sdl.rect.Rect(rect_type), size: sdl.rect.Point(rect_type)) @TypeOf(rect) {
    const x = rect.x + (rect.w - size.x) / 2;
    const y = rect.y + (rect.h - size.y) / 2;
    return .{ .x = x, .y = y, .w = size.x, .h = size.y };
}

///turns rect to be the same ratio as 'ratio' while keeping the same center and not making it smaller
pub fn sameRatioRect(rect_type: type, rect: sdl.rect.Rect(rect_type), ratio: sdl.rect.Point(rect_type)) @TypeOf(rect) {
    const adj_w = ratio.x / ratio.y * rect.h;
    const adj_h = ratio.y / ratio.x * rect.w;
    if (adj_w > rect.w) {
        return centrelizedRect(rect_type, rect, .{ .x = adj_w, .y = rect.h });
    }
    return centrelizedRect(rect_type, rect, .{ .x = rect.w, .y = adj_h });
}

pub inline fn functionFormat(name: []const u8, args: anytype) []const u8 {
    comptime {
        const fields = std.meta.fields(@TypeOf(args));
        var fmt = name;
        fmt = fmt ++ "(";
        for (0..fields.len) |_| {
            fmt = fmt ++ "{}, ";
        }
        if (fields.len > 0)
            fmt = fmt[0 .. fmt.len - 2];
        fmt = fmt ++ ")";
        return fmt;
    }
}

// pub inline fn pointerFields(T: type) [][]const u8 {
// var fields: [][]const u8 = switch (@typeInfo(T)) {
// .
//
// }
//
// }
