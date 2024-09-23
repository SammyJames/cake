//! Cake

const cake_video = @import("cake.video");

const Self = @This();

surface: *cake_video.Surface,

pub fn init(size: @Vector(2, u32)) !Self {
    return .{
        .surface = try cake_video.createSurface(size),
    };
}

pub fn deinit(self: Self) void {
    cake_video.destroySurface(self.surface);
}

pub fn wantsClose(self: Self) bool {
    return self.surface.close_requested;
}
