//! Cake.Video

const std = @import("std");
const wayland = @import("wayland");
const Surface = @import("surface.zig");

const wl = wayland.client.wl;
const xdg = wayland.client.xdg;
const zxdg = wayland.client.zxdg;

const Self = @This();
const Log = std.log.scoped(.@"cake.video.wayland");
const Errors = error{
    RoundtripFailed,
    DispatchFailed,
};

allocator: std.mem.Allocator,
app_id: [:0]const u8,
display: *wl.Display,
registry: *wl.Registry,
compositor: *wl.Compositor,
shm: *wl.Shm,
outputs: std.ArrayList(*wl.Output),
xdg_wm_base: *xdg.WmBase,
zxdg_decoration_man: *zxdg.DecorationManagerV1,
seat: *wl.Seat,

state: enum {
    invalid,
    waiting_on_capabilities,
    capabilities_found,
} = .invalid,

///////////////////////////////////////////////////////////////////////////////
/// initialize the wayland video context
/// @param allocator the allocator interface to use
/// @param app_id the application identifier
pub fn init(self: *Self, allocator: std.mem.Allocator, app_id: [:0]const u8) !void {
    self.allocator = allocator;
    self.app_id = app_id;

    self.display = try wl.Display.connect(null);
    self.registry = try self.display.getRegistry();

    self.outputs = std.ArrayList(*wl.Output).init(allocator);

    self.registry.setListener(*Self, registryListener, self);

    self.state = .waiting_on_capabilities;
    while (self.state != .capabilities_found) {
        // get that registry callback firing
        if (self.display.roundtrip() != .SUCCESS) {
            return Errors.RoundtripFailed;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
pub fn deinit(self: *Self) void {
    for (self.outputs.items) |o| o.destroy();
    self.outputs.deinit();

    self.registry.destroy();
    self.compositor.destroy();
    self.shm.destroy();
    self.xdg_wm_base.destroy();
    self.zxdg_decoration_man.destroy();
    self.seat.destroy();
    self.display.disconnect();
}

///////////////////////////////////////////////////////////////////////////////
pub fn renderData(self: *Self) *anyopaque {
    return self.display;
}

///////////////////////////////////////////////////////////////////////////////
/// tick the wayland video context
pub fn tick(self: *Self) !void {
    var fds = [_]std.posix.pollfd{
        .{ .fd = self.display.getFd(), .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = -1, .events = std.posix.POLL.IN, .revents = 0 },
    };

    var event = false;
    while (!event) {
        while (!self.display.prepareRead()) {
            if (self.display.dispatchPending() == .SUCCESS) {
                return;
            }
        }

        //if (!self.flushDisplay()) {
        //    self.display.cancelRead();
        //    // todo(sjames) - close windows
        //}

        if (try std.posix.poll(&fds, 1) == 0) {
            self.display.cancelRead();
            return;
        }

        if ((fds[0].revents & std.posix.POLL.IN) == std.posix.POLL.IN) {
            _ = self.display.readEvents();
            if (self.display.dispatchPending() == .SUCCESS) {
                event = true;
            }
        } else {
            self.display.cancelRead();
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
fn flushDisplay(self: *Self) bool {
    while (self.display.flush() != .SUCCESS) {
        var fds = [_]std.posix.pollfd{
            .{ .fd = self.display.getFd(), .events = std.posix.POLL.IN, .revents = 0 },
        };

        while (try std.posix.poll(&fds, -1) == -1) {}
    }

    return true;
}

///////////////////////////////////////////////////////////////////////////////
fn registryListener(
    registry: *wl.Registry,
    event: wl.Registry.Event,
    self: *Self,
) void {
    const Handlers = struct {
        fn handleCompositor(
            s: *Self,
            r: *wl.Registry,
            name: u32,
        ) void {
            s.compositor = r.bind(name, wl.Compositor, 6) catch |err| {
                std.debug.panic("failed to bind compositor interface {s}", .{@errorName(err)});
            };
        }

        fn handleSeat(s: *Self, r: *wl.Registry, name: u32) void {
            s.seat = r.bind(name, wl.Seat, 9) catch |err| {
                std.debug.panic("failed to bind seat interface {s}", .{@errorName(err)});
            };

            s.seat.setListener(*Self, seatListener, s);
        }

        fn handleShm(s: *Self, r: *wl.Registry, name: u32) void {
            s.shm = r.bind(name, wl.Shm, 2) catch |err| {
                std.debug.panic("failed to bind shm interface {s}", .{@errorName(err)});
            };
        }

        fn handleOutput(s: *Self, r: *wl.Registry, name: u32) void {
            const output = r.bind(name, wl.Output, 4) catch |err| {
                std.debug.panic("failed to bind output interface {s}", .{@errorName(err)});
            };

            s.outputs.append(output) catch |err| {
                std.debug.panic("failed to append to output list {s}", .{@errorName(err)});
            };
        }

        fn handleWmBase(s: *Self, r: *wl.Registry, name: u32) void {
            s.xdg_wm_base = r.bind(name, xdg.WmBase, 6) catch |err| {
                std.debug.panic("failed to bind wmbase interface {s}", .{@errorName(err)});
            };
            s.xdg_wm_base.setListener(*Self, xdgWmBaseListener, s);
        }

        fn handleDecorationMan(s: *Self, r: *wl.Registry, name: u32) void {
            s.zxdg_decoration_man = r.bind(name, zxdg.DecorationManagerV1, 1) catch |err| {
                std.debug.panic("failed to bind decoration man interface {s}", .{@errorName(err)});
            };
        }
    };

    const Handler = *const fn (s: *Self, r: *wl.Registry, name: u32) void;
    const handlers = std.StaticStringMap(Handler).initComptime(.{
        .{ "wl_compositor", Handlers.handleCompositor },
        .{ "wl_shm", Handlers.handleShm },
        .{ "wl_seat", Handlers.handleSeat },
        .{ "wl_output", Handlers.handleOutput },
        .{ "xdg_wm_base", Handlers.handleWmBase },
        .{ "zxdg_decoration_manager_v1", Handlers.handleDecorationMan },
    });

    switch (event) {
        .global => |global| {
            if (handlers.get(std.mem.span(global.interface))) |func| {
                Log.info("Binding {s}", .{global.interface});
                @call(.auto, func, .{ self, registry, global.name });
            }
        },
        .global_remove => {},
    }
}

///////////////////////////////////////////////////////////////////////////////
fn seatListener(
    _: *wl.Seat,
    event: wl.Seat.Event,
    self: *Self,
) void {
    switch (event) {
        .capabilities => |caps| {
            Log.debug(
                "seat capabilities\n\tPointer {}\n\tKeyboard {}\n\tTouch {}\n",
                .{
                    caps.capabilities.pointer,
                    caps.capabilities.keyboard,
                    caps.capabilities.touch,
                },
            );
            self.state = .capabilities_found;
        },
    }
}

///////////////////////////////////////////////////////////////////////////////
fn xdgWmBaseListener(
    wm_base: *xdg.WmBase,
    event: xdg.WmBase.Event,
    _: *Self,
) void {
    switch (event) {
        .ping => |s| {
            Log.debug("wm ping {} => pong", .{s.serial});
            wm_base.pong(s.serial);
        },
    }
}
