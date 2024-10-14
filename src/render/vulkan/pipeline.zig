//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");

const Context = @import("context.zig");
const RenderPass = @import("render_pass.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.pipeline");

context: ?*Context = null,
layout: vk.PipelineLayout = .null_handle,
handle: vk.Pipeline = .null_handle,

pub fn init(ctx: *Context, rp: RenderPass) !Self {
    const layout = try ctx.device.createPipelineLayout(
        &.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        },
        null,
    );

    _ = rp;

    return .{
        .context = ctx,
        .layout = layout,
    };
}

pub fn deinit(self: *Self) void {
    if (self.context) |ctx| {
        ctx.device.destroyPipelineLayout(
            self.layout,
            null,
        );
    }
}
