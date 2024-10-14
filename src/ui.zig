//! Cake - its a piece of cake

const std = @import("std");
const cake_render = @import("cake.render");

const Self = @This();
const Log = std.log.scoped(.@"cake.ui");

allocator: std.mem.Allocator,
render_pass: cake_render.Pass,
pipeline: cake_render.Pipeline,

/// Initialize the ui
/// @param allocator the allocator
/// @param swapchain the swapchain we're rendering ui to
/// @return a new ui context
pub fn init(allocator: std.mem.Allocator, swapchain: *cake_render.Swapchain) !Self {
    const rp = try cake_render.createPass(swapchain);
    const pipeline = try cake_render.createPipeline(rp);

    return .{
        .allocator = allocator,
        .pipeline = pipeline,
        .render_pass = rp,
    };
}

pub fn deinit(self: *Self) void {
    self.pipeline.deinit();
    self.render_pass.deinit();
}

pub fn beginFrame(self: Self) void {
    cake_render.begin(self.render_pass) catch |err| {
        Log.err("failed to begin {s}", .{
            @errorName(err),
        });
    };
}

pub fn endFrame(self: Self) void {
    cake_render.end(self.render_pass) catch |err| {
        Log.err("failed to end {s}", .{
            @errorName(err),
        });
    };
}
