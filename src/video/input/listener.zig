//! Cake.Video - the video subsystem

const Event = @import("event.zig");

/// signature for input event handlers
/// implementors should return true if they have "handled" the event
const TOnInput = *const fn (?*anyopaque, Event) anyerror!bool;

/// an object that listens for input
ptr: ?*anyopaque,
vtable: struct {
    on_input: TOnInput,
},

pub fn init(ptr: ?*anyopaque, callback: TOnInput) @This() {
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
