//! Cake

const std = @import("std");
const builtin = @import("builtin");

const RenderBackend = enum {
    vulkan,
    d3d12,
    opengl,
    metal,
};

const VideoBackend = enum {
    wayland,
    x11,
    win32,
    osx,
};

pub fn build(b: *std.Build) void {
    const render_backend = b.option(
        RenderBackend,
        "RenderBackend",
        "The render backend to use for cake",
    ) orelse switch (builtin.os.tag) {
        .macos => .metal,
        else => .vulkan,
    };

    const video_backend = b.option(
        VideoBackend,
        "VideoBackend",
        "The video backend to use for cake",
    ) orelse switch (builtin.os.tag) {
        .linux => .wayland,
        .windows => .windows,
        .macos => .osx,
        else => @panic("unsupported video backend"),
    };

    const render_options = b.addOptions();
    render_options.addOption(RenderBackend, "RenderBackend", render_backend);

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cake_render = b.addModule("cake.render", .{
        .root_source_file = b.path("src/render/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cake_render.addOptions("build_options", render_options);

    const video_options = b.addOptions();
    video_options.addOption(VideoBackend, "VideoBackend", video_backend);

    const cake_video = b.addModule("cake.video", .{
        .root_source_file = b.path("src/video/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cake_video.addOptions("build_options", video_options);

    const cake = b.addModule("cake", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cake.addImport("cake.video", cake_video);
    cake.addImport("cake.render", cake_render);

    const exe = b.addExecutable(.{
        .name = "cake",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("cake", cake);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
