//! Cake.Video

pub const Swapchain = struct {
    ptr: *anyopaque,
    vtable: struct {
        on_resize: *const fn (*anyopaque, @Vector(2, u32)) anyerror!void,
    },

    pub fn onResize(self: @This(), size: @Vector(2, u32)) !void {
        try @call(
            .auto,
            self.vtable.on_resize,
            .{ self.ptr, size },
        );
    }
};
