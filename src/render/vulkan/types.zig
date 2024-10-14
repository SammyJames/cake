//! Cake.Render - the render subsystem

const vk = @import("vulkan");

pub const APIS: []const vk.ApiInfo = &.{
    vk.features.version_1_0,
    vk.extensions.khr_surface,
    vk.extensions.khr_swapchain,
    vk.extensions.khr_wayland_surface, // todo(sjames) - make platform agnostic
};

pub const Instance = vk.InstanceProxy(APIS);
pub const Device = vk.DeviceProxy(APIS);
