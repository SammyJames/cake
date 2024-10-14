//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");
const Context = @import("context.zig");
const Surface = @import("surface.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan.swapchain");
const Errors = error{
    QueuePresentFailed,
    ImageAcquireFailed,
    FenceWaitFailed,
};

pub const PresentState = enum {
    optimal,
    suboptimal,
};

ctx: *Context,

surface: *Surface,
surface_format: vk.SurfaceFormatKHR,
present_mode: vk.PresentModeKHR,
extent: vk.Extent2D,
handle: vk.SwapchainKHR,

swap_images: []SwapImage,
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

    const extents: vk.Extent2D = find_extents: {
        const size = surface.video_surface.getSize();

        if (caps.current_extent.width != 0xFFFF_FFFF) {
            break :find_extents caps.current_extent;
        } else {
            break :find_extents .{
                .width = std.math.clamp(
                    size[0],
                    caps.min_image_extent.width,
                    caps.max_image_extent.width,
                ),
                .height = std.math.clamp(
                    size[1],
                    caps.min_image_extent.height,
                    caps.max_image_extent.height,
                ),
            };
        }
    };

    Log.debug("{} extents {}", .{ surface.handle, extents });

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

    Log.debug("{} format {}", .{ surface.handle, surface_format });

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

    Log.debug("{} present mode {}", .{ surface.handle, present_mode });

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
            .image_extent = extents,
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
        ctx.device.destroySwapchainKHR(old_handle, null);
    }

    const swap_images = try initSwapchainImages(
        ctx,
        handle,
        surface_format.format,
    );
    errdefer {
        for (swap_images) |si| si.deinit(ctx);
        ctx.allocator.free(swap_images);
    }

    var next_image_acquired = try ctx.device.createSemaphore(
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
        return Errors.ImageAcquireFailed;
    }

    std.mem.swap(
        vk.Semaphore,
        &swap_images[result.image_index].image_acquired,
        &next_image_acquired,
    );

    return .{
        .ctx = ctx,
        .surface = surface,
        .surface_format = surface_format,
        .present_mode = present_mode,
        .extent = extents,
        .handle = handle,
        .swap_images = swap_images,
        .image_index = result.image_index,
        .next_image = next_image_acquired,
    };
}

///////////////////////////////////////////////////////////////////////////////
pub fn deinit(self: *Self) void {
    self.deinitExceptSwapchain();
    self.ctx.device.destroySwapchainKHR(
        self.handle,
        null,
    );
}

///////////////////////////////////////////////////////////////////////////////
fn deinitExceptSwapchain(self: *Self) void {
    for (self.swap_images) |si| {
        si.deinit(self.ctx);
    }
    self.ctx.allocator.free(self.swap_images);
    self.ctx.device.destroySemaphore(
        self.next_image,
        null,
    );
}

///////////////////////////////////////////////////////////////////////////////
pub fn recreate(self: *Self, size: @Vector(2, u32)) !void {
    _ = size; // autofix
    const old_ctx = self.ctx;
    const old_handle = self.handle;
    const old_surf = self.surface;
    self.deinitExceptSwapchain();
    self.* = try initRecycle(
        old_ctx,
        old_surf,
        old_handle,
    );
}

///////////////////////////////////////////////////////////////////////////////
pub fn waitForAllFences(self: *Self) !void {
    for (self.swap_images) |si| {
        try si.waitForFence(self.ctx);
    }
}

///////////////////////////////////////////////////////////////////////////////
pub fn currentImage(self: *Self) vk.Image {
    return self.swap_images[self.image_index].image;
}

///////////////////////////////////////////////////////////////////////////////
pub fn currentSwapImage(self: *Self) *const SwapImage {
    return &self.swap_images[self.image_index];
}

///////////////////////////////////////////////////////////////////////////////
/// present this swapchain
/// @param ctx the render context
/// @return
pub fn present(self: *Self) !PresentState {
    //Log.debug("present {}", .{self.surface.handle});

    const current = self.currentSwapImage();
    try current.waitForFence(self.ctx);
    try self.ctx.device.resetFences(1, @ptrCast(&current.frame_fence));

    const wait_stage = [_]vk.PipelineStageFlags{
        .{ .top_of_pipe_bit = true },
    };
    try self.ctx.device.queueSubmit(
        self.surface.graphics_queue.handle,
        1,
        &[_]vk.SubmitInfo{
            .{
                .wait_semaphore_count = 1,
                .p_wait_semaphores = @ptrCast(&current.image_acquired),
                .p_wait_dst_stage_mask = &wait_stage,
                .command_buffer_count = 0,
                .p_command_buffers = null,
                .signal_semaphore_count = 1,
                .p_signal_semaphores = @ptrCast(&current.render_finished),
            },
        },
        current.frame_fence,
    );

    if (try self.ctx.device.queuePresentKHR(
        self.surface.present_queue.handle,
        &.{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&current.render_finished),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.handle),
            .p_image_indices = @ptrCast(&self.image_index),
        },
    ) != .success) {
        return Errors.QueuePresentFailed;
    }

    const result = try self.ctx.device.acquireNextImageKHR(
        self.handle,
        std.math.maxInt(u64),
        self.next_image,
        .null_handle,
    );

    std.mem.swap(
        vk.Semaphore,
        &self.swap_images[result.image_index].image_acquired,
        &self.next_image,
    );
    self.image_index = result.image_index;

    return switch (result.result) {
        .success => .optimal,
        .suboptimal_khr => .suboptimal,
        else => unreachable,
    };
}

///////////////////////////////////////////////////////////////////////////////
const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,

    ///////////////////////////////////////////////////////////////////////////
    fn init(ctx: *const Context, image: vk.Image, format: vk.Format) !@This() {
        const view = try ctx.device.createImageView(
            &.{
                .image = image,
                .view_type = .@"2d",
                .format = format,
                .components = .{
                    .r = .identity,
                    .g = .identity,
                    .b = .identity,
                    .a = .identity,
                },
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            },
            null,
        );
        errdefer ctx.device.destroyImageView(
            view,
            null,
        );

        const image_acquired = try ctx.device.createSemaphore(
            &.{},
            null,
        );
        errdefer ctx.device.destroySemaphore(
            image_acquired,
            null,
        );

        const render_finished = try ctx.device.createSemaphore(
            &.{},
            null,
        );
        errdefer ctx.device.destroySemaphore(
            render_finished,
            null,
        );

        const frame_fence = try ctx.device.createFence(
            &.{ .flags = .{ .signaled_bit = true } },
            null,
        );
        errdefer ctx.device.destroyFence(frame_fence, null);

        return .{
            .image = image,
            .view = view,
            .image_acquired = image_acquired,
            .render_finished = render_finished,
            .frame_fence = frame_fence,
        };
    }

    ///////////////////////////////////////////////////////////////////////////
    fn deinit(self: @This(), ctx: *const Context) void {
        self.waitForFence(ctx) catch return;
        ctx.device.destroyImageView(self.view, null);
        ctx.device.destroySemaphore(self.image_acquired, null);
        ctx.device.destroySemaphore(self.render_finished, null);
        ctx.device.destroyFence(self.frame_fence, null);
    }

    ///////////////////////////////////////////////////////////////////////////
    fn waitForFence(self: @This(), ctx: *const Context) !void {
        if (try ctx.device.waitForFences(
            1,
            @ptrCast(&self.frame_fence),
            vk.TRUE,
            std.math.maxInt(u64),
        ) != .success) {
            return Errors.FenceWaitFailed;
        }
    }
};

///////////////////////////////////////////////////////////////////////////////
///
fn initSwapchainImages(
    ctx: *const Context,
    swapchain: vk.SwapchainKHR,
    format: vk.Format,
) ![]SwapImage {
    const images = try ctx.device.getSwapchainImagesAllocKHR(
        swapchain,
        ctx.allocator,
    );
    defer ctx.allocator.free(images);

    const swap_images = try ctx.allocator.alloc(
        SwapImage,
        images.len,
    );
    errdefer ctx.allocator.free(swap_images);

    var i: usize = 0;
    errdefer for (swap_images[0..i]) |si| si.deinit(ctx);

    for (images) |image| {
        swap_images[i] = try SwapImage.init(
            ctx,
            image,
            format,
        );
        i += 1;
    }

    return swap_images;
}
