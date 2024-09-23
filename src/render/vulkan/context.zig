//! Cake.Render

const std = @import("std");

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    self.allocator = allocator;
}
