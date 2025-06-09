const std = @import("std");
const sdl = @import("sdl3");
const helpers = @import("../SDL_helpers.zig");
const Operation = @import("operation.zig");
const Action = @import("action.zig").Action;
const View = @import("../view.zig");
const Self = @This();
op_queue: std.ArrayList(Operation),
undo_queue: std.ArrayList(Action),
allocator: std.mem.Allocator,
current: usize = 0,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .op_queue = std.ArrayList(Operation).init(allocator),
        .undo_queue = std.ArrayList(Action).init(allocator),
        .allocator = allocator,
    };
}

pub fn currentActionName(self: *const Self) ?[]const u8 {
    if (self.current >= self.op_queue.items.len) return null;
    return self.op_queue.items[self.current].action.name();
}

pub fn deinit(self: *Self) void {
    for (self.op_queue.items) |operation| {
        operation.deinit(self.allocator);
    }
    for (self.undo_queue.items) |action| {
        action.deinit(self.allocator);
    }
    self.op_queue.deinit();
    self.undo_queue.deinit();
}

pub fn append(self: *Self, op: Operation) void {
    self.op_queue.append(op) catch {
        @panic("failed to append operation");
    };
}

pub fn update(self: *Self, interval_ns: f64, view: ?*View) void {
    if (self.current >= self.op_queue.items.len)
        return;

    const current_op = &self.op_queue.items[self.current];
    if (view) |v| {
        if (current_op.first_update) {
            if (current_op.camera_motion) |*motion| {
                motion.start = v.cam;
                //adjust ratio to port in oreder to prevent stretching of textures while zooming
                motion.end = helpers.sameRatioRect(sdl.rect.FloatingType, motion.end, .{ .x = @floatFromInt(v.port.w), .y = @floatFromInt(v.port.h) });
            }
        }
    }
    switch (self.op_queue.items[self.current].update(interval_ns, self.allocator)) {
        .action => |undo| {
            self.undo_queue.append(undo) catch @panic("failed to append undo action");
            self.current += 1;
            //  std.debug.print("\x1B[2J\x1B[H", .{});
            //  self.printAllUndo();
        },
        .animation_state => |rect| {
            if (view) |v| {
                v.cam = rect;
            }
        },
    }
}

pub fn undoLast(self: *Self) void {
    if (self.current < 2) return;
    self.current -= 1;
    const last_action = self.undo_queue.pop() orelse unreachable;
    const undone = last_action.perform(self.allocator);
    last_action.deinit(self.allocator);
    undone.deinit(self.allocator);
    //    std.debug.print("\x1B[2J\x1B[H", .{});
    //    self.printAllUndo();
}

pub fn endCamState(self: *const Self) sdl.rect.FRect {
    for (std.mem.reverseIterator(self.op_queue.items)) |operation| {
        if (operation.ptr.camera_motion) |motion| return motion.end;
    }
    return .{ .x = 0, .y = 0, .w = 1920, .h = 1080 };
}

///prints a list of all operations in list for debugging purposes
pub fn printAll(self: *Self) void {
    for (self.op_queue.items) |operation| {
        switch (operation.action) {
            .call => |data| {
                std.debug.print("call:\t{s}\n", .{data.new_text});
            },
            .eval => |data| {
                std.debug.print("eval:\t{s}\n", .{data.new_text});
            },
            .pop => |_| {
                std.debug.print("pop!\t\n", .{});
            },
            .create => |_| {
                std.debug.print("create!\t\n", .{});
            },
            .destroy => |_| {
                std.debug.print("destroy!\t\n", .{});
            },
        }
    }
}

pub fn printAllUndo(self: *Self) void {
    for (self.undo_queue.items) |action| {
        switch (action) {
            .call => |data| {
                std.debug.print("call:\t{s}\n", .{data.new_text});
            },
            .eval => |data| {
                std.debug.print("eval:\t{s}\n", .{data.new_text});
            },
            .pop => |_| {
                std.debug.print("pop!\t\n", .{});
            },
            .create => |_| {
                std.debug.print("create!\t\n", .{});
            },
            .destroy => |_| {
                std.debug.print("destroy!\t\n", .{});
            },
        }
    }
}
