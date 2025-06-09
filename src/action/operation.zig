const std = @import("std");
const sdl = @import("sdl3");
const heap = @import("../heap/internal.zig");
const Action = @import("action.zig");
const CameraMotion = @import("../camera_motion.zig");
const Self = @This();
action: Action.Action,
camera_motion: ?CameraMotion = .{ .duration = 3_000_000_000, .end = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 }, .start = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 } },
first_update: bool = true,

// returns either an action to undo the performed one or the current animation state
pub fn update(self: *Self, interval_ns: f64, allocator: std.mem.Allocator) union(enum) { action: Action.Action, animation_state: sdl.rect.FRect } {
    const real_motion: *CameraMotion =
        if (self.camera_motion) |*mot| mot else return .{ .action = self.action.perform(allocator) };

    if (self.first_update) {
        self.first_update = false;
    }

    if (!real_motion.running()) {
        return .{ .action = self.action.perform(allocator) };
    }
    // block's location is set during operation performing
    real_motion.update(interval_ns);
    return .{ .animation_state = real_motion.currentRect() };
}

pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
    self.action.deinit(allocator);
}
