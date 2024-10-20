//! Cake - its a piece of cake

const std = @import("std");
const cake_video = @import("cake.video");
const cake_render = @import("cake.render");

pub const App = @import("app.zig");
pub const Window = @import("window.zig");
pub const Ui = @import("ui.zig");
pub const Input = cake_video.Input;

pub const Errors = error{
    InitFailed,
};

/// options for initializing cake!
pub const Options = struct {
    /// the allocator! we're gunna abuse this bad boy
    allocator: std.mem.Allocator,
    /// common identifier for this application
    app_id: [:0]const u8 = "cake",
};

/// Initialize cake
/// @param options the options touse for initialization
pub fn init(options: Options) !void {
    const Anon = struct {
        fn getOsDisplay(ctx: *anyopaque) !*anyopaque {
            return ctx;
        }
    };

    try cake_video.init(.{
        .allocator = options.allocator,
        .app_id = options.app_id,
    });

    try cake_render.init(.{
        .allocator = options.allocator,
        .app_id = options.app_id,
        .video = cake_render.VideoInterface{
            .ptr = cake_video.renderData(),
            .vtable = .{
                .get_os_display = Anon.getOsDisplay,
            },
        },
    });
}

/// Deinit cake
pub fn deinit() void {
    cake_render.deinit();
    cake_video.deinit();
}

/// Tick cake
pub fn tick() !void {
    try cake_video.tick();
    try cake_render.tick();
}

pub fn registerForInput(priority: Input.Priority, listener: Input.Listener) !void {
    try cake_video.registerForInput(priority, listener);
}
