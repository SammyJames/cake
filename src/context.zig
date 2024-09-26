//! Cake - its a piece of cake

const std = @import("std");

const Self = @This();
const Log = std.log.scoped(.@"cake.context");

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    return .{
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    _ = self; // autofix
}
