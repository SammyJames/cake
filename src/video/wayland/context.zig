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
output: *wl.Output,
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
pub fn renderData(self: *Self) *anyopaque {
    return self.display;
}

///////////////////////////////////////////////////////////////////////////////
/// tick the wayland video context
pub fn tick(self: *Self) !void {
    if (self.display.dispatchPending() != .SUCCESS) {
        return Errors.DispatchFailed;
    }
}

///////////////////////////////////////////////////////////////////////////////
fn registryListener(
    registry: *wl.Registry,
    event: wl.Registry.Event,
    self: *Self,
) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(
                u8,
                global.interface,
                wl.Seat.getInterface().name,
            ) == .eq) {
                self.seat = registry.bind(
                    global.name,
                    wl.Seat,
                    1,
                ) catch return;
                self.seat.setListener(
                    *Self,
                    seatListener,
                    self,
                );
            } else if (std.mem.orderZ(
                u8,
                global.interface,
                wl.Compositor.getInterface().name,
            ) == .eq) {
                self.compositor = registry.bind(
                    global.name,
                    wl.Compositor,
                    1,
                ) catch return;
            } else if (std.mem.orderZ(
                u8,
                global.interface,
                wl.Shm.getInterface().name,
            ) == .eq) {
                self.shm = registry.bind(
                    global.name,
                    wl.Shm,
                    1,
                ) catch return;
            } else if (std.mem.orderZ(
                u8,
                global.interface,
                wl.Output.getInterface().name,
            ) == .eq) {
                self.output = registry.bind(
                    global.name,
                    wl.Output,
                    1,
                ) catch return;
            } else if (std.mem.orderZ(
                u8,
                global.interface,
                xdg.WmBase.getInterface().name,
            ) == .eq) {
                self.xdg_wm_base = registry.bind(
                    global.name,
                    xdg.WmBase,
                    1,
                ) catch return;
                self.xdg_wm_base.setListener(
                    *Self,
                    xdgWmBaseListener,
                    self,
                );
            } else if (std.mem.orderZ(
                u8,
                global.interface,
                zxdg.DecorationManagerV1.getInterface().name,
            ) == .eq) {
                self.zxdg_decoration_man = registry.bind(
                    global.name,
                    zxdg.DecorationManagerV1,
                    1,
                ) catch return;
            } else {
                Log.debug("ignoring {s}", .{global.interface});
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
