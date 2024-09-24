//! Cake.Render

const std = @import("std");
const build_options = @import("build_options");

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

var context: Context = undefined;
var swapchains: std.ArrayList(*Swapchain) = undefined;
var surfaces: std.ArrayList(*Surface) = undefined;

pub const Options = struct {
    allocator: std.mem.Allocator,
    app_id: [:0]const u8,
    udata: *anyopaque,
};

///////////////////////////////////////////////////////////////////////////////
/// initialize the renderer
pub fn init(options: Options) !void {
    swapchains = std.ArrayList(*Swapchain).init(options.allocator);
    surfaces = std.ArrayList(*Surface).init(options.allocator);

    try context.init(
        options.allocator,
        options.app_id,
        options.udata,
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
        const state = try sc.present(&context);
        _ = state; // autofix
    }
}

///////////////////////////////////////////////////////////////////////////////
/// create a surface
/// @param surface
/// @return a new surface
pub fn createSurface(surface: *anyopaque, size: @Vector(2, u32)) !*Surface {
    const surf = try context.allocator.create(Surface);
    errdefer context.allocator.destroy(surf);
    surf.* = try Surface.init(&context, surface, size);
    return surf;
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a surface
/// @param surface
pub fn destroySurface(surface: *Surface) void {
    surface.deinit(&context);
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
    const index = std.mem.indexOfScalar(*Swapchain, swapchains.items, swapchain);
    if (index) |i| {
        _ = swapchains.swapRemove(i);
    }

    swapchain.deinit(&context);
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
