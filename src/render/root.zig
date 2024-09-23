//! Cake.Render

const std = @import("std");
const build_options = @import("build_options");

pub const Errors = error{
    RenderInitializationFailed,
};

const Context = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/context.zig"),
    .d3d12 => @import("d3d12/context.zig"),
    else => @compileError("unsupported render platform: " ++ @tagName(build_options.RenderBackend)),
};

var context: Context = undefined;

pub const Options = struct {
    allocator: std.mem.Allocator,
};

pub fn init(options: Options) Errors!void {
    try context.init(options.allocator);
}

pub fn tick() !void {}
