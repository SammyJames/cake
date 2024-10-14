//! Cake - its a piece of cake

const std = @import("std");
const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

const Ui = @import("ui.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.window");

const SurfaceInterface = cake_render.SurfaceInterface;
const SwapchainInterface = cake_video.SwapchainInterface;

allocator: std.mem.Allocator,
video: struct {
    surface: *cake_video.Surface,
},
render: struct {
    surface: *cake_render.Surface,
    swapchain: *cake_render.Swapchain,
},

on_tick: ?TickInterface,
ui_state: Ui,

/// Create a window
/// @param title the title of the window
/// @param size the size of the window
/// @return a new window
pub fn init(
    allocator: std.mem.Allocator,
    title: [:0]const u8,
    size: @Vector(2, u32),
) !Self {
    const video_surface = try cake_video.createSurface(
        title,
        size,
    );
    errdefer cake_video.destroySurface(video_surface) catch
        @panic("failed to destroy surface");

    const Anon = struct {
        fn getOsSurface(ctx: *anyopaque) !*anyopaque {
            const surf: *cake_video.Surface = @ptrCast(@alignCast(ctx));
            return surf.surface;
        }

        fn getSize(ctx: *anyopaque) @Vector(2, u32) {
            const surf: *cake_video.Surface = @ptrCast(@alignCast(ctx));
            return surf.size;
        }

        fn onResize(ctx: *anyopaque, sz: @Vector(2, u32)) !void {
            const swpchain: *cake_render.Swapchain = @ptrCast(@alignCast(ctx));
            try swpchain.recreate(sz);
        }
    };

    const render_surface = try cake_render.createSurface(
        SurfaceInterface{
            .ptr = video_surface,
            .vtable = .{
                .get_os_surface = Anon.getOsSurface,
                .get_size = Anon.getSize,
            },
        },
    );
    errdefer cake_render.destroySurface(render_surface) catch
        @panic("unable to destroy surface");

    const swapchain = try cake_render.createSwapchain(
        render_surface,
    );
    errdefer cake_render.destroySwapchain(swapchain) catch
        @panic("unable to destroy swapchain");

    const swap_interface = SwapchainInterface{
        .ptr = swapchain,
        .vtable = .{
            .on_resize = Anon.onResize,
        },
    };
    video_surface.swapchain = swap_interface;

    return .{
        .allocator = allocator,
        .video = .{
            .surface = video_surface,
        },
        .render = .{
            .surface = render_surface,
            .swapchain = swapchain,
        },
        .on_tick = null,
        .ui_state = try Ui.init(allocator, swapchain),
    };
}

/// Destroy a window
pub fn deinit(self: *Self) void {
    self.ui_state.deinit();
    cake_render.destroySwapchain(self.render.swapchain) catch |err| {
        std.debug.panic("failed to destroy swapchain {s}", .{
            @errorName(err),
        });
    };

    cake_render.destroySurface(self.render.surface) catch |err| {
        std.debug.panic("failed to destroy surface {s}", .{
            @errorName(err),
        });
    };

    cake_video.destroySurface(self.video.surface) catch |err| {
        std.debug.panic("failed to destroy surface {s}", .{
            @errorName(err),
        });
    };
}

/// Determine if the window should close
/// @return true if the window wants to close
pub fn closeRequested(self: Self) bool {
    return self.video.surface.close_requested;
}

/// Tick the window
pub fn tick(self: Self) !void {
    self.ui_state.beginFrame();

    if (self.on_tick) |*ot| {
        try ot.onTick(self.ui_state);
    }

    self.ui_state.endFrame();
}

/// Used to abstract ticking
pub const TickInterface = struct {
    ptr: *anyopaque,
    vtable: struct {
        on_tick: *const fn (*anyopaque, Ui) anyerror!void,
    },

    fn onTick(self: @This(), ui_state: Ui) !void {
        try @call(
            .auto,
            self.vtable.on_tick,
            .{ self.ptr, ui_state },
        );
    }
};

/// Update this window's title
/// @param title the title to use
pub fn setTitle(self: Self, title: [:0]const u8) void {
    self.video.surface.setTitle(title);
}

/// Update this window's size
/// @param size the size
pub fn setSize(self: Self, size: @Vector(2, u32)) void {
    self.video.surface.setSize(size);
}
