//! Cake.Render

const std = @import("std");
const build_options = @import("build_options");
const interface = @import("interface.zig");

pub const Errors = error{
    RenderInitializationFailed,
};

const Context = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/context.zig"),
    .d3d12 => @import("d3d12/context.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const Swapchain = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/swapchain.zig"),
    .d3d12 => @import("d3d12/swapchain.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const Surface = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/surface.zig"),
    .d3d12 => @import("d3d12/surface.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const VideoInterface = interface.Video;
pub const SurfaceInterface = interface.Surface;

var context: Context = undefined;
var swapchains: std.ArrayList(*Swapchain) = undefined;
var surfaces: std.ArrayList(*Surface) = undefined;

pub const Options = struct {
    allocator: std.mem.Allocator,
    app_id: [:0]const u8,
    video: VideoInterface,
};

///////////////////////////////////////////////////////////////////////////////
/// initialize the renderer
pub fn init(options: Options) !void {
    swapchains = std.ArrayList(*Swapchain).init(options.allocator);
    surfaces = std.ArrayList(*Surface).init(options.allocator);

    try context.init(
        options.allocator,
        options.app_id,
        options.video,
    );
}

///////////////////////////////////////////////////////////////////////////////
/// deinit
pub fn deinit() void {
    swapchains.deinit();
    surfaces.deinit();

    context.deinit();
}

///////////////////////////////////////////////////////////////////////////////
/// tick the renderer
pub fn tick() !void {
    for (swapchains.items) |sc| {
        const state = try sc.present();

        switch (state) {
            .optimal => {},
            .suboptimal => {},
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
/// create a surface
/// @param surface
/// @return a new surface
pub fn createSurface(surface: SurfaceInterface) !*Surface {
    const surf = try context.allocator.create(Surface);
    errdefer context.allocator.destroy(surf);
    surf.* = try Surface.init(&context, surface);

    try surfaces.append(surf);

    return surf;
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a surface
/// @param surface
pub fn destroySurface(surface: *Surface) void {
    const index = std.mem.indexOfScalar(
        *Surface,
        surfaces.items,
        surface,
    );
    if (index) |i| {
        _ = surfaces.swapRemove(i);
    }

    surface.deinit();
    context.allocator.destroy(surface);
}

///////////////////////////////////////////////////////////////////////////////
/// create a swapchain for a surface
/// @param surface
/// @return a new swapchain
pub fn createSwapchain(surface: *Surface) !*Swapchain {
    const swap = try context.allocator.create(Swapchain);
    errdefer context.allocator.destroy(swap);
    swap.* = try Swapchain.init(&context, surface);

    try swapchains.append(swap);

    return swap;
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a swapchain
/// @param swapchain
pub fn destroySwapchain(swapchain: *Swapchain) void {
    const index = std.mem.indexOfScalar(
        *Swapchain,
        swapchains.items,
        swapchain,
    );
    if (index) |i| {
        _ = swapchains.swapRemove(i);
    }

    swapchain.deinit();
    context.allocator.destroy(swapchain);
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn begin() !void {
    try context.begin();
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn end() !void {
    context.end();
}
