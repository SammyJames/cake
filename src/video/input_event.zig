//! Cake.Video

const std = @import("std");

const Self = @This();

pub const Modifiers = packed struct(u32) {
    ctrl: bool = false,
    alt: bool = false,
    shift: bool = false,
    _padding: u29 = 0,
};

pub const Event = union(enum) {
    invalid: u32,
    key: struct {
        key: Key = .none,
        modifiers: Modifiers = .{},
        state: enum { pressed, released } = .released,
    },
    mouse_move: struct {
        modifiers: Modifiers = .{},
        position: @Vector(2, u32) = .{ 0, 0 },
    },
    mouse_button: struct {
        button: MouseButton = .none,
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

pub const Key = enum {
    none,

    escape,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,

    @"`",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"0",
    @"-",
    @"=",
    backspace,

    tab,
    q,
    w,
    e,
    r,
    t,
    y,
    u,
    i,
    o,
    p,
    @"[",
    @"]",
    @"\\",

    caps_lock,
    a,
    s,
    d,
    f,
    g,
    h,
    j,
    k,
    l,
    @";",
    @"'",
    @"return",

    left_shift,
    z,
    x,
    c,
    v,
    b,
    n,
    m,
    @",",
    @".",
    @"/",
    right_shift,

    left_control,
    left_super,
    left_alt,
    space,
    right_alt,
    right_super,
    right_function,
    right_control,

    insert,
    home,
    page_up,
    delete,
    end,
    page_down,

    left,
    right,
    up,
    down,
};

pub const MouseButton = enum {
    none,
    left,
    right,
    middle,
    four,
    five,
};
