const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdl_dep = b.dependency("sdl3", .{ .ext_image = true });
    const sdl_mod = sdl_dep.module("sdl3");
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("sdl3", sdl_mod);

    exe_mod.linkSystemLibrary("SDL3_ttf", .{});
    exe_mod.linkSystemLibrary("SDL3_mixer", .{});

    {
        const translate_c_mixer = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("c_stub.c", "#include <SDL2/SDL_mixer.h>"),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("mixer", translate_c_mixer.createModule());

        const translate_c_ttf = b.addTranslateC(.{
            .root_source_file = b.addWriteFiles().add("c_stub.c", "#include <SDL2/SDL_ttf.h>"),
            .target = target,
            .optimize = optimize,
        });
        exe_mod.addImport("ttf", translate_c_ttf.createModule());
    }

    {
        const exe = b.addExecutable(.{
            .name = "AV",
            .root_module = exe_mod,
            .use_lld = false,
            //.use_llvm = false,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const exe_unit_tests = b.addTest(.{ .root_module = exe_mod });
        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_exe_unit_tests.step);
    }
}
