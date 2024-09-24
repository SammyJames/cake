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
    defer cake.deinit();

    const win1 = try cake.Window.init("Bakery", .{ 1920, 1080 });
    defer win1.deinit();

    const win2 = try cake.Window.init("Bakery", .{ 1024, 768 });
    defer win2.deinit();

    while (!win1.wantsClose() and !win2.wantsClose()) {
        try win1.tick();
        try win2.tick();
        try cake.tick();
    }
}
