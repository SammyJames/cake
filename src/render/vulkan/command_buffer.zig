//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");

const Context = @import("context.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.command_buffer");

ctx: *Context,
handle: vk.CommandBuffer,

pub fn init(ctx: *Context) !Self {
    _ = ctx; // autofix
}

pub fn deinit(self: *Self) void {
    _ = self;
}
