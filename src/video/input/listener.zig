//! Cake.Video - the video subsystem

const Event = @import("event.zig");

const OnInputFunction = *const fn (?*anyopaque, Event) anyerror!bool;

/// an object that listens for input
ptr: ?*anyopaque,
vtable: struct {
    on_input: OnInputFunction,
},

pub fn init(ptr: ?*anyopaque, callback: OnInputFunction) @This() {
    return .{
        .ptr = ptr,
        .vtable = .{
            .on_input = callback,
        },
    };
}

pub fn onInput(self: @This(), event: Event) !bool {
    return try @call(.auto, self.vtable.on_input, .{
        self.ptr,
        event,
    });
}
