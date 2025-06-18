const std = @import("std");
const sdl = @import("sdl3");
const Program = @import("program.zig");
const Stack = @import("stack/internal.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
pub var exe_path: []const u8 = undefined;

pub const main_bg = sdl.pixels.Color{ .r = 160, .g = 160, .b = 160, .a = 255 };
pub const ui_bg = sdl.pixels.Color{ .r = 80, .g = 80, .b = 80, .a = 255 };
var global_program: *Program = undefined;
fn add(a: i32, b: i32) i32 {
    return a + b;
}

// const LinkedList = struct {
//     value: i32,
//     next: *LinkedList = null,
//     const Self = @This();

//    pub fn init(value: i32, heap: Program.Heap, allocator: std.mem.Allocator) *Self {
//        return heap.create(Self{.value = value,}, allocator);
//    }
//    pub fn setNext(self: *Self, )
// };

pub fn main() !void {
    var program = try Program.init(gpa.allocator());
    global_program = program;

    var list = std.SinglyLinkedList(i32){ .first = program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 32 }, gpa.allocator()) };
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 3 }, gpa.allocator()));
    program.heap.destroy(list.popFirst().?, gpa.allocator());
    program.heap.destroy(list.popFirst().?, gpa.allocator());
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 3 }, gpa.allocator()));
    program.heap.update(list.first.?);
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 3 }, gpa.allocator()));
    program.heap.update(list.first.?);
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 44 }, gpa.allocator()));
    program.heap.update(list.first.?);
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 44 }, gpa.allocator()));
    program.heap.update(list.first.?);
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 44 }, gpa.allocator()));
    program.heap.update(list.first.?);
    list.prepend(program.heap.create(std.SinglyLinkedList(i32).Node{ .data = 44 }, gpa.allocator()));
    while (list.popFirst()) |first| {
        program.heap.destroy(first, gpa.allocator());
    }
    std.debug.print("{d}", .{list.len()});

    program.start();
    program.deinit();
    const leak = gpa.detectLeaks();
    std.debug.print("leak: {}\n", .{leak});
}
