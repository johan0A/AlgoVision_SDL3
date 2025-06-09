const std = @import("std");
const ui = @import("UI.zig");
const ttf = @cImport(@cInclude("SDL3_ttf/SDL_ttf.h"));
const sdl = @import("sdl3");
const helpers = @import("../SDL_helpers.zig");

const Design = struct {
    font: *ttf.TTF_Font,
    color: sdl.pixels.Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 },
};

pub const Text = ui.interactiveElement(
    []const u8,
    Design,
    makeTexture,
    null,
);

fn makeTexture(value: []const u8, design: Design, renderer: sdl.render.Renderer) sdl.render.Texture {
    return helpers.createTextureFromText(design.font, value, design.color, renderer) catch unreachable;
}
