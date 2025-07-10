const std = @import("std");
const sdl = @import("sdl3");
const ttf = @import("ttf");
const View = @import("view.zig");
const Helpers = @import("SDL_helpers.zig");
const OperationManager = @import("action/operation_manager.zig");
const UI = @import("ui/UI.zig");
pub const Stack = @import("stack/interface.zig");
const Camera = @import("camera_motion.zig");
pub const Heap = @import("heap/interface.zig");
const main = @import("main.zig");
const main_bg = main.main_bg;
const Self = @This();

///A list of all ui element field names.
/// used for iterating over them.
const UIElements: []const []const u8 = blk: {
    var list: []const []const u8 = &.{};
    for (std.meta.fields(Self)) |field| {
        if (UI.isElement(field.type)) {
            list = list ++ .{field.name};
        }
    }
    break :blk list;
};

// sdl components
window: sdl.video.Window,
renderer: sdl.render.Renderer,

// core components
allocator: std.mem.Allocator,
main_view: View,
ui_view: View,
op_manager: OperationManager,
stack: Stack,
heap: Heap,

// UI
speed_slider: UI.Slider,
freecam_checkbox: UI.Checkbox,
freecam_text: UI.Text,
action_display: UI.Text,
fastforward_btn: UI.Button,
undo_btn: UI.Button,
pause_checkbox: UI.Checkbox,
ui_texture: sdl.render.Texture = undefined,
ui_bg: sdl.render.Texture,

// runtime data
running: bool = true,
playback_speed: f32 = 1.0,
pause: bool = false,
undo_btn_pressed: bool = false,
freecam_text_data: []const u8 = "Freecam",
freecam: bool = false,
fastforward_btn_pressed: bool = false,
current_action: []const u8 = undefined,

/// initialize a program and return a pointer to it
pub fn init(allocator: std.mem.Allocator) !*Self {
    var window: sdl.video.Window = undefined;
    var renderer: sdl.render.Renderer = undefined;
    window, renderer = try Helpers.initSDL(allocator);

    UI.init(renderer, allocator) catch unreachable;
    const op_manager = OperationManager.init(allocator);
    const stack_font = try Helpers.loadFont("assets/font/fint.ttf", allocator);

    const win_size = try window.getSize();
    const Pwin_size: sdl.rect.IPoint = .{ .x = @intCast(win_size.width), .y = @intCast(win_size.height) };

    const main_view = View{
        .cam = .{
            .x = 0,
            .y = 0,
            .w = Pwin_size.asOtherPoint(sdl.rect.FloatingType).x,
            .h = Pwin_size.asOtherPoint(sdl.rect.FloatingType).y,
        },
        .port = .{
            .x = 0,
            .y = 0,
            .w = Pwin_size.x,
            .h = Pwin_size.y,
        },
    };
    const ui_view: View = .{
        .cam = .{ .x = 0, .y = 0, .w = 1000, .h = 1000 },
        .port = .{ .x = 0, .y = 0, .w = 420, .h = 840 },
    };

    //allocated on the heap because objects place in memory matters,
    //therefor it cannot be copied around.
    const ret = try allocator.create(Self);
    ret.* = .{
        .window = window,
        .renderer = renderer,
        .allocator = allocator,
        .main_view = main_view,
        .ui_view = ui_view,
        .op_manager = op_manager,
        .stack = undefined,
        .heap = undefined,
        .current_action = "Test",
        .ui_texture = try renderer.createTexture(.packed_rgba_8_8_8_8, .target, 1000, 1000),
        .ui_bg = try Helpers.loadImage(renderer, "assets/ui/menu.png", allocator),
        //TODO: make actual textures for those buttons
        .fastforward_btn = UI.Button.init(&ret.fastforward_btn_pressed, .{ .x = 800, .y = 50, .w = 150, .h = 150 }, .{ .texture = try Helpers.createTextureFromText(stack_font, ">", .{ .r = 255, .g = 255, .b = 255, .a = 255 }, renderer) }),
        .undo_btn = UI.Button.init(&ret.undo_btn_pressed, .{ .x = 50, .y = 50, .w = 150, .h = 150 }, .{ .texture = try Helpers.createTextureFromText(stack_font, "<", .{ .r = 255, .g = 255, .b = 255, .a = 255 }, renderer) }),
        .speed_slider = UI.Slider.init(
            &ret.playback_speed,
            .{ .x = 50, .y = 265, .w = 700, .h = 70 },
            .{ .range = .{ .min = 0.2, .max = 10 }, .show_text = true, .text_font = stack_font },
        ),
        .pause_checkbox = UI.Checkbox.init(&ret.pause, .{ .x = 770, .y = 250, .w = 200, .h = 100 }),
        .freecam_checkbox = UI.Checkbox.init(&ret.freecam, .{ .x = 640, .y = 400, .w = 200, .h = 100 }),
        .freecam_text = UI.Text.init(&ret.freecam_text_data, .{ .x = 20, .y = 400, .w = 600, .h = 100 }, .{ .font = stack_font }),
        .action_display = UI.Text.init(&ret.current_action, .{ .x = 250, .y = 50, .w = 500, .h = 150 }, .{ .font = stack_font }),
    };

    //members must be initiallized after ret has been allocated
    ret.stack = Stack{
        .data = try Stack.Internal.init(allocator, renderer, .{ .x = 50, .y = 800, .w = 600, .h = 100 }, "assets/method.png", stack_font),
        .operations = &ret.op_manager,
    };
    try ret.heap.init(&ret.op_manager, .{ .x = 100, .y = 0, .w = 512, .h = 512 }, ret.allocator, renderer, "assets/heap.png", "assets/cloud.png", stack_font);
    //   ret.callMain();
    return ret;
}

fn callMain(self: *Self) void {
    const motion = Camera.init(
        3_000_000_000,
        .{ .x = 0, .y = 0, .w = 1920, .h = 1080 },
        self.stack.data.base_rect,
    );
    self.op_manager.append(.{
        .action = .{
            .call = .{
                .stack = &self.stack.data,
                .new_text = self.op_manager.allocator.dupe(u8, "main()") catch unreachable,
            },
        },
        .camera_motion = motion,
    });
    self.stack.stack_height += 1;
}

/// run main program loop
pub fn start(self: *Self) void {
    var timer = std.time.Timer.start() catch @panic("clock error");
    var lap_time: u64 = 0;
    while (self.running) {
        self.current_action = self.op_manager.currentActionName() orelse "Done!";
        while (sdl.events.poll()) |ev| {
            handleEvent(self, &ev);
        }
        self.main_view.portWindowRatio(.{ .x = 0, .y = 0, .w = 1, .h = 1 }, self.window);
        self.ui_view.portWindowRatio(.{ .x = 0.75, .y = 0, .w = 0.25, .h = 0.50 }, self.window);
        self.draw() catch |err| {
            if (err == sdl.errors.Error.SdlError) {
                std.log.debug("SDL error: {s}\n", .{sdl.errors.get().?});
            }
            @panic("drawing failure");
        };
        const augmented_time = @as(f64, @floatFromInt(lap_time)) * self.playback_speed;
        self.op_manager.update(
            if (self.pause) 0 else augmented_time,
            if (self.freecam) null else &self.main_view,
        );
        const passed = timer.read();
        if (passed < 4_000_000)
            std.time.sleep(4_000_000 - passed);
        lap_time = timer.lap();
    }
}

/// handle event (runs once per frame)
fn handleEvent(self: *Self, event: *const sdl.events.Event) void {
    const mouse_state = sdl.mouse.getState();
    const mousepos: sdl.rect.FPoint = .{ .x = mouse_state.x, .y = mouse_state.y };
    if (event.* == .quit) {
        self.running = false;
    }
    keyboard: {
        const key = if (event.* == .key_down) event.key_down.key orelse break :keyboard else break :keyboard;
        switch (key) {
            .escape => {
                self.running = false;
            },
            else => {},
            .left => {
                self.op_manager.undoLast();
            },
            .right => {
                self.op_manager.fastForward();
            },
            .space => {
                self.pause = !self.pause;
            },
        }
    }

    mouse: {
        const mouse_relative_state = sdl.mouse.getRelativeState();

        if (self.freecam) {
            if (mouse_state.flags.left and
                !self.ui_view.port.pointIn(mousepos.asOtherPoint(sdl.rect.IntegerType)))
            {
                const mouse_diff: sdl.rect.FPoint = .{ .x = mouse_relative_state.x, .y = mouse_relative_state.y };
                const scaled_diff: sdl.rect.FPoint = self.main_view.unscalePoint(sdl.rect.FloatingType, mouse_diff);
                self.main_view.cam.x -= scaled_diff.x;
                self.main_view.cam.y -= scaled_diff.y;
                break :mouse;
            }
            if (event.* == .mouse_wheel) {
                const delta = event.mouse_wheel.scroll_y;
                if (delta < 0)
                    self.main_view.zoom(1.0 / 1.1, mousepos)
                else
                    self.main_view.zoom(1.1, mousepos);
            }
        }

        inline for (UIElements) |elm| {
            @field(self, elm).handleEvent(event, mousepos, self.ui_view);
        }
        if (self.fastforward_btn_pressed) {
            self.op_manager.fastForward();
        }
        if (self.undo_btn_pressed) {
            self.op_manager.undoLast();
        }
    }
}

/// draw on window (runs once per frame)
fn draw(self: *Self) !void {
    try self.renderer.clear();
    // try self.ui_view.fillPort(self.renderer, .{
    //     .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
    // });
    try self.stack.data.draw(self.renderer, self.main_view);
    try self.heap.data.draw(self.renderer, self.main_view);

    // draw ui to a seperate texture to prevent clipping with main view
    try self.renderer.setTarget(self.ui_texture);
    try self.renderer.renderTexture(self.ui_bg, null, null);
    //no scaling because ui is drawn on a texture.
    inline for (UIElements) |elm| {
        try @field(self, elm).draw(null, self.renderer);
    }

    try self.renderer.setTarget(null);
    try self.renderer.setDrawColor(main_bg);

    // draw ui texture on window
    try self.renderer.renderTexture(self.ui_texture, null, self.ui_view.port.asOtherRect(sdl.rect.FloatingType));
    try self.renderer.present();
}

/// deinitiallize the program
pub fn deinit(self: *Self) void {
    self.stack.data.deinit();
    self.heap.deinit();
    self.op_manager.deinit();
    inline for (UIElements) |elm| {
        @field(self, elm).deinit();
    }
    self.fastforward_btn.design.texture.deinit();
    self.undo_btn.design.texture.deinit();
    Helpers.deinitSDL(self.window, self.renderer, self.allocator);
    self.allocator.destroy(self);
}
