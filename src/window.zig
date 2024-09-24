//! Cake

const std = @import("std");
const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

const Self = @This();

video_surface: *cake_video.Surface,
render_surface: *cake_render.Surface,
render_swapchain: *cake_render.Swapchain,

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
    const render_surface = try cake_render.createSurface(
        video_surface.surface,
        size,
    );
    return .{
        .video_surface = video_surface,
        .render_surface = render_surface,
        .render_swapchain = try cake_render.createSwapchain(render_surface),
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
pub fn tick(self: Self) !void {
    _ = self; // autofix
}
