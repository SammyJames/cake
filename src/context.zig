//! Cake

const std = @import("std");

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    _ = self; // autofix
}
