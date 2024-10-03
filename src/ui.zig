//! Cake - its a piece of cake

const std = @import("std");
const cake_render = @import("cake.render");

const Self = @This();
const Log = std.log.scoped(.@"cake.ui");

allocator: std.mem.Allocator,
render_pass: cake_render.Pass,

pub fn init(allocator: std.mem.Allocator, swapchain: *cake_render.Swapchain) !Self {
    const rp = try cake_render.createPass(swapchain);

    return .{
        .allocator = allocator,
        .render_pass = rp,
    };
}

pub fn deinit(self: *Self) void {
    cake_render.destroyPass(&self.render_pass);
}

pub fn beginFrame(self: Self) void {
    _ = self; // autofix
}

pub fn endFrame(self: Self) void {
    _ = self; // autofix
}
