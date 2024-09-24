//! Cake - its a piece of cake

const std = @import("std");
const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

pub const Errors = error{
    InitFailed,
};

pub const Window = @import("window.zig");

/// options for initializing cake!
pub const Options = struct {
    /// the allocator! we're gunna abuse this bad boy
    allocator: std.mem.Allocator,
    /// common identifier for this application
    app_id: [:0]const u8 = "cake",
};

///////////////////////////////////////////////////////////////////////////////
/// initialize cake
/// @param options the options touse for initialization
pub fn init(options: Options) !void {
    try cake_video.init(.{
        .allocator = options.allocator,
        .app_id = options.app_id,
    });

    try cake_render.init(.{
        .allocator = options.allocator,
        .app_id = options.app_id,
        .udata = cake_video.renderData(),
    });
}

///////////////////////////////////////////////////////////////////////////////
/// tick cake
pub fn tick() !void {
    try cake_video.tick();
    try cake_render.tick();
}
