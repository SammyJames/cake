//! Cake - its a piece of cake

const std = @import("std");
const cake = @import("cake");

const log_cake = std.log.scoped(.cake);

pub fn main() !void {
    log_cake.info("welcome to the cake test application", .{});
    defer log_cake.info("exiting...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const alloc = gpa.allocator();

    try cake.init(.{
        .allocator = alloc,
    });
}
