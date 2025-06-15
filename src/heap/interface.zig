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

area: sdl.rect.IRect,

pub fn init(self: *Self, operations: *OperationManager, area: sdl.rect.IRect, allocator: std.mem.Allocator, renderer: sdl.render.Renderer, block_texture_path: []const u8, font: *ttf.TTF_Font) !void {
    self.data = try Internal.init(allocator, renderer, block_texture_path, font);
    self.existing_rects = std.hash_map.AutoHashMap(*anyopaque, sdl.rect.IRect).init(allocator);
    errdefer self.data.deinit();
    self.operations = operations;
    self.area = area;
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
pub fn alloc(self: *Self, comptime T: type, size: usize, allocator: std.mem.Allocator) []T {
    switch (@typeInfo(T)) {
        .float => {},
        .int => {},
        else => {
            @compileError("only floats and ints are currently suppurted for arrays");
        },
    }
    const mem = allocator.alloc(T, size) catch @panic("alloc error");
    for (mem) |*elm| {
        elm.* = 0;
    }

    const block =
        Internal.Block.init(mem, .{ .font = self.data.default_font, .text_color = .{ .r = 255, .g = 0, .b = 0, .a = 255 } }, self.operations.allocator, calculateNewPos(self));

    self.existing_rects.put(@ptrCast(mem.ptr), block.rect) catch @panic("alloc error");

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
    const is_slice = @typeInfo(@TypeOf(ptr)).pointer.size == .slice;
    const real_ptr = if (is_slice) ptr.ptr else ptr;
    const block_rect = self.existing_rects.get(@ptrCast(real_ptr)) orelse @panic("tried to destroy non alocated memory");

    self.operations.append(.{
        .action = .{
            .destroy = .{
                .heap = &self.data,
                .ptr = @ptrCast(real_ptr),
            },
        },
        .camera_motion = .{
            .start = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 },
            .end = Internal.scaleRect(gappedRect(block_rect, 1), self.data.draw_scale).asOtherRect(sdl.rect.FloatingType),
            .duration = 3_000_000_000,
        },
    });
    _ = self.existing_rects.remove(real_ptr);

    if (is_slice) {
        allocator.free(ptr);
    } else {
        allocator.destroy(ptr);
    }
}

pub fn update(self: *Self, ptr: anytype) void {
    const is_slice = @typeInfo(@TypeOf(ptr)).pointer.size == .slice;
    const real_ptr = if (is_slice) ptr.ptr else ptr;
    const existing_rect = self.existing_rects.getPtr(real_ptr) orelse @panic("updating non allocated memory");
    const block =
        Internal.Block.init(ptr, .{ .font = self.data.default_font, .text_color = .{ .r = 255, .g = 0, .b = 0, .a = 255 } }, self.operations.allocator, .{ .x = existing_rect.x, .y = existing_rect.y });
    existing_rect.* = block.rect;
    self.operations.append(.{
        .action = .{
            .override = .{
                .heap = &self.data,
                .block = block,
                .ptr = @ptrCast(real_ptr),
            },
        },
        .camera_motion = .{
            .start = .{ .x = 0, .y = 0, .w = 1920, .h = 1080 },
            .end = Internal.scaleRect(gappedRect(block.rect, 1), self.data.draw_scale).asOtherRect(sdl.rect.FloatingType),
            .duration = 3_000_000_000,
        },
    });
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
fn calculateNewPos(self: *const Self) sdl.rect.IPoint {
    const lowest_block: sdl.rect.IRect = blk: {
        var it = self.existing_rects.iterator();
        var lowest: sdl.rect.IRect = (it.next() orelse break :blk .{ .x = self.area.x, .y = self.area.y, .w = 1, .h = 1 }).value_ptr.*;
        while (it.next()) |ref| {
            const rect = ref.value_ptr.*;
            if (rect.y < lowest.y)
                lowest = rect;
        }
        break :blk lowest;
    };
    return .{ .x = lowest_block.x, .y = lowest_block.y + lowest_block.h + 2 };
}
