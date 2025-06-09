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

fn multiply(a: i32, b: i32) i32 {
    if (a > 1)
        _ = global_program.stack.call(multiply, .{ a - 1, b }, "multiply", gpa.allocator());
    return a * b;
}
const two_nums = struct {
    num1: i32 = 69,
    num2: i32 = 420,
};
const three_nums = struct {
    num1: i32 = 1,
    num2: i32 = 2,
    num3: i32 = 3,
};

pub fn main() !void {
    var program = try Program.init(gpa.allocator());
    global_program = program;
    const int = program.heap.create(two_nums{}, gpa.allocator());
    const other = program.heap.create(three_nums{}, gpa.allocator());
    _ = program.stack.call(add, .{ int.num1, int.num2 }, "add");
    program.heap.destroy(int, gpa.allocator());
    program.heap.destroy(other, gpa.allocator());

    program.start();
    program.deinit();
    const leak = gpa.detectLeaks();
    std.debug.print("leak: {}\n", .{leak});
}
