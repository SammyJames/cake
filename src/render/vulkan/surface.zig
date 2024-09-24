//! Cake.Render

const std = @import("std");
const vk = @import("vulkan");
const types = @import("types.zig");
const Context = @import("context.zig");

const Self = @This();

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
graphics_queue: Queue,
present_queue: Queue,

///////////////////////////////////////////////////////////////////////////////
/// initialize a surface
/// @param ctx
/// @param surface
/// @return a new surface
pub fn init(ctx: *Context, surface: *anyopaque) !Self {
    const handle = try ctx.instance.createWaylandSurfaceKHR(
        &.{
            .display = @ptrCast(@alignCast(ctx.udata)),
            .surface = @ptrCast(@alignCast(surface)),
        },
        null,
    );

    return .{
        .handle = handle,
        .graphics_queue = Queue.init(ctx.device, 0),
        .present_queue = Queue.init(ctx.device, 0),
    };
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn deinit(self: *Self, ctx: *Context) void {
    ctx.instance.destroySurfaceKHR(self.handle, null);
}
