//! Cake.Video

const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const xdg = wayland.client.xdg;
const zxdg = wayland.client.zxdg;

const Self = @This();
const Log = std.log.scoped(.@"cake.video.wayland");
const Errors = error{
    RoundtripFailed,
};

allocator: std.mem.Allocator,
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

pub fn init(self: *Self, allocator: std.mem.Allocator) !void {
    self.allocator = allocator;
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

pub fn tick(self: *Self) !void {
    if (self.display.roundtrip() != .SUCCESS) {
        return Errors.RoundtripFailed;
    }
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, self: *Self) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Seat.getInterface().name) == .eq) {
                self.seat = registry.bind(global.name, wl.Seat, 1) catch return;
                self.seat.setListener(*Self, seatListener, self);
            } else if (std.mem.orderZ(u8, global.interface, wl.Compositor.getInterface().name) == .eq) {
                self.compositor = registry.bind(global.name, wl.Compositor, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.getInterface().name) == .eq) {
                self.shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Output.getInterface().name) == .eq) {
                self.output = registry.bind(global.name, wl.Output, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, xdg.WmBase.getInterface().name) == .eq) {
                self.xdg_wm_base = registry.bind(global.name, xdg.WmBase, 1) catch return;
                self.xdg_wm_base.setListener(*Self, xdgWmBaseListener, self);
            } else if (std.mem.orderZ(u8, global.interface, zxdg.DecorationManagerV1.getInterface().name) == .eq) {
                self.zxdg_decoration_man = registry.bind(global.name, zxdg.DecorationManagerV1, 1) catch return;
            } else {
                Log.debug("ignoring {s}", .{global.interface});
            }
        },
        .global_remove => {},
    }
}

fn seatListener(_: *wl.Seat, event: wl.Seat.Event, self: *Self) void {
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

fn xdgWmBaseListener(wm_base: *xdg.WmBase, event: xdg.WmBase.Event, _: *Self) void {
    switch (event) {
        .ping => |s| {
            Log.debug("wm ping {} => pong", .{s.serial});
            wm_base.pong(s.serial);
        },
    }
}

pub const Surface = struct {
    surface: *wl.Surface,
    region: *wl.Region,
    xdg_surface: *xdg.Surface,
    top_level: *xdg.Toplevel,
    decoration: *zxdg.ToplevelDecorationV1,

    size: @Vector(2, u32),
    close_requested: bool,

    state: enum {
        waiting_for_configuration,
        configured,
    },

    pub fn deinit(self: *@This()) void {
        self.surface.destroy();
        self.region.destroy();
        self.xdg_surface.destroy();
        self.top_level.destroy();
        self.decoration.destroy();
    }

    fn updateOpaqueArea(self: *@This()) void {
        self.region.add(0, 0, @intCast(self.size[0]), @intCast(self.size[1]));
        self.surface.setOpaqueRegion(self.region);
        self.region.subtract(0, 0, @intCast(self.size[0]), @intCast(self.size[1]));

        // todo update swapchain
    }

    fn xdgSurfaceListener(surface: *xdg.Surface, event: xdg.Surface.Event, self: *@This()) void {
        switch (event) {
            .configure => |c| {
                surface.ackConfigure(c.serial);

                switch (self.state) {
                    .waiting_for_configuration => self.state = .configured,
                    else => self.surface.commit(),
                }
            },
        }
    }

    fn topLevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, self: *@This()) void {
        switch (event) {
            .configure => |c| {
                self.size = @Vector(2, u32){ @intCast(c.width), @intCast(c.height) };
                self.updateOpaqueArea();
            },
            .close => {
                self.close_requested = true;
            },
        }
    }
};

pub fn createSurface(self: *Self, size: @Vector(2, u32)) !*Surface {
    var result = try self.allocator.create(Surface);
    errdefer self.allocator.destroy(result);

    result.size = size;
    result.close_requested = false;
    result.surface = try self.compositor.createSurface();
    result.region = try self.compositor.createRegion();

    result.xdg_surface = try self.xdg_wm_base.getXdgSurface(result.surface);
    result.top_level = try result.xdg_surface.getToplevel();

    result.xdg_surface.setWindowGeometry(0, 0, @intCast(size[0]), @intCast(size[1]));

    result.xdg_surface.setListener(*Surface, Surface.xdgSurfaceListener, result);
    result.top_level.setListener(*Surface, Surface.topLevelListener, result);

    result.surface.commit();

    result.state = .waiting_for_configuration;
    while (self.display.dispatch() == .SUCCESS and result.state != .configured) {}

    result.decoration = try self.zxdg_decoration_man.getToplevelDecoration(result.top_level);
    result.decoration.setMode(.server_side);

    result.surface.commit();

    if (self.display.roundtrip() != .SUCCESS) {
        return Errors.RoundtripFailed;
    }

    return result;
}
