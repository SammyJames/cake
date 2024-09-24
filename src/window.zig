//! Cake

const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

const Self = @This();

video_surface: *cake_video.Surface,
render_surface: *cake_render.Surface,
render_swapchain: *cake_render.Swapchain,

///////////////////////////////////////////////////////////////////////////////
///
pub fn init(title: [:0]const u8, size: @Vector(2, u32)) !Self {
    const video_surface = try cake_video.createSurface(title, size);
    const render_surface = try cake_render.createSurface(video_surface.surface);
    return .{
        .video_surface = video_surface,
        .render_surface = render_surface,
        .render_swapchain = try cake_render.createSwapchain(render_surface),
    };
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn deinit(self: Self) void {
    cake_render.destroySwapchain(self.render_swapchain);
    cake_render.destroySurface(self.render_surface);
    cake_video.destroySurface(self.video_surface);
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn wantsClose(self: Self) bool {
    return self.video_surface.close_requested;
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn tick(self: Self) !void {
    try cake_render.present(self.render_swapchain);
}
