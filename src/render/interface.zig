//! Cake.Render - the render subsystem

/// Used to abstract away the underlying video surface implementation within the renderer
pub const Surface = struct {
    const Self = @This();

    ptr: *allowzero anyopaque,
    vtable: struct {
        get_os_surface: *allowzero const fn (ctx: *anyopaque) anyerror!*anyopaque,
        get_size: *allowzero const fn (ctx: *anyopaque) @Vector(2, u32),
    },

    /// Get the operating system surface
    /// @return an opaque pointer to the surface
    pub fn getOsSurface(self: Self) !*anyopaque {
        return try @call(
            .auto,
            self.vtable.get_os_surface,
            .{self.ptr},
        );
    }

    /// Get the size of the operating system surface
    /// @return a vec2
    pub fn getSize(self: Self) @Vector(2, u32) {
        return @call(
            .auto,
            self.vtable.get_size,
            .{self.ptr},
        );
    }
};

/// Used to abstract away the underlying video implementation within the renderer
pub const Video = struct {
    const Self = @This();

    ptr: *allowzero anyopaque,
    vtable: struct {
        get_os_display: *allowzero const fn (ctx: *anyopaque) anyerror!*anyopaque,
    },

    /// Get the os display
    /// @return an opaque pointer to the display
    pub fn getOsDisplay(self: Self) !*anyopaque {
        return try @call(
            .auto,
            self.vtable.get_os_display,
            .{self.ptr},
        );
    }
};
