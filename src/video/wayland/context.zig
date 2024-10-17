//! Cake.Video - the video subsystem
const std = @import("std");
const wayland = @import("wayland");
const Surface = @import("surface.zig");
const Input = @import("../input/root.zig");

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
xdg_wm_base: *xdg.WmBase,
zxdg_decoration_man: *zxdg.DecorationManagerV1,
seat: *wl.Seat,
outputs: std.ArrayList(*wl.Output),

input: struct {
    pointer: *wl.Pointer,
    keyboard: *wl.Keyboard,
    modifiers: Input.Event.Modifiers,
    queue: std.fifo.LinearFifo(Input.Event, .Dynamic),

    ctx: Input.XKB.Context,
    state: Input.XKB.State,
    keymap: Input.XKB.Keymap,
},

state: enum {
    invalid,
    waiting_on_capabilities,
    capabilities_found,
} = .invalid,

var xkb: Input.XKB = undefined;
var INIT_XKB = std.once(Private.initXkb);

const Private = struct {
    fn initXkb() void {
        xkb = Input.XKB.load() catch |err| {
            std.debug.panic("failed to load xkb {s}", .{
                @errorName(err),
            });
        };
    }
};

/// Initialize the wayland video context
/// @param allocator the allocator interface to use
/// @param app_id the application identifier
pub fn init(self: *Self, allocator: std.mem.Allocator, app_id: [:0]const u8) !void {
    self.allocator = allocator;
    self.app_id = app_id;

    INIT_XKB.call();

    self.input.modifiers = std.mem.zeroInit(Input.Event.Modifiers, .{});
    self.input.queue = std.fifo.LinearFifo(Input.Event, .Dynamic).init(allocator);
    self.input.ctx = try xkb.newContext();

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

pub fn deinit(self: *Self) void {
    self.input.queue.deinit();

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

/// Get the display
pub fn renderData(self: *Self) *anyopaque {
    return self.display;
}

/// Tick the wayland video context
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

fn flushDisplay(self: *Self) bool {
    while (self.display.flush() != .SUCCESS) {
        var fds = [_]std.posix.pollfd{
            .{ .fd = self.display.getFd(), .events = std.posix.POLL.IN, .revents = 0 },
        };

        while (try std.posix.poll(&fds, -1) == -1) {}
    }

    return true;
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, self: *Self) void {
    const Handlers = struct {
        fn handleCompositor(s: *Self, r: *wl.Registry, name: u32, ver: u32) void {
            s.compositor = r.bind(name, wl.Compositor, ver) catch |err| {
                std.debug.panic(
                    "failed to bind compositor interface {s}",
                    .{@errorName(err)},
                );
            };
        }

        fn handleSeat(s: *Self, r: *wl.Registry, name: u32, ver: u32) void {
            s.seat = r.bind(name, wl.Seat, ver) catch |err| {
                std.debug.panic(
                    "failed to bind seat interface {s}",
                    .{@errorName(err)},
                );
            };

            s.seat.setListener(*Self, seatListener, s);
        }

        fn handleShm(s: *Self, r: *wl.Registry, name: u32, ver: u32) void {
            s.shm = r.bind(name, wl.Shm, ver) catch |err| {
                std.debug.panic(
                    "failed to bind shm interface {s}",
                    .{@errorName(err)},
                );
            };
        }

        fn handleOutput(s: *Self, r: *wl.Registry, name: u32, ver: u32) void {
            const output = r.bind(name, wl.Output, ver) catch |err| {
                std.debug.panic(
                    "failed to bind output interface {s}",
                    .{@errorName(err)},
                );
            };

            s.outputs.append(output) catch |err| {
                std.debug.panic(
                    "failed to append to output list {s}",
                    .{@errorName(err)},
                );
            };
        }

        fn handleWmBase(s: *Self, r: *wl.Registry, name: u32, ver: u32) void {
            s.xdg_wm_base = r.bind(name, xdg.WmBase, ver) catch |err| {
                std.debug.panic(
                    "failed to bind wmbase interface {s}",
                    .{@errorName(err)},
                );
            };
            s.xdg_wm_base.setListener(*Self, xdgWmBaseListener, s);
        }

        fn handleDecorationMan(s: *Self, r: *wl.Registry, name: u32, ver: u32) void {
            s.zxdg_decoration_man = r.bind(name, zxdg.DecorationManagerV1, ver) catch |err| {
                std.debug.panic(
                    "failed to bind decoration man interface {s}",
                    .{@errorName(err)},
                );
            };
        }
    };

    const Handler = struct {
        func: *const fn (s: *Self, r: *wl.Registry, name: u32, version: u32) void,
        version: u32,
    };
    const handlers = std.StaticStringMap(Handler).initComptime(.{
        .{ "wl_compositor", .{ .func = Handlers.handleCompositor, .version = 6 } },
        .{ "wl_shm", .{ .func = Handlers.handleShm, .version = 2 } },
        .{ "wl_seat", .{ .func = Handlers.handleSeat, .version = 9 } },
        .{ "wl_output", .{ .func = Handlers.handleOutput, .version = 4 } },
        .{ "xdg_wm_base", .{ .func = Handlers.handleWmBase, .version = 6 } },
        .{ "zxdg_decoration_manager_v1", .{ .func = Handlers.handleDecorationMan, .version = 1 } },
    });

    switch (event) {
        .global => |g| {
            if (handlers.get(std.mem.span(g.interface))) |h| {
                Log.debug("Binding {s} @ v{}", .{
                    g.interface,
                    h.version,
                });

                @call(
                    .auto,
                    h.func,
                    .{ self, registry, g.name, h.version },
                );
            }
        },
        .global_remove => |g| {
            Log.debug("removing {}", .{
                g.name,
            });
        },
    }
}

fn seatListener(seat: *wl.Seat, event: wl.Seat.Event, self: *Self) void {
    switch (event) {
        .capabilities => |c| {
            Log.debug("seat capabilities\n\tPointer {}\n\tKeyboard {}\n\tTouch {}\n", .{
                c.capabilities.pointer,
                c.capabilities.keyboard,
                c.capabilities.touch,
            });

            if (c.capabilities.pointer) {
                self.input.pointer = seat.getPointer() catch |err| {
                    std.debug.panic("failed to get pointer {s}", .{
                        @errorName(err),
                    });
                };
                self.input.pointer.setListener(*Self, pointerListener, self);
            }

            if (c.capabilities.keyboard) {
                self.input.keyboard = seat.getKeyboard() catch |err| {
                    std.debug.panic("failed to get keyboard {s}", .{
                        @errorName(err),
                    });
                };
                self.input.keyboard.setListener(*Self, keyboardListener, self);
            }

            self.state = .capabilities_found;
        },
        .name => |_| {},
    }
}

fn xdgWmBaseListener(wm_base: *xdg.WmBase, event: xdg.WmBase.Event, _: *Self) void {
    switch (event) {
        .ping => |s| {
            Log.debug("wm ping {} => pong", .{
                s.serial,
            });
            wm_base.pong(s.serial);
        },
    }
}

fn pointerListener(ptr: *wl.Pointer, event: wl.Pointer.Event, self: *Self) void {
    _ = ptr;
    switch (event) {
        .axis => {},
        .axis_discrete => {},
        .axis_relative_direction => {},
        .axis_source => {},
        .axis_stop => {},
        .axis_value120 => {},
        .button => |b| {
            const e = Input.Event.Union{
                .mouse_button = .{
                    .button = translateMouseButton(b.button) orelse .none,
                    .modifiers = self.input.modifiers,
                    .state = if (b.state == .pressed) .pressed else .released,
                },
            };
            self.input.queue.writeItem(Input.Event.init(e)) catch |err| {
                Log.err("failed to write input event {s}", .{
                    @errorName(err),
                });
            };
        },
        .enter => {},
        .frame => {},
        .leave => {},
        .motion => |m| {
            const e = Input.Event.Union{
                .mouse_move = .{
                    .modifiers = self.input.modifiers,
                    .position = .{
                        @bitCast(@as(i32, m.surface_x.toInt())),
                        @bitCast(@as(i32, m.surface_y.toInt())),
                    },
                },
            };
            self.input.queue.writeItem(Input.Event.init(e)) catch |err| {
                Log.err("failed to write input event {s}", .{
                    @errorName(err),
                });
            };
        },
    }
}

fn keyboardListener(kbd: *wl.Keyboard, event: wl.Keyboard.Event, self: *Self) void {
    _ = kbd;
    switch (event) {
        .enter => {},
        .key => |k| {
            const e = Input.Event.Union{
                .key = .{
                    .key = translateKeyCode(k.key) orelse .none,
                    .modifiers = self.input.modifiers,
                    .state = if (k.state == .pressed) .pressed else .released,
                },
            };
            self.input.queue.writeItem(Input.Event.init(e)) catch |err| {
                Log.err("failed to write input event {s}", .{
                    @errorName(err),
                });
            };
        },
        .keymap => |km| {
            switch (km.format) {
                .xkb_v1 => {
                    const map_shm = std.posix.mmap(null, km.size, std.posix.PROT.READ, .{ .TYPE = .PRIVATE }, km.fd, 0) catch |err| {
                        std.debug.panic("failed to map keymap {s}", .{
                            @errorName(err),
                        });
                    };
                    defer std.posix.munmap(map_shm);

                    self.input.keymap = self.input.ctx.newKeymap(@alignCast(map_shm)) catch |err| {
                        std.debug.panic("failed to create xkb keymap {s}", .{
                            @errorName(err),
                        });
                    };

                    const state = self.input.keymap.newState() catch |err| {
                        std.debug.panic("failed to create keymap state {s}", .{
                            @errorName(err),
                        });
                    };
                    defer state.unref();
                },
                .no_keymap => {},
                else => {},
            }
        },
        .leave => {},
        .modifiers => |m| {
            Log.debug("{}", .{m});
        },
        .repeat_info => {},
    }
}

pub fn dispatchInput(self: *Self, listeners: []Input.Listener) !void {
    while (self.input.queue.readItem()) |e| {
        var event = e;
        for (listeners) |l| {
            const result = try l.onInput(event);
            event.handled = result;
        }
    }
}

fn translateMouseButton(code: u32) ?Input.MouseButton {
    return switch (code) {
        272 => .left,
        273 => .right,
        274 => .middle,
        275 => .four,
        276 => .five,
        else => null,
    };
}

fn translateKeyCode(code: u32) ?Input.Key {
    return switch (code) {
        41 => .@"`",
        2 => .@"1",
        3 => .@"2",
        4 => .@"3",
        5 => .@"4",
        6 => .@"5",
        7 => .@"6",
        8 => .@"7",
        9 => .@"8",
        10 => .@"9",
        11 => .@"0",
        12 => .@"-",
        13 => .@"=",
        14 => .backspace,

        15 => .tab,
        16 => .q,
        17 => .w,
        18 => .e,
        19 => .r,
        20 => .t,
        21 => .y,
        22 => .u,
        23 => .i,
        24 => .o,
        25 => .p,
        26 => .@"[",
        27 => .@"]",
        43 => .@"\\",

        58 => .capsLock,
        30 => .a,
        31 => .s,
        32 => .d,
        33 => .f,
        34 => .g,
        35 => .h,
        36 => .j,
        37 => .k,
        38 => .l,
        39 => .@";",
        40 => .@"'",
        28 => .@"return",

        42 => .leftShift,
        44 => .z,
        45 => .x,
        46 => .c,
        47 => .v,
        48 => .b,
        49 => .n,
        50 => .m,
        51 => .@",",
        52 => .@".",
        53 => .@"/",
        54 => .rightShift,

        29 => .leftControl,
        125 => .leftSuper,
        56 => .leftAlt,
        57 => .space,
        100 => .rightAlt,
        126 => .rightSuper,
        97 => .rightControl,

        1 => .escape,
        59 => .f1,
        60 => .f2,
        61 => .f3,
        62 => .f4,
        63 => .f5,
        64 => .f6,
        65 => .f7,
        66 => .f8,
        67 => .f9,
        68 => .f10,
        87 => .f11,
        88 => .f12,

        110 => .insert,
        102 => .home,
        104 => .pageUp,
        111 => .delete,
        107 => .end,
        109 => .pageDown,

        105 => .left,
        103 => .up,
        106 => .right,
        108 => .down,

        else => null,
    };
}
