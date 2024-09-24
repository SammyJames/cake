//! Cake.Video

const std = @import("std");
const build_options = @import("build_options");
const interface = @import("interface.zig");

pub const Errors = error{
    VideoInitializationFailed,
};

const Context = switch (build_options.VideoBackend) {
    .wayland => @import("wayland/context.zig"),
    .win32 => @import("win32/context.zig"),
    else => @compileError("unsupported video platform: " ++ @tagName(build_options.VideoBackend)),
};

pub const Surface = switch (build_options.VideoBackend) {
    .wayland => @import("wayland/surface.zig"),
    .win32 => @import("win32/surface.zig"),
    else => @compileError("unsupported video platform: " ++ @tagName(build_options.VideoBackend)),
};

pub const SwapchainInterface = interface.Swapchain;

var context: Context = undefined;
var surfaces: std.ArrayList(*Surface) = undefined;

pub const Options = struct {
    allocator: std.mem.Allocator,
    app_id: [:0]const u8,
};

///////////////////////////////////////////////////////////////////////////////
/// initialize the video module
/// @param options options to use for this module
pub fn init(options: Options) !void {
    surfaces = std.ArrayList(*Surface).init(options.allocator);
    try context.init(options.allocator, options.app_id);
}

///////////////////////////////////////////////////////////////////////////////
pub fn deinit() void {
    surfaces.deinit();
    context.deinit();
}

///////////////////////////////////////////////////////////////////////////////
pub fn renderData() *anyopaque {
    return context.renderData();
}

///////////////////////////////////////////////////////////////////////////////
/// create a surface
/// @param title the title
/// @param size the dimensions of the surface
/// @return a pointer to a newly created surface
pub fn createSurface(title: [:0]const u8, size: @Vector(2, u32)) !*Surface {
    const surf = try context.allocator.create(Surface);
    errdefer context.allocator.destroy(surf);
    try surf.init(&context, title, size);

    try surfaces.append(surf);

    return surf;
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a surface
/// @param surface the surface to destroy
pub fn destroySurface(surface: *Surface) void {
    const index = std.mem.indexOfScalar(*Surface, surfaces.items, surface);
    if (index) |i| {
        _ = surfaces.swapRemove(i);
    }

    surface.deinit();
    context.allocator.destroy(surface);
}

///////////////////////////////////////////////////////////////////////////////
/// tick the video module
pub fn tick() !void {
    try context.tick();
}
