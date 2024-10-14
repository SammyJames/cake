//! Cake.Video - the video subsystem

const std = @import("std");
const wayland = @import("wayland");
const interface = @import("../interface.zig");
const Context = @import("context.zig");

const wl = wayland.client.wl;
const xdg = wayland.client.xdg;
const zxdg = wayland.client.zxdg;

const Self = @This();
const Log = std.log.scoped(.@"cake.video.wayland.surface");
const Errors = error{
    RoundtripFailed,
};

ctx: *const Context,
surface: *wl.Surface,
xdg_surface: *xdg.Surface,
top_level: *xdg.Toplevel,
decoration: *zxdg.ToplevelDecorationV1,

size: @Vector(2, u32),
close_requested: bool,
swapchain: ?interface.Swapchain,

state: enum {
    waiting_for_configuration,
    configured,
},

///////////////////////////////////////////////////////////////////////////////
/// initialize a surface, expects the memory for this surface to have been
/// allocated prior to calling init
/// @param ctx the wayland video context
/// @param title the title of the surface
/// @param size the dimensions of the surface
pub fn init(
    self: *Self,
    ctx: *const Context,
    title: [:0]const u8,
    size: @Vector(2, u32),
) !void {
    self.ctx = ctx;
    self.size = size;
    self.close_requested = false;
    self.swapchain = null;
    self.surface = try ctx.compositor.createSurface();

    self.xdg_surface = try ctx.xdg_wm_base.getXdgSurface(self.surface);
    self.top_level = try self.xdg_surface.getToplevel();

    self.xdg_surface.setWindowGeometry(
        0,
        0,
        @intCast(size[0]),
        @intCast(size[1]),
    );

    self.xdg_surface.setListener(
        *Self,
        Self.xdgSurfaceListener,
        self,
    );
    self.top_level.setListener(
        *Self,
        Self.topLevelListener,
        self,
    );

    self.setTitle(title);
    self.setAppId(ctx.app_id);

    self.surface.commit();

    self.state = .waiting_for_configuration;
    while (ctx.display.dispatch() == .SUCCESS and self.state != .configured) {
        try std.Thread.yield();
    }

    self.decoration = try ctx.zxdg_decoration_man.getToplevelDecoration(
        self.top_level,
    );
    self.decoration.setMode(.server_side);

    self.surface.commit();

    if (ctx.display.roundtrip() != .SUCCESS) {
        return Errors.RoundtripFailed;
    }
}

///////////////////////////////////////////////////////////////////////////////
pub fn deinit(self: *Self) void {
    self.surface.destroy();
    self.xdg_surface.destroy();
    self.top_level.destroy();
    self.decoration.destroy();
}

///////////////////////////////////////////////////////////////////////////////
/// set the title
/// @param title the title
pub fn setTitle(self: *Self, title: [:0]const u8) void {
    self.top_level.setTitle(title.ptr);
}

///////////////////////////////////////////////////////////////////////////////
/// set the size of the surface
/// @param size
pub fn setSize(self: *Self, size: @Vector(2, u32)) void {
    self.xdg_surface.setWindowGeometry(
        0,
        0,
        @intCast(size[0]),
        @intCast(size[1]),
    );
}

///////////////////////////////////////////////////////////////////////////////
/// set the app id
/// @param app_id the application identifier
fn setAppId(self: *Self, app_id: [:0]const u8) void {
    self.top_level.setAppId(app_id.ptr);
}

///////////////////////////////////////////////////////////////////////////////
fn updateOpaqueArea(self: *Self) !void {
    var region = try self.ctx.compositor.createRegion();
    defer region.destroy();

    region.add(
        0,
        0,
        @intCast(self.size[0]),
        @intCast(self.size[1]),
    );
    self.surface.setOpaqueRegion(region);
}

///////////////////////////////////////////////////////////////////////////////
fn xdgSurfaceListener(
    surface: *xdg.Surface,
    event: xdg.Surface.Event,
    self: *Self,
) void {
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

///////////////////////////////////////////////////////////////////////////////
fn topLevelListener(
    _: *xdg.Toplevel,
    event: xdg.Toplevel.Event,
    self: *Self,
) void {
    switch (event) {
        .configure => |c| {
            const w: u32 = @intCast(c.width);
            const h: u32 = @intCast(c.height);

            if (w == 0 and h == 0) {
                return;
            }

            if (self.size[0] == w and self.size[1] == h) {
                return;
            }

            self.size = @Vector(2, u32){ w, h };

            Log.debug("{p} configure {}", .{ self.surface, self.size });

            if (self.swapchain) |*sc| {
                sc.onResize(self.size) catch |err| {
                    Log.err("failed to resize swapchain: {s}", .{@errorName(err)});
                };
            }

            self.updateOpaqueArea() catch |err| {
                Log.err("failed to update opaque area {s}", .{@errorName(err)});
            };

            self.surface.commit();
        },
        .configure_bounds => |_| {},
        .wm_capabilities => |_| {},
        .close => {
            self.close_requested = true;
        },
    }
}
