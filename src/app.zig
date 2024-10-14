//! Cake - its a piece of cake

const std = @import("std");
const cake = @import("root.zig");

const Window = @import("window.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.app");

allocator: std.mem.Allocator,
windows: std.ArrayList(*Window),

/// Initialize a cake application
/// @param allocator the allocator interface for cake to use
/// @return a new cake application
pub fn init(allocator: std.mem.Allocator) !Self {
    try cake.init(.{
        .allocator = allocator,
        .app_id = "bakery",
    });
    errdefer cake.deinit();

    return .{
        .allocator = allocator,
        .windows = std.ArrayList(*Window).init(allocator),
    };
}

///
pub fn deinit(self: *Self) void {
    self.windows.deinit();

    cake.deinit();
}

///
pub fn tick(self: *Self) !void {
    for (self.windows.items) |win| {
        try win.tick();
    }

    try cake.tick();
}

/// Determine if the application should exit, by default this checks all
/// windows to determine if they want to close
pub fn exitRequested(self: *const Self) bool {
    var result = false;
    for (self.windows.items) |w| {
        result = result or w.closeRequested();
    }

    return result;
}

/// Create a window
/// @param title the title of the application
/// @param size the dimensions of the window being created
/// @return a new window
pub fn createWindow(self: *Self, title: [:0]const u8, size: @Vector(2, u32)) !*Window {
    const window = try self.allocator.create(Window);
    errdefer self.allocator.destroy(window);

    Log.info("Creating a new window named {s} w/ dimensions {}", .{
        title,
        size,
    });

    window.* = try Window.init(
        self.allocator,
        title,
        size,
    );

    try self.windows.append(window);

    return window;
}

/// Destroy a window
/// @param window the window to destroy
pub fn destroyWindow(self: *Self, window: *Window) void {
    const idx = std.mem.indexOfScalar(
        *Window,
        self.windows.items,
        window,
    );

    if (idx) |i| {
        _ = self.windows.swapRemove(i);
    }

    window.deinit();
    self.allocator.destroy(window);
}
