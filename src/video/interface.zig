//! Cake.Video - the video subsystem

const InputEvent = @import("input_event.zig");

///
pub const Swapchain = struct {
    ptr: *allowzero anyopaque,
    vtable: struct {
        on_resize: *allowzero const fn (*anyopaque, @Vector(2, u32)) anyerror!void,
    },

    pub fn onResize(self: @This(), size: @Vector(2, u32)) !void {
        try @call(
            .auto,
            self.vtable.on_resize,
            .{ self.ptr, size },
        );
    }
};

///
pub const InputListener = struct {
    ptr: *allowzero anyopaque,
    vtable: struct {
        on_input: *allowzero const fn (*allowzero anyopaque, InputEvent) anyerror!bool,
    },

    pub fn onInput(self: @This(), event: InputEvent) !bool {
        return try @call(.auto, self.vtable.on_input, .{
            self.ptr,
            event,
        });
    }
};
