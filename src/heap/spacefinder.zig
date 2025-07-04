const sdl = @import("sdl3");
const std = @import("std");

const RectInfo = struct {
    rect: sdl.rect.IRect,
    visited: bool,

    fn islessthanX(context: void, lhs: RectInfo, rhs: RectInfo) bool {
        _ = context;
        return (lhs.rect.x + lhs.rect.w <= rhs.rect.x + rhs.rect.w);
    }
    fn islessthanY(context: void, lhs: RectInfo, rhs: RectInfo) bool {
        _ = context;
        return (lhs.rect.y + lhs.rect.h <= rhs.rect.y + rhs.rect.h);
    }
};
pub fn spaceFinder(rect_type: type, gap: comptime_int) type {
    const TYPE = sdl.rect.Rect(rect_type);
    if (gap < 0)
        @compileError("gap size cannot be negative");

    return struct {
        const Self = @This();

        area: TYPE,
        existing_rects: std.ArrayList(RectInfo),

        pub fn init(allocator: std.mem.Allocator, initial_capacity: usize, area: TYPE) !Self {
            return Self{
                .area = area,
                .existing_rects = try std.ArrayList(RectInfo).initCapacity(allocator, initial_capacity),
            };
        }

        ///appends to list and maintains order based on x dimension.
        /// array capacity growth is exponential to save reallocations.
        pub fn append(self: *Self, rect: TYPE) !void {
            const rects = &self.existing_rects;

            if (rects.capacity == rects.items.len) {
                const new_cap: usize = @intFromFloat(@as(f32, @floatFromInt(rects.capacity)) * 1.5);
                try rects.ensureTotalCapacity(new_cap);
            }
            const gapped_rect = gappedRect(rect);
            try rects.append(.{ .rect = gapped_rect, .visited = false });
            std.sort.insertion(RectInfo, rects.items, {}, RectInfo.islessthanX);
        }
        pub fn getFreeSpace(self: *Self, size: sdl.rect.Point(rect_type)) TYPE {
            for (self.existing_rects.items) |*strct| {
                strct.visited = false;
            }
            const base_rect: TYPE = .{ .x = self.area.x, .y = self.area.y, .w = size.x, .h = size.y };

            return findEmptySpace(base_rect, base_rect, self.existing_rects);
        }
        pub fn remove(self: *Self, rect: TYPE) void {
            for (self.existing_rects.items, 0..) |strct, idx| {
                if (rect.x != strct.rect.x) continue;
                if (rect.y != strct.rect.y) continue;
                if (rect.w != strct.rect.w) continue;
                if (rect.h != strct.rect.h) continue;

                _ = self.existing_rects.orderedRemove(idx);
                return;
            }
        }

        fn findEmptySpace(
            original: TYPE,
            current: TYPE,
            Xlist: std.ArrayList(RectInfo),
        ) TYPE {
            for (Xlist.items, 0..) |*strct, idx| {
                const rect = strct.rect;
                if (rect.hasIntersection(current)) {
                    if (strct.visited) {
                        //return something that cant be nearest to start point
                        return sdl.rect.IRect{
                            .x = std.math.sqrt(std.math.maxInt(sdl.rect.IntegerType)) / 4,
                            .y = std.math.sqrt(std.math.maxInt(sdl.rect.IntegerType)) / 4,
                            .w = 0,
                            .h = 0,
                        };
                    }

                    strct.visited = true;

                    const finalY = rect.y + rect.h;
                    const finalX = rect.x + rect.w;

                    const ydiffed_rect: sdl.rect.IRect = .{
                        .x = current.x,
                        .y = finalY,
                        .w = current.w,
                        .h = current.h,
                    };

                    const xdiffed_rect: sdl.rect.IRect = .{
                        .x = finalX,
                        .y = current.y,
                        .w = current.w,
                        .h = current.h,
                    };

                    const allowed_idx = min: {
                        var index = idx;
                        while (index > 0) : (index -= 1) {
                            const rct = Xlist.items[index];
                            if (rct.rect.x + rct.rect.h < finalX) break;
                        }
                        break :min index;
                    };

                    const Yres = findEmptySpace(original, ydiffed_rect, Xlist);
                    const Xres = findEmptySpace(original, xdiffed_rect, std.ArrayList(RectInfo).fromOwnedSlice(Xlist.allocator, Xlist.items[allowed_idx..]));
                    const xdistance = std.math.pow(sdl.rect.IntegerType, Xres.x - original.x, 2) + std.math.pow(sdl.rect.IntegerType, Xres.y - original.y, 2);
                    const ydistance = std.math.pow(sdl.rect.IntegerType, Yres.x - original.x, 2) + std.math.pow(sdl.rect.IntegerType, Yres.y - original.y, 2);
                    if (xdistance > ydistance) {
                        return Yres;
                    } else {
                        return Xres;
                    }
                }
            }
            return current;
        }
        fn gappedRect(rect: TYPE) sdl.rect.IRect {
            return sdl.rect.IRect{
                .x = rect.x - gap,
                .y = rect.y - gap,
                .w = rect.w + gap * 2,
                .h = rect.h + gap * 2,
            };
        }
    };
}
