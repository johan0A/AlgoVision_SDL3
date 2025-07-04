const std = @import("std");
const ui = @import("UI.zig");
const sdl = @import("sdl3");
const helpers = @import("../SDL_helpers.zig");

pub const Checkbox = ui.interactiveElement(
    bool,
    void,
    makeTexture,
    handleEvent,
);

fn makeTexture(value: bool, renderer: sdl.render.Renderer) sdl.render.Texture {
    return helpers.cloneTexture(if (value) textures.checked else textures.unchecked, renderer) catch unreachable;
}

fn handleEvent(event: *const sdl.events.Event, value: *bool, relative_mouse_pos: sdl.rect.FPoint) void {
    //only react in bounds.
    //bounds are based on the square texture size.
    if (relative_mouse_pos.x < 0.2 or relative_mouse_pos.x > 0.8 or relative_mouse_pos.y < 0.2 or relative_mouse_pos.y > 0.8) return;

    if (event.* == .mouse_button_down and event.mouse_button_down.button == .left)
        value.* = !value.*;
}

//TODO: move textures to design
var textures = struct {
    checked: sdl.render.Texture = undefined,
    unchecked: sdl.render.Texture = undefined,
}{};

pub fn init(renderer: sdl.render.Renderer, allocator: std.mem.Allocator) !void {
    textures.checked = try helpers.loadImage(renderer, "assets/ui/CB_checked.png", allocator);
    textures.unchecked = try helpers.loadImage(renderer, "assets/ui/CB_unchecked.png", allocator);
}
