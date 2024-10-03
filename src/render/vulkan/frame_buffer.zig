//! Cake.Render

const std = @import("std");
const vk = @import("vulkan");

const Context = @import("context.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.frame_buffer");

ctx: *Context,
handle: vk.Framebuffer,

///////////////////////////////////////////////////////////////////////////////
///
pub fn init(
    ctx: *Context,
) !Self {
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

///////////////////////////////////////////////////////////////////////////////
///
pub fn deinit(self: *Self) void {
    self.ctx.device.destroyFramebuffer(
        self.handle,
        null,
    );
    self.handle = .null_handle;
}
