//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");

const Context = @import("context.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.frame_buffer");

ctx: ?*Context = null,
handle: vk.Framebuffer = .null_handle,

///
pub fn init(ctx: *Context) !Self {
    const fb = try ctx.device.createFramebuffer(
        &.{},
        null,
    );
    errdefer ctx.device.destroyFramebuffer(
        fb,
        null,
    );

    return .{
        .ctx = ctx,
        .handle = fb,
    };
}

///
pub fn deinit(self: *Self) void {
    if (self.ctx) |ctx| {
        ctx.device.destroyFramebuffer(
            self.handle,
            null,
        );
    }
    self.handle = .null_handle;
}
