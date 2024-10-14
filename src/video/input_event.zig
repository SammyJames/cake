//! Cake.Video

const Self = @This();

const Modifiers = packed struct(u32) {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
    _padding: u29 = 0,
};

pub const Event = union(enum) {
    invalid: u32,
    key: struct {
        key: u32 = 0,
        modifiers: Modifiers = .{},
        state: enum { pressed, released } = .released,
    },
    mouse_move: struct {
        position: @Vector(2, u32) = .{ 0, 0 },
    },
    mouse_button: struct {
        button: u32,
        modifiers: Modifiers = .{},
        state: enum { pressed, released } = .released,
    },
};

event: Event = .{ .invalid = 0 },
handled: bool = false,

pub fn init(e: Event) Self {
    return .{
        .event = e,
        .handled = false,
    };
}
