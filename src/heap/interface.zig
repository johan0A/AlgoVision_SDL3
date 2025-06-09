const std = @import("std");
const sdl = @import("sdl3");
pub const Internal = @import("internal.zig");
const OperationManager = @import("../action/operation_manager.zig");
const Camera = @import("../camera_motion.zig");
const ttf = @cImport(@cInclude("SDL3_ttf/SDL_ttf.h"));

const Self = @This();
data: Internal,
operations: *OperationManager,
// data that updated on runtime (when code runs) to keep track and know upfront how to operate based on the past.
existing_rects: std.hash_map.AutoHashMap(*anyopaque, sdl.rect.IRect),

pub fn init(self: *Self, operations: *OperationManager, allocator: std.mem.Allocator, renderer: sdl.render.Renderer, block_texture_path: []const u8, font: *ttf.TTF_Font) !void {
    self.data = try Internal.init(allocator, renderer, block_texture_path, font);
    self.existing_rects = std.hash_map.AutoHashMap(*anyopaque, sdl.rect.IRect).init(allocator);
    errdefer self.data.deinit();
    self.operations = operations;
}

pub fn deinit(self: *Self) void {
    self.data.deinit();
    self.existing_rects.deinit();
}

pub fn create(self: *Self, val: anytype, allocator: std.mem.Allocator) *@TypeOf(val) {
    const mem = allocator.create(@TypeOf(val)) catch unreachable;
    mem.* = val;

    const block =
        Internal.Block.init(val, .{ .font = self.data.default_font, .text_color = .{ .r = 255, .g = 0, .b = 0, .a = 255 } }, self.operations.allocator, calculateNewPos(self));

    self.existing_rects.put(@ptrCast(mem), block.rect) catch @panic("alloc error");

    self.operations.append(.{
        .action = .{
            .create = .{
                .heap = &self.data,
                .block = block,
                .ptr = @ptrCast(mem),
            },
        },
        .camera_motion = .{
            .start = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 },
            .end = Internal.scaleRect(gappedRect(block.rect, 1), self.data.draw_scale).asOtherRect(sdl.rect.FloatingType),
            .duration = 3_000_000_000,
        },
    });
    return mem;
}

pub fn destroy(self: *Self, ptr: anytype, allocator: std.mem.Allocator) void {
    const block_rect = self.existing_rects.get(ptr) orelse @panic("tried to destroy not alocated memory");
    self.operations.append(.{
        .action = .{
            .destroy = .{
                .heap = &self.data,
                .ptr = ptr,
            },
        },
        .camera_motion = .{
            .start = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 },
            .end = Internal.scaleRect(gappedRect(block_rect, 1), self.data.draw_scale).asOtherRect(sdl.rect.FloatingType),
            .duration = 3_000_000_000,
        },
    });

    allocator.destroy(ptr);
}

fn gappedRect(rect: sdl.rect.IRect, gap: sdl.rect.IntegerType) sdl.rect.IRect {
    return sdl.rect.IRect{
        .x = rect.x - gap,
        .y = rect.y - gap,
        .w = rect.w + gap * 2,
        .h = rect.h + gap * 2,
    };
}

// TODO: make this algorithm better
// for now temporary implementation for testing
pub fn calculateNewPos(self: *const Self) sdl.rect.IPoint {
    const lowest_block: sdl.rect.IRect = blk: {
        var it = self.existing_rects.iterator();
        var lowest: sdl.rect.IRect = (it.next() orelse break :blk .{ .x = 0, .y = 0, .w = 1, .h = 1 }).value_ptr.*;
        while (it.next()) |ref| {
            const rect = ref.value_ptr.*;
            if (rect.y < lowest.y)
                lowest = rect;
        }
        break :blk lowest;
    };
    return .{ .x = lowest_block.x, .y = lowest_block.y + lowest_block.h + 2 };
}
