//! Cake - its a piece of cake

const std = @import("std");
const cake = @import("root.zig");

const Window = @import("window.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.app");

allocator: std.mem.Allocator,
windows: std.ArrayList(*Window),

///////////////////////////////////////////////////////////////////////////////
///
pub fn init(allocator: std.mem.Allocator) !Self {
    try cake.init(.{
        .allocator = allocator,
        .app_id = "bakery",
    });
    defer cake.deinit();

    return .{
        .allocator = allocator,
        .windows = std.ArrayList(*Window).init(allocator),
    };
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn deinit(self: *Self) void {
    self.windows.deinit();
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn tick(self: *Self) !void {
    for (self.windows.items) |win| {
        try win.tick();
    }
}

///////////////////////////////////////////////////////////////////////////////
pub fn exitRequested(self: *const Self) bool {
    _ = self; // autofix
    return false;
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn createWindow(
    self: *Self,
    title: [:0]const u8,
    size: @Vector(2, u32),
) !*Window {
    const window = try self.allocator.create(Window);
    errdefer self.allocator.destroy(window);

    Log.info(
        "creating a new window named {s} w/ dimensions {}",
        .{ title, size },
    );

    window.* = try Window.init(
        self.allocator,
        title,
        size,
    );

    try self.windows.append(window);

    return window;
}

///////////////////////////////////////////////////////////////////////////////
///
pub fn destroyWindow(self: *Self, window: *Window) void {
    const idx = std.mem.indexOfScalar(*Window, self.windows.items, window);
    if (idx) |i| {
        _ = self.windows.swapRemove(i);
    }

    window.deinit();
    self.allocator.destroy(window);
}
