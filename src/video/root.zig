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

pub const Surface = Context.Surface;

var context: Context = undefined;

pub const Options = struct {
    allocator: std.mem.Allocator,
};

pub fn init(options: Options) !void {
    try context.init(options.allocator);
}

/// create a surface
pub fn createSurface(size: @Vector(2, u32)) !*Surface {
    return try context.createSurface(size);
}

pub fn destroySurface(surface: *Surface) void {
    surface.deinit();
    context.allocator.destroy(surface);
}

pub fn tick() !void {
    try context.tick();
}
