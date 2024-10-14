//! Cake - its a piece of cake

const std = @import("std");
const cake = @import("cake");

const assert = std.debug.assert;

const Log = std.log.scoped(.cake);

pub fn main() !void {
    Log.info("Welcome to the cake test application", .{});
    defer Log.info("exiting...", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const alloc = gpa.allocator();

    var app = try cake.App.init(alloc);
    defer app.deinit();

    const w1 = try app.createWindow("Bakery", .{ 1920, 1080 });
    var main_window = MainWindow.init(w1);
    defer main_window.deinit(&app);

    w1.on_tick = main_window.tickable();

    var w2 = try app.createWindow("Bakery", .{ 1024, 768 });
    var secondary_window = SecondaryWindow.init(w2);
    defer secondary_window.deinit(&app);

    w2.on_tick = secondary_window.tickable();

    main_window.window.setSize(.{ 2560, 1440 });

    while (!app.exitRequested()) {
        try app.tick();
    }
}

const MainWindow = struct {
    const Self = @This();

    window: *cake.Window,

    fn init(window: *cake.Window) Self {
        return .{
            .window = window,
        };
    }

    fn deinit(self: *Self, app: *cake.App) void {
        app.destroyWindow(self.window);
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

    window: *cake.Window,

    fn init(window: *cake.Window) Self {
        return .{
            .window = window,
        };
    }

    fn deinit(self: *Self, app: *cake.App) void {
        app.destroyWindow(self.window);
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
