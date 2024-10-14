//! Cake.Video - the video subsystem

const std = @import("std");
const build_options = @import("build_options");
const interface = @import("interface.zig");

pub const IntputEvent = @import("input_event.zig");

pub const Errors = error{
    VideoInitializationFailed,
    NoContext,
    NoSurfaces,
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
pub const InputListener = interface.InputListener;

var context: ?Context = null;
var surfaces: ?std.ArrayList(*Surface) = null;
var input_listeners: ?std.ArrayList(InputListener) = null;

pub const Options = struct {
    allocator: std.mem.Allocator,
    app_id: [:0]const u8,
};

/// Initialize the video module
/// @param options options to use for this module
pub fn init(options: Options) !void {
    surfaces = std.ArrayList(*Surface).init(options.allocator);
    input_listeners = std.ArrayList(InputListener).init(options.allocator);

    context = undefined;
    if (context) |*ctx| {
        try ctx.init(
            options.allocator,
            options.app_id,
        );
    } else {
        return Errors.NoContext;
    }
}

pub fn deinit() void {
    if (input_listeners) |*il| il.deinit();
    if (surfaces) |*s| s.deinit();
    if (context) |*ctx| ctx.deinit();
}

pub fn registerForInput(listener: InputListener) !void {
    if (input_listeners) |*il| {
        try il.append(listener);
    }
}

pub fn renderData() *anyopaque {
    return context.?.renderData();
}

/// Create a surface
/// @param title the title
/// @param size the dimensions of the surface
/// @return a pointer to a newly created surface
pub fn createSurface(title: [:0]const u8, size: @Vector(2, u32)) !*Surface {
    if (context) |*ctx| {
        const surf = try ctx.allocator.create(Surface);
        errdefer ctx.allocator.destroy(surf);

        try surf.init(ctx, title, size);

        if (surfaces) |*s| {
            try s.append(surf);
        } else {
            return Errors.NoSurfaces;
        }

        return surf;
    }

    return Errors.NoContext;
}

/// Destroy a surface
/// @param surface the surface to destroy
pub fn destroySurface(surface: *Surface) !void {
    if (surfaces) |*s| {
        const index = std.mem.indexOfScalar(
            *Surface,
            s.items,
            surface,
        );
        if (index) |i| {
            _ = s.swapRemove(i);
        }
    } else {
        return Errors.NoSurfaces;
    }

    surface.deinit();

    if (context) |*ctx| {
        ctx.allocator.destroy(surface);
    } else {
        return Errors.NoContext;
    }
}

/// Tick the video module
pub fn tick() !void {
    if (context) |*ctx| {
        try ctx.tick();

        try ctx.dispatchInput(input_listeners.?.items);
    } else {
        return Errors.NoContext;
    }
}
