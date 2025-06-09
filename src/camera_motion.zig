///moves camera from one state to another over a time duration
const std = @import("std");
const sdl = @import("sdl3");
const Self = @This();
duration: f64,
passed: f64 = 0,
start: sdl.rect.FRect,
end: sdl.rect.FRect,

pub fn init(duration: f64, start: sdl.rect.FRect, end: sdl.rect.FRect) Self {
    return Self{
        .duration = duration,
        .start = start,
        .end = end,
    };
}

pub fn update(self: *Self, interval_ns: f64) void {
    self.passed += interval_ns;
}

pub fn running(self: *const Self) bool {
    return self.passed < self.duration;
}

pub fn reset(self: *Self) void {
    self.passed = 0;
}

pub fn currentRect(self: *const Self) sdl.rect.FRect {
    if (!self.running())
        return self.end;
    const fraction_passed: f64 = self.passed / self.duration;
    return .{
        .x = @floatCast((self.end.x - self.start.x) * fraction_passed + self.start.x),
        .y = @floatCast((self.end.y - self.start.y) * fraction_passed + self.start.y),
        .w = @floatCast((self.end.w - self.start.w) * fraction_passed + self.start.w),
        .h = @floatCast((self.end.h - self.start.h) * fraction_passed + self.start.h),
    };
}
