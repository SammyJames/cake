//! Cake - its a piece of cake

const std = @import("std");
const cake = @import("cake");

const Log = std.log.scoped(.cake);

pub fn main() !void {
    Log.info("Welcome to the cake test application", .{});
    defer Log.info("exiting...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const alloc = gpa.allocator();

    try cake.init(.{
        .allocator = alloc,
        .app_id = "bakery",
    });

    const win = try cake.Window.init("Bakery", @Vector(2, u32){ 1920, 1080 });
    defer win.deinit();

    while (!win.wantsClose()) {
        try win.tick();
        try cake.tick();
    }
}
