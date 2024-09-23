//! Cake.Video

const std = @import("std");
const build_options = @import("build_options");

pub const Errors = error{
    VideoInitializationFailed,
};

const Context = switch (build_options.VideoBackend) {
    .wayland => @import("wayland.zig"),
    .win32 => @import("win32.zig"),
    else => @compileError("unsupported video platform: " ++ @tagName(build_options.VideoBackend)),
};

var context: ?Context = null;

pub const Options = struct {
    allocator: std.mem.Allocator,
};

pub fn init(options: Options) Errors!void {
    context = try Context.init(options.allocator);
}
