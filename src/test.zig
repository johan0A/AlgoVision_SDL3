const std = @import("std");
const sdl = @import("sdl3");

test "view" {
    const View = @import("view.zig");

    const view: View = .{ .cam = .{ .x = 0, .y = 0, .w = 1000, .h = 1000 }, .port = .{ .x = 500, .y = 500, .w = 500, .h = 500 } };
    const rect = sdl.rect.FRect{ .x = 50, .y = 50, .w = 50, .h = 50 };
    try std.testing.expect(view.inView(rect));
}

//TODO: complete this test after figuring memory mangemaent
//
//test "stack" {
//    const Stack = @import("stack/internal.zig");
//    const Operations = @import("action/operation_manager.zig");
//    const allocator = std.testing.allocator;
//    var op_manager = Operations.init(allocator);
//    var stack: Stack = Stack{
//        .top = 0,
//        .renderer = undefined,
//        .default_font = undefined,
//        .stack_frame = std.ArrayList(Stack.Block).init(allocator),
//        .block_texture = undefined,
//    };
//    defer stack.deinit(allocator);
//    _ = try op_manager.op_queue.append(.{ .action = .{ .call = .{ .stack = &stack, .new_text = allocator.dupe(u8, "hello") catch unreachable } }, .wait_time_ns = 0 });
//    _ = try op_manager.op_queue.append(.{ .action = .{ .call = .{ .stack = &stack, .new_text = allocator.dupe(u8, "hello") catch unreachable } }, .wait_time_ns = 0 });
//    _ = try op_manager.op_queue.append(.{ .action = .{ .call = .{ .stack = &stack, .new_text = allocator.dupe(u8, "hello") catch unreachable } }, .wait_time_ns = 0 });
//    for (op_manager.op_queue.items) |_| {
//        op_manager.update(0);
//    }
//}
