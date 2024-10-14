//! Cake.Render - the render subsystem

const std = @import("std");
const build_options = @import("build_options");
const interface = @import("interface.zig");

pub const Errors = error{
    RenderInitializationFailed,
    NoContext,
    NoSurfaces,
    NoSwapchains,
};

const Context = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/context.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const Swapchain = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/swapchain.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const Surface = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/surface.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const Pass = switch (build_options.RenderBackend) {
    .vulkan => @import("vulkan/render_pass.zig"),
    else => @compileError(
        "unsupported render platform: " ++ @tagName(build_options.RenderBackend),
    ),
};

pub const VideoInterface = interface.Video;
pub const SurfaceInterface = interface.Surface;

var context: ?Context = null;
var swapchains: ?std.ArrayList(*Swapchain) = null;
var surfaces: ?std.ArrayList(*Surface) = null;

pub const Options = struct {
    /// the allocator interface to use for the renderer
    allocator: std.mem.Allocator,
    /// the application id string used to identify things
    app_id: [:0]const u8,
    /// an interface to the video subsystem
    video: VideoInterface,
};

///////////////////////////////////////////////////////////////////////////////
/// initialize the renderer
/// @param options the options to use for the render subsystem
pub fn init(options: Options) !void {
    swapchains = std.ArrayList(*Swapchain).init(options.allocator);
    surfaces = std.ArrayList(*Surface).init(options.allocator);

    context = undefined;
    if (context) |*ctx| {
        try ctx.init(
            options.allocator,
            options.app_id,
            options.video,
        );
    }
}

///////////////////////////////////////////////////////////////////////////////
/// deinit
pub fn deinit() void {
    if (swapchains) |*sc| sc.deinit();
    if (surfaces) |*sf| sf.deinit();
    if (context) |*ctx| ctx.deinit();

    context = null;
}

///////////////////////////////////////////////////////////////////////////////
/// tick the renderer
pub fn tick() !void {
    if (swapchains) |*chains| {
        for (chains.items) |sc| {
            const state = try sc.present();

            switch (state) {
                .optimal => {},
                .suboptimal => {},
            }
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
/// create a surface
/// @param surface
/// @return a new surface
pub fn createSurface(surface: SurfaceInterface) !*Surface {
    if (context) |*ctx| {
        const surf = try ctx.allocator.create(Surface);
        errdefer ctx.allocator.destroy(surf);
        surf.* = try Surface.init(ctx, surface);

        if (surfaces) |*s| {
            try s.append(surf);
        } else {
            return Errors.NoSurfaces;
        }

        return surf;
    }

    return Errors.NoContext;
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a surface
/// @param surface
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

///////////////////////////////////////////////////////////////////////////////
/// create a swapchain for a surface
/// @param surface
/// @return a new swapchain
pub fn createSwapchain(surface: *Surface) !*Swapchain {
    if (context) |*ctx| {
        const swap = try ctx.allocator.create(Swapchain);
        errdefer ctx.allocator.destroy(swap);
        swap.* = try Swapchain.init(ctx, surface);

        if (swapchains) |*s| {
            try s.append(swap);
        } else {
            return Errors.NoSwapchains;
        }

        return swap;
    }

    return Errors.NoContext;
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a swapchain
/// @param swapchain
pub fn destroySwapchain(swapchain: *Swapchain) !void {
    if (swapchains) |*s| {
        const index = std.mem.indexOfScalar(
            *Swapchain,
            s.items,
            swapchain,
        );
        if (index) |i| {
            _ = s.swapRemove(i);
        }
    } else {
        return Errors.NoSwapchains;
    }

    swapchain.deinit();

    if (context) |*ctx| {
        ctx.allocator.destroy(swapchain);
    } else {
        return Errors.NoContext;
    }
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn createPass(swapchain: *Swapchain) !Pass {
    if (context) |*ctx| {
        return try Pass.init(ctx, swapchain);
    }

    return Errors.NoContext;
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn destroyPass(render_pass: *Pass) void {
    render_pass.deinit();
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn begin() !void {
    if (context) |*ctx| {
        try ctx.begin();
    } else {
        return Errors.NoContext;
    }
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn end() !void {
    if (context) |*ctx| {
        ctx.end();
    } else {
        return Errors.NoContext;
    }
}
