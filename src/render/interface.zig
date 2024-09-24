//! Cake.Render

pub const Surface = struct {
    ptr: *anyopaque,
    vtable: struct {
        get_os_surface: *const fn (ctx: *anyopaque) *anyopaque,
        get_size: *const fn (ctx: *anyopaque) @Vector(2, u32),
    },

    pub fn getOsSurface(self: @This()) *anyopaque {
        return @call(.auto, self.vtable.get_os_surface, .{self.ptr});
    }

    pub fn getSize(self: @This()) @Vector(2, u32) {
        return @call(.auto, self.vtable.get_size, .{self.ptr});
    }
};

pub const Video = struct {
    ptr: *anyopaque,
    vtable: struct {
        get_os_display: *const fn (ctx: *anyopaque) *anyopaque,
    },

    pub fn getOsDisplay(self: @This()) *anyopaque {
        return @call(.auto, self.vtable.get_os_display, .{self.ptr});
    }
};
