//! Cake.Render

const std = @import("std");
const vk = @import("vulkan");
const Context = @import("context.zig");
const Surface = @import("surface.zig");

const Self = @This();

pub const PresentState = enum {
    optimal,
    suboptimal,
};

allocator: std.mem.Allocator,

surface: *Surface,
surface_format: vk.SurfaceFormatKHR,
present_mode: vk.PresentModeKHR,
extent: vk.Extent2D,
handle: vk.SwapchainKHR,

swap_images: []u8,
image_index: u32,
next_image: vk.Semaphore,

///////////////////////////////////////////////////////////////////////////////
/// initialize a swapchain from scratch
/// @param ctx
/// @param surface
/// @return a new swapchain
pub fn init(ctx: *Context, surface: *Surface) !Self {
    return try initRecycle(
        ctx,
        surface,
        .null_handle,
    );
}

///////////////////////////////////////////////////////////////////////////////
/// initialize a swapchain, releasing the old one
/// @param ctx
/// @param size
/// @param old_handle
/// @return a new swapchain
pub fn initRecycle(
    ctx: *Context,
    surface: *Surface,
    old_handle: vk.SwapchainKHR,
) !Self {
    const caps = try ctx.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(
        ctx.pdev,
        surface.handle,
    );

    const surface_format = find_surface_format: {
        const pref: vk.SurfaceFormatKHR = .{
            .format = .b8g8r8a8_srgb,
            .color_space = .srgb_nonlinear_khr,
        };
        const surface_formats = try ctx.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(
            ctx.pdev,
            surface.handle,
            ctx.allocator,
        );
        defer ctx.allocator.free(surface_formats);

        for (surface_formats) |sfmt| {
            if (std.meta.eql(sfmt, pref)) {
                break :find_surface_format pref;
            }
        }

        break :find_surface_format surface_formats[0]; // There must always be at least one supported surface format
    };

    const present_mode = find_present_mode: {
        const pref = [_]vk.PresentModeKHR{
            .mailbox_khr,
            .immediate_khr,
        };

        const present_modes = try ctx.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(
            ctx.pdev,
            surface.handle,
            ctx.allocator,
        );
        defer ctx.allocator.free(present_modes);

        for (pref) |mode| {
            if (std.mem.indexOfScalar(vk.PresentModeKHR, present_modes, mode) != null) {
                break :find_present_mode mode;
            }
        }

        break :find_present_mode .fifo_khr;
    };

    var image_count = caps.min_image_count + 1;
    if (caps.max_image_count > 0) {
        image_count = @min(image_count, caps.max_image_count);
    }

    const qfi = [_]u32{ surface.graphics_queue.family, surface.present_queue.family };
    const sharing_mode: vk.SharingMode = if (surface.graphics_queue.family != surface.present_queue.family)
        .concurrent
    else
        .exclusive;

    const handle = try ctx.device.createSwapchainKHR(
        &.{
            .surface = surface.handle,
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = .{ .width = 0, .height = 0 },
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true },
            .image_sharing_mode = sharing_mode,
            .queue_family_index_count = qfi.len,
            .p_queue_family_indices = &qfi,
            .pre_transform = caps.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = old_handle,
        },
        null,
    );
    errdefer ctx.device.destroySwapchainKHR(handle, null);

    if (old_handle != .null_handle) {
        // Apparently, the old swapchain handle still needs to be destroyed after recreating.
        ctx.device.destroySwapchainKHR(old_handle, null);
    }

    //const swap_images = try initSwapchainImages(gc, handle, surface_format.format, allocator);
    //errdefer {
    //    for (swap_images) |si| si.deinit(gc);
    //    allocator.free(swap_images);
    //}

    const next_image_acquired = try ctx.device.createSemaphore(
        &.{},
        null,
    );
    errdefer ctx.device.destroySemaphore(next_image_acquired, null);

    const result = try ctx.device.acquireNextImageKHR(
        handle,
        std.math.maxInt(u64),
        next_image_acquired,
        .null_handle,
    );
    if (result.result != .success) {
        return error.ImageAcquireFailed;
    }

    //std.mem.swap(vk.Semaphore, &swap_images[result.image_index].image_acquired, &next_image_acquired);

    return .{
        .allocator = ctx.allocator,
        .surface = surface,
        .surface_format = surface_format,
        .present_mode = present_mode,
        .extent = .{ .width = 0, .height = 0 },
        .handle = handle,
        .swap_images = &[_]u8{},
        .image_index = result.image_index,
        .next_image = next_image_acquired,
    };
}

///////////////////////////////////////////////////////////////////////////////
pub fn deinit(self: *Self, ctx: *Context) void {
    _ = self; // autofix
    _ = ctx; // autofix
}

///////////////////////////////////////////////////////////////////////////////
/// present this swapchain
/// @param ctx the render context
/// @return
pub fn present(
    self: *Self,
    ctx: *Context,
) !PresentState {
    const wait_stage = [_]vk.PipelineStageFlags{.{ .top_of_pipe_bit = true }};
    try ctx.device.queueSubmit(
        self.surface.graphics_queue.handle,
        1,
        &[_]vk.SubmitInfo{
            .{
                .wait_semaphore_count = 1,
                .p_wait_semaphores = null,
                .p_wait_dst_stage_mask = &wait_stage,
                .command_buffer_count = 1,
                .p_command_buffers = null,
                .signal_semaphore_count = 1,
                .p_signal_semaphores = null,
            },
        },
        .null_handle,
    );

    _ = try ctx.device.queuePresentKHR(
        self.surface.present_queue.handle,
        &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = null,
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.handle),
            .p_image_indices = @ptrCast(&self.image_index),
        },
    );

    const result = try ctx.device.acquireNextImageKHR(
        self.handle,
        std.math.maxInt(u64),
        self.next_image,
        .null_handle,
    );

    self.image_index = result.image_index;

    return switch (result.result) {
        .success => .optimal,
        .suboptimal_khr => .suboptimal,
        else => unreachable,
    };
}
