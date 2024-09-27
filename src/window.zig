//! Cake - its a piece of cake

const std = @import("std");
const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

const Ui = @import("ui.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.window");

const SurfaceInterface = cake_render.SurfaceInterface;
const SwapchainInterface = cake_video.SwapchainInterface;

video_surface: *cake_video.Surface,
render_surface: *cake_render.Surface,
render_swapchain: *cake_render.Swapchain,
ui_state: Ui,

///////////////////////////////////////////////////////////////////////////////
/// create a window
/// @param title the title of the window
/// @param size the size of the window
/// @return a new window
pub fn init(title: [:0]const u8, size: @Vector(2, u32)) !Self {
    const video_surface = try cake_video.createSurface(
        title,
        size,
    );

    const Anon = struct {
        fn getOsSurface(ctx: *anyopaque) *anyopaque {
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

    const render_swapchain = try cake_render.createSwapchain(
        render_surface,
    );

    const swap_interface = SwapchainInterface{
        .ptr = render_swapchain,
        .vtable = .{
            .on_resize = Anon.onResize,
        },
    };
    video_surface.swapchain = swap_interface;

    return .{
        .video_surface = video_surface,
        .render_surface = render_surface,
        .render_swapchain = render_swapchain,
        .ui_state = try Ui.init(),
    };
}

///////////////////////////////////////////////////////////////////////////////
/// destroy a window
pub fn deinit(self: Self) void {
    cake_render.destroySwapchain(self.render_swapchain);
    cake_render.destroySurface(self.render_surface);
    cake_video.destroySurface(self.video_surface);
}

///////////////////////////////////////////////////////////////////////////////
/// determine if the window should close
/// @return true if the window wants to close
pub fn wantsClose(self: Self) bool {
    return self.video_surface.close_requested;
}

///////////////////////////////////////////////////////////////////////////////
/// tick the window
pub fn tick(self: Self, tickable: TickInterface) !void {
    self.ui_state.beginFrame();

    try tickable.onTick(self.ui_state);

    self.ui_state.endFrame();
}

///////////////////////////////////////////////////////////////////////////////
/// used to abstract ticking
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
