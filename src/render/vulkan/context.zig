//! Cake.Render - the render subsystem

const std = @import("std");
const vk = @import("vulkan");
const types = @import("types.zig");
const interface = @import("../interface.zig");

const Self = @This();
const Log = std.log.scoped(.@"cake.render.vulkan");

const REQUIRED_INSTANCE_EXTENSIONS = [_][*:0]const u8{
    vk.extensions.khr_surface.name,
    vk.extensions.khr_wayland_surface.name, // todo(sjames) - make platform agnostic
};
const REQUIRED_DEVICE_EXTENSIONS = [_][*:0]const u8{
    vk.extensions.khr_swapchain.name,
};

const DeviceCandidate = struct {
    pdev: vk.PhysicalDevice,
    props: vk.PhysicalDeviceProperties,
    queues: QueueAllocation,
};

const QueueAllocation = struct {
    graphics_family: u32,
    present_family: u32,
};

const BaseDispatch = vk.BaseWrapper(types.APIS);
const InstanceDispatch = vk.InstanceWrapper(types.APIS);
const DeviceDispatch = vk.DeviceWrapper(types.APIS);

var vulkan_lib: std.DynLib = undefined;
var load_vulkan = std.once(loadVulkan);

allocator: std.mem.Allocator,
app_id: [:0]const u8,
video: interface.Video,
base_dispatch: BaseDispatch,
instance: types.Instance,
device: types.Device,

pdev: vk.PhysicalDevice,
props: vk.PhysicalDeviceProperties,
mem_props: vk.PhysicalDeviceMemoryProperties,
queues: QueueAllocation,

/// Initialize the vulkan context
/// @param allocator the allocator interface to use
/// @param app_id the application identifier
/// @param udata usually the display
pub fn init(self: *Self, allocator: std.mem.Allocator, app_id: [:0]const u8, video: interface.Video) !void {
    self.allocator = allocator;
    self.app_id = app_id;
    self.video = video;

    const Loader = struct {
        fn load(_: vk.Instance, name: [*:0]const u8) vk.PfnVoidFunction {
            load_vulkan.call();
            return vulkan_lib.lookup(
                vk.PfnVoidFunction,
                std.mem.span(name),
            ) orelse null;
        }
    };

    self.base_dispatch = try BaseDispatch.load(Loader.load);

    const app_info: vk.ApplicationInfo = .{
        .p_application_name = app_id,
        .application_version = vk.makeApiVersion(0, 0, 1, 0),
        .p_engine_name = app_id,
        .engine_version = vk.makeApiVersion(0, 0, 1, 0),
        .api_version = vk.API_VERSION_1_2,
    };

    const instance = try self.base_dispatch.createInstance(
        &.{
            .p_application_info = &app_info,
            .enabled_extension_count = REQUIRED_INSTANCE_EXTENSIONS.len,
            .pp_enabled_extension_names = &REQUIRED_INSTANCE_EXTENSIONS,
        },
        null,
    );

    const vki = try allocator.create(InstanceDispatch);
    errdefer allocator.destroy(vki);
    vki.* = try InstanceDispatch.load(
        instance,
        self.base_dispatch.dispatch.vkGetInstanceProcAddr,
    );
    self.instance = types.Instance.init(instance, vki);
    errdefer self.instance.destroyInstance(null);

    const candidate = try self.pickPhysicalDevice(video);
    Log.debug(
        "device candidate {s}",
        .{candidate.props.device_name},
    );

    self.pdev = candidate.pdev;
    self.props = candidate.props;
    self.queues = candidate.queues;
    self.mem_props = self.instance.getPhysicalDeviceMemoryProperties(self.pdev);

    const dev = try self.initCandidate(candidate);

    const vkd = try allocator.create(DeviceDispatch);
    errdefer allocator.destroy(vkd);
    vkd.* = try DeviceDispatch.load(dev, self.instance.wrapper.dispatch.vkGetDeviceProcAddr);
    self.device = types.Device.init(dev, vkd);
    errdefer self.device.destroyDevice(null);
}

/// deinit
pub fn deinit(self: *Self) void {
    self.device.destroyDevice(null);
    self.instance.destroyInstance(null);

    self.allocator.destroy(self.device.wrapper);
    self.allocator.destroy(self.instance.wrapper);
}

/// Init the device candidate
/// @param candidate
/// @return a device
fn initCandidate(self: *Self, candidate: DeviceCandidate) !vk.Device {
    const priority = [_]f32{1};
    const qci = [_]vk.DeviceQueueCreateInfo{
        .{
            .queue_family_index = candidate.queues.graphics_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
        .{
            .queue_family_index = candidate.queues.present_family,
            .queue_count = 1,
            .p_queue_priorities = &priority,
        },
    };

    const queue_count: u32 = if (candidate.queues.graphics_family == candidate.queues.present_family)
        1
    else
        2;

    return try self.instance.createDevice(
        candidate.pdev,
        &.{
            .queue_create_info_count = queue_count,
            .p_queue_create_infos = &qci,
            .enabled_extension_count = REQUIRED_DEVICE_EXTENSIONS.len,
            .pp_enabled_extension_names = &REQUIRED_DEVICE_EXTENSIONS,
        },
        null,
    );
}

/// Loads the vulkan shared lib
fn loadVulkan() void {
    // todo(sjames) - make platform agnostic
    vulkan_lib = std.DynLib.open("libvulkan.so") catch |err| {
        std.debug.panic(
            "unable to load vulkan shared library: {s}",
            .{@errorName(err)},
        );
    };
}

/// Pick a physical device to use, assumes no surfaces exist yet
/// @param udata usually the display on wayland
/// @return a device candidate
fn pickPhysicalDevice(self: *Self, video: interface.Video) !DeviceCandidate {
    const pdevs = try self.instance.enumeratePhysicalDevicesAlloc(
        self.allocator,
    );
    defer self.allocator.free(pdevs);

    for (pdevs) |pdev| {
        // check required device extensions
        {
            const propsv = try self.instance.enumerateDeviceExtensionPropertiesAlloc(
                pdev,
                null,
                self.allocator,
            );
            defer self.allocator.free(propsv);

            for (REQUIRED_DEVICE_EXTENSIONS) |ext| {
                for (propsv) |props| {
                    if (std.mem.eql(u8, std.mem.span(ext), std.mem.sliceTo(&props.extension_name, 0))) {
                        break;
                    }
                } else {
                    return error.NoSuitablePhysicalDevice;
                }
            }
        }

        // check queue / presentation support
        {
            const queue_fams = try self.instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(
                pdev,
                self.allocator,
            );
            defer self.allocator.free(queue_fams);

            var graphics_family: ?u32 = null;
            var present_family: ?u32 = null;

            for (queue_fams, 0..) |properties, i| {
                const family: u32 = @intCast(i);

                if (graphics_family == null and properties.queue_flags.graphics_bit) {
                    graphics_family = family;
                }

                if (present_family == null and self.instance.getPhysicalDeviceWaylandPresentationSupportKHR(
                    pdev,
                    family,
                    @ptrCast(@alignCast(try video.getOsDisplay())),
                ) == vk.TRUE) {
                    present_family = family;
                }
            }

            if (graphics_family != null and present_family != null) {
                return .{
                    .pdev = pdev,
                    .props = self.instance.getPhysicalDeviceProperties(pdev),
                    .queues = .{
                        .graphics_family = graphics_family.?,
                        .present_family = present_family.?,
                    },
                };
            }
        }
    }

    return error.NoSuitablePhysicalDevice;
}

pub fn begin(self: *Self) !void {
    _ = self; // autofix
}

pub fn end(self: *Self) void {
    _ = self; // autofix
}
