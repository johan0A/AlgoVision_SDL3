///file meant to handle all scaling and devision of window for different uses.
const std = @import("std");
const sdl = @import("sdl3");
const helpers = @import("SDL_helpers.zig");
const IRect = sdl.rect.IRect;
const FRect = sdl.rect.FRect;
const IPoint = sdl.rect.IPoint;
const FPoint = sdl.rect.FPoint;

const Self = @This();

cam: FRect,
port: IRect,

pub fn convertPoint(self: Self, point_type: type, point: sdl.rect.Point(point_type)) @TypeOf(point) {
    var new_point = point.asOtherPoint(f32);
    const Fport = self.port.asOtherRect(f32);
    new_point.x = Fport.x + (point.x - self.cam.x) * Fport.w / self.cam.w;
    new_point.y = Fport.y + (point.y - self.cam.y) * Fport.h / self.cam.h;
    return new_point.asOtherPoint(point_type);
}

pub fn scalePoint(self: Self, point_type: type, point: sdl.rect.Point(point_type)) @TypeOf(point) {
    var new_point = point.asOtherPoint(f32);
    const Fport = self.port.asOtherRect(f32);
    new_point.x *= (Fport.w / self.cam.w);
    new_point.y *= (Fport.h / self.cam.h);
    return new_point.asOtherPoint(point_type);
}

pub fn unscalePoint(self: Self, point_type: type, point: sdl.rect.Point(point_type)) @TypeOf(point) {
    var new_point = point.asOtherPoint(f32);
    const Fport = self.port.asOtherRect(f32);
    new_point.x /= (Fport.w / self.cam.w);
    new_point.y /= (Fport.h / self.cam.h);
    return new_point.asOtherPoint(point_type);
}

pub fn revertPoint(self: Self, point_type: type, point: sdl.rect.Point(point_type)) @TypeOf(point) {
    var new_point = point.asOtherPoint(f32);
    const Fport = self.port.asOtherRect(f32);

    new_point.x = self.cam.x + (point.x - Fport.x) * self.cam.w / Fport.w;
    new_point.y = self.cam.y + (point.y - Fport.y) * self.cam.h / Fport.h;
    return new_point.asOtherPoint(point_type);
}

pub fn convertRect(self: Self, rect_type: type, rect: sdl.rect.Rect(rect_type)) @TypeOf(rect) {
    var new_rect = rect.asOtherRect(f32);
    const Fport = self.port.asOtherRect(f32);

    new_rect.x = Fport.x + (new_rect.x - self.cam.x) * Fport.w / self.cam.w;
    new_rect.y = Fport.y + (new_rect.y - self.cam.y) * Fport.h / self.cam.h;

    new_rect.w *= Fport.w / self.cam.w;
    new_rect.h *= Fport.h / self.cam.h;

    return new_rect.asOtherRect(rect_type);
}

pub fn revertRect(self: Self, rect_type: type, rect: sdl.rect.Rect(rect_type)) @TypeOf(rect) {
    var new_rect = rect.asOtherRect(f32);
    const Fport = self.port.asOtherRect(f32);

    new_rect.x = self.cam.x + (rect.x - Fport.x) * self.cam.w / Fport.w;
    new_rect.y = self.cam.y + (rect.y - Fport.y) * self.cam.h / Fport.h;
    new_rect.w /= Fport.w / self.cam.w;
    new_rect.h /= Fport.h / self.cam.h;

    return new_rect.asOtherRect(rect_type);
}

///adjust port size to have a given ratio for window.
///makes it easier to resize the whole window and get responsive rendering adjustments.
///
///ratio parameter: x and y are offsets (floats 0-1).
///w and h correspond with port size relative to window size (floats 0-1).
///null assume .{.x = 0,.y = 0,.w = 1,.h = 1}. (entire window).
pub fn portWindowRatio(self: *Self, ratio: ?FRect, window: sdl.video.Window) void {
    const real_ratio: FRect = ratio orelse .{ .x = 0, .y = 0, .w = 1, .h = 1 };
    var window_size: IPoint = undefined;
    helpers.checkError(sdl.c.SDL_GetWindowSize(window.value, @ptrCast(&window_size.x), @ptrCast(&window_size.y))) catch {
        @panic("failed to get window size");
    };
    const Fwindow_size: FPoint = window_size.asOtherPoint(f32);
    self.port = (FRect{
        .x = Fwindow_size.x * real_ratio.x,
        .y = Fwindow_size.y * real_ratio.y,
        .w = Fwindow_size.x * real_ratio.w,
        .h = Fwindow_size.y * real_ratio.h,
    }).asOtherRect(sdl.rect.IntegerType);
}

pub fn zoom(self: *Self, scale: sdl.rect.FloatingType, direction: ?FPoint) void {
    if (scale <= 0)
        @panic("impossible zoom scale");

    const Fport = self.port.asOtherRect(f32);
    const original_cam = self.cam; // save original cam rect for future calculations.
    self.cam.w /= scale;
    self.cam.h /= scale;
    self.cam.x += (original_cam.w - self.cam.w) * (if (direction) |d| d.x / Fport.w else 0.5);
    self.cam.y += (original_cam.h - self.cam.h) * (if (direction) |d| d.y / Fport.h else 0.5);
}

///checks for intersection between camera and given rect
pub fn inView(self: Self, rect: sdl.rect.FRect) bool {
    return sdl.rect.FRect.hasIntersection(rect, self.cam);
}

const Filler = union(enum) {
    color: sdl.pixels.Color,
    texture: sdl.render.Texture,
};

/// fill port with a color to prevent port clipping
pub fn fillPort(self: *Self, renderer: sdl.render.Renderer, filler: Filler) !void {
    switch (filler) {
        .color => |color| {
            //save last color
            const last_color = try renderer.getDrawColor();
            defer renderer.setDrawColor(last_color) catch unreachable;

            try renderer.setDrawColor(color);
            try renderer.renderFillRect(self.port.asOtherRect(sdl.rect.FloatingType));
        },
        .texture => |texture| {
            try renderer.renderTexture(texture, null, self.port.asOtherRect(sdl.rect.FloatingType));
        },
    }
}
