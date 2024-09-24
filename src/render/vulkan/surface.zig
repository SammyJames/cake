//! Cake.Render

const std = @import("std");
const vk = @import("vulkan");
const types = @import("types.zig");
const interface = @import("../interface.zig");
const Context = @import("context.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.surface");

const Queue = struct {
    handle: vk.Queue,
    family: u32,

    fn init(device: types.Device, family: u32) Queue {
        return .{
            .handle = device.getDeviceQueue(family, 0),
            .family = family,
        };
    }
};

handle: vk.SurfaceKHR,
video_surface: interface.Surface,
graphics_queue: Queue,
present_queue: Queue,

///////////////////////////////////////////////////////////////////////////////
/// initialize a surface
/// @param ctx
/// @param surface
/// @return a new surface
pub fn init(ctx: *Context, surface: interface.Surface) !Self {
    const handle = try ctx.instance.createWaylandSurfaceKHR(
        &.{
            .display = @ptrCast(@alignCast(ctx.video.getOsDisplay())),
            .surface = @ptrCast(@alignCast(surface.getOsSurface())),
        },
        null,
    );

    Log.debug("surface created: {}", .{handle});

    return .{
        .handle = handle,
        .video_surface = surface,
        .graphics_queue = Queue.init(ctx.device, ctx.queues.graphics_family),
        .present_queue = Queue.init(ctx.device, ctx.queues.present_family),
    };
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn deinit(self: *Self, ctx: *Context) void {
    ctx.instance.destroySurfaceKHR(self.handle, null);
}
