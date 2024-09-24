//! Cake.Render

///////////////////////////////////////////////////////////////////////////////
/// used to abstract away the underlying video surface implementation within
/// the renderer
pub const Surface = struct {
    ptr: *anyopaque,
    vtable: struct {
        get_os_surface: *const fn (ctx: *anyopaque) *anyopaque,
        get_size: *const fn (ctx: *anyopaque) @Vector(2, u32),
    },

    ///////////////////////////////////////////////////////////////////////////
    /// get the operating system surface
    /// @return an opaque pointer to the surface
    pub fn getOsSurface(self: @This()) *anyopaque {
        return @call(
            .auto,
            self.vtable.get_os_surface,
            .{self.ptr},
        );
    }

    ///////////////////////////////////////////////////////////////////////////
    /// get the size of the operating system surface
    /// @return a vec2
    pub fn getSize(self: @This()) @Vector(2, u32) {
        return @call(
            .auto,
            self.vtable.get_size,
            .{self.ptr},
        );
    }
};

///////////////////////////////////////////////////////////////////////////////
/// used to abstract away the underlying video implementation within the
/// renderer
pub const Video = struct {
    ptr: *anyopaque,
    vtable: struct {
        get_os_display: *const fn (ctx: *anyopaque) *anyopaque,
    },

    ///////////////////////////////////////////////////////////////////////////
    /// get the os display
    /// @return an opaque pointer to the display
    pub fn getOsDisplay(self: @This()) *anyopaque {
        return @call(
            .auto,
            self.vtable.get_os_display,
            .{self.ptr},
        );
    }
};
