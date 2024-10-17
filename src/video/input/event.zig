//! Cake.Video - the video subsystem

const constants = @import("constants.zig");

const Self = @This();

pub const Modifiers = packed struct(u8) {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
    _padding: u5 = 0,
};

pub const Union = union(enum) {
    invalid: u32,
    key: struct {
        key: constants.Key = .none,
        modifiers: Modifiers = .{},
        state: enum { pressed, released } = .released,
    },
    mouse_move: struct {
        modifiers: Modifiers = .{},
        position: @Vector(2, u32) = .{ 0, 0 },
    },
    mouse_button: struct {
        button: constants.MouseButton = .none,
        modifiers: Modifiers = .{},
        state: enum { pressed, released } = .released,
    },
};

event: Union = .{ .invalid = 0 },
handled: bool = false,

pub fn init(e: Union) Self {
    return .{
        .event = e,
        .handled = false,
    };
}
