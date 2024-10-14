//! Cake.Video - the video subsystem

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
