//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");

const Context = @import("context.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.command_buffer");

ctx: ?*Context = null,
handle: vk.CommandBuffer = .null_handle,

pub fn init(ctx: *Context) !Self {
    return .{
        .ctx = ctx,
        .handle = .null_handle,
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}
