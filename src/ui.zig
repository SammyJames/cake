//! Cake - its a piece of cake

const std = @import("std");

const Self = @This();
const Log = std.log.scoped(.@"cake.ui");

pub fn init() !Self {
    return .{};
}

pub fn deinit(self: Self) void {
    _ = self; // autofix
}

pub fn beginFrame(self: Self) void {
    _ = self; // autofix
}

pub fn endFrame(self: Self) void {
    _ = self; // autofix
}
