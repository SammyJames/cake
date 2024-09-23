//! Cake - its a piece of cake

const std = @import("std");
const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

pub const Errors = error{
    InitFailed,
};

/// options for initializing cake!
pub const Options = struct {
    /// the allocator! we're gunna abuse this bad boy
    allocator: std.mem.Allocator,
};

pub const InitErrors = Errors || cake_video.Errors || cake_render.Errors;
pub fn init(options: Options) InitErrors!void {
    try cake_video.init(.{
        .allocator = options.allocator,
    });

    try cake_render.init(.{
        .allocator = options.allocator,
    });
}
