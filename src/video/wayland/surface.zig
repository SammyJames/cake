//! Cake.Video

const std = @import("std");
const wayland = @import("wayland");
const Context = @import("context.zig");

const wl = wayland.client.wl;
const xdg = wayland.client.xdg;
const zxdg = wayland.client.zxdg;

const Self = @This();
const Errors = error{
    RoundtripFailed,
};

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

pub fn create(ctx: *const Context, size: @Vector(2, u32)) !*Self {
    var result = try ctx.allocator.create(Self);
    errdefer ctx.allocator.destroy(result);

    result.size = size;
    result.close_requested = false;
    result.surface = try ctx.compositor.createSurface();
    result.region = try ctx.compositor.createRegion();

    result.xdg_surface = try ctx.xdg_wm_base.getXdgSurface(result.surface);
    result.top_level = try result.xdg_surface.getToplevel();

    result.xdg_surface.setWindowGeometry(0, 0, @intCast(size[0]), @intCast(size[1]));

    result.xdg_surface.setListener(*Self, Self.xdgSurfaceListener, result);
    result.top_level.setListener(*Self, Self.topLevelListener, result);

    result.surface.commit();

    result.state = .waiting_for_configuration;
    while (ctx.display.dispatch() == .SUCCESS and result.state != .configured) {}

    result.decoration = try ctx.zxdg_decoration_man.getToplevelDecoration(result.top_level);
    result.decoration.setMode(.server_side);

    result.surface.commit();

    if (ctx.display.roundtrip() != .SUCCESS) {
        return Errors.RoundtripFailed;
    }

    return result;
}

pub fn deinit(self: *Self) void {
    self.surface.destroy();
    self.region.destroy();
    self.xdg_surface.destroy();
    self.top_level.destroy();
    self.decoration.destroy();
}

fn updateOpaqueArea(self: *Self) void {
    self.region.add(0, 0, @intCast(self.size[0]), @intCast(self.size[1]));
    self.surface.setOpaqueRegion(self.region);
    self.region.subtract(0, 0, @intCast(self.size[0]), @intCast(self.size[1]));

    // todo update swapchain
}

fn xdgSurfaceListener(surface: *xdg.Surface, event: xdg.Surface.Event, self: *Self) void {
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

fn topLevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, self: *Self) void {
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
