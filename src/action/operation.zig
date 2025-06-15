const std = @import("std");
const sdl = @import("sdl3");
const heap = @import("../heap/internal.zig");
const Action = @import("action.zig");
const CameraMotion = @import("../camera_motion.zig");
const Wait = @import("../wait.zig");
const Self = @This();
action: Action.Action,
camera_motion: ?CameraMotion = .{ .duration = 3_000_000_000, .end = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 }, .start = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 } },
first_update: bool = true,
pause: Wait = .{ .duration = 2_000_000_000 },
current_step: Steps = @enumFromInt(0),

// returns either an action to undo the performed one or the current animation state
pub fn update(self: *Self, interval_ns: f64, allocator: std.mem.Allocator) ?union(enum) { action: Action.Action, animation_state: sdl.rect.FRect, done: void } {
    switch (self.current_step) {
        .look => {
            const real_motion: *CameraMotion =
                if (self.camera_motion) |*mot| mot else {
                    self.current_step.iterate();
                    return null;
                };
            real_motion.update(interval_ns);
            if (!real_motion.running()) {
                self.current_step.iterate();
            }
            return .{ .animation_state = real_motion.currentRect() };
        },
        .act => {
            self.current_step.iterate();
            return .{ .action = self.action.perform(allocator) };
        },
        .pause => {
            self.pause.update(interval_ns);
            if (!self.pause.running()) {
                self.current_step.iterate();
            }
            return null;
        },
        .done => {
            //self.reset();
            return .{ .done = {} };
        },
    }
}

pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
    self.action.deinit(allocator);
}

pub fn reset(self: *Self) void {
    if (self.camera_motion) |*motion| {
        motion.passed = 0;
    }
    self.pause.passed = 0;
    self.current_step = @enumFromInt(0);
}

const Steps = enum(u8) {
    look = 0,
    act,
    pause,
    done,

    ///moves to next step
    pub fn iterate(self: *Steps) void {
        self.* = @enumFromInt((@intFromEnum(self.*) + 1) % (@intFromEnum(Steps.done) + 1));
    }
};
