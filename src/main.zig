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

    var main_window = MainWindow.init(
        try cake.Window.init("Bakery", .{ 1920, 1080 }),
    );
    defer main_window.deinit();

    var secondary_window = SecondaryWindow.init(
        try cake.Window.init("Bakery", .{ 1024, 768 }),
    );
    defer secondary_window.deinit();

    main_window.window.setSize(.{ 2560, 1440 });

    while (!main_window.window.wantsClose() and !secondary_window.window.wantsClose()) {
        try main_window.tick();
        try secondary_window.tick();
        try cake.tick();
    }
}

const MainWindow = struct {
    const Self = @This();

    window: cake.Window,

    fn init(window: cake.Window) Self {
        return .{
            .window = window,
        };
    }

    fn deinit(self: *Self) void {
        self.window.deinit();
    }

    fn tick(self: *Self) !void {
        try self.window.tick(self.tickable());
    }

    fn update_ui(self: *Self, ui: cake.Ui) !void {
        _ = self; // autofix
        _ = ui; // autofix
    }

    fn tickable(self: *Self) cake.Window.TickInterface {
        const Anon = struct {
            fn tickAnon(ctx: *anyopaque, ui: cake.Ui) !void {
                const win: *Self = @ptrCast(@alignCast(ctx));
                try win.update_ui(ui);
            }
        };

        return .{
            .ptr = self,
            .vtable = .{
                .on_tick = Anon.tickAnon,
            },
        };
    }
};

const SecondaryWindow = struct {
    const Self = @This();

    window: cake.Window,

    fn init(window: cake.Window) Self {
        return .{
            .window = window,
        };
    }

    fn deinit(self: *Self) void {
        self.window.deinit();
    }

    fn tick(self: *Self) !void {
        try self.window.tick(self.tickable());
    }

    fn update_ui(self: *Self, ui: cake.Ui) !void {
        _ = self; // autofix
        _ = ui; // autofix
    }

    fn tickable(self: *Self) cake.Window.TickInterface {
        const Anon = struct {
            fn tickAnon(ctx: *anyopaque, ui: cake.Ui) !void {
                const win: *Self = @ptrCast(@alignCast(ctx));
                try win.update_ui(ui);
            }
        };

        return .{
            .ptr = self,
            .vtable = .{
                .on_tick = Anon.tickAnon,
            },
        };
    }
};
