//! Cake.Render - the render subsystem

const std = @import("std");

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    var result: Self = undefined;
    result.allocator = allocator;

    return result;
}
