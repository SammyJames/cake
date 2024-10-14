//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");

const Context = @import("context.zig");
const Swapchain = @import("swapchain.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.render_pass");

ctx: ?*Context = null,
handle: vk.RenderPass = .null_handle,

/// initialize a render pass for a swapchain
/// @param ctx the context
/// @param swapchain the swapchain that owns this render pass
/// @return a new render pass
pub fn init(ctx: *Context, swapchain: *Swapchain) !Self {
    const rp = try ctx.device.createRenderPass(
        &.{
            .attachment_count = 1,
            .p_attachments = &.{
                .{
                    .format = swapchain.surface_format.format,
                    .samples = .{ .@"1_bit" = true },
                    .load_op = .clear,
                    .store_op = .store,
                    .stencil_load_op = .dont_care,
                    .stencil_store_op = .dont_care,
                    .initial_layout = .undefined,
                    .final_layout = .present_src_khr,
                },
            },
            .subpass_count = 1,
            .p_subpasses = &.{
                .{
                    .pipeline_bind_point = .graphics,
                    .color_attachment_count = 1,
                    .p_color_attachments = &.{
                        .{
                            .attachment = 0,
                            .layout = .color_attachment_optimal,
                        },
                    },
                },
            },
        },
        null,
    );
    errdefer ctx.device.destroyRenderPass(
        rp,
        null,
    );

    return .{
        .ctx = ctx,
        .handle = rp,
    };
}

///
pub fn deinit(self: *Self) void {
    if (self.ctx) |ctx| {
        ctx.device.destroyRenderPass(
            self.handle,
            null,
        );
    }
    self.handle = .null_handle;
}
