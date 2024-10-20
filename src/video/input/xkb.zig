//! Cake.Video - the video subsystem

const std = @import("std");

const Self = @This();
const Log = std.log.scoped(.@"cake.video.xkb");

const c = @cImport({
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("xkbcommon/xkbcommon-compose.h");
    @cInclude("linux/input-event-codes.h");
});

handle: std.DynLib,

xkb_context_new: *const @TypeOf(c.xkb_context_new),
xkb_context_ref: *const @TypeOf(c.xkb_context_ref),
xkb_context_unref: *const @TypeOf(c.xkb_context_unref),
xkb_keymap_new_from_string: *const @TypeOf(c.xkb_keymap_new_from_string),
xkb_state_new: *const @TypeOf(c.xkb_state_new),
xkb_keymap_ref: *const @TypeOf(c.xkb_keymap_ref),
xkb_keymap_unref: *const @TypeOf(c.xkb_keymap_unref),
xkb_state_ref: *const @TypeOf(c.xkb_state_ref),
xkb_state_unref: *const @TypeOf(c.xkb_state_unref),
xkb_compose_table_new_from_locale: *const @TypeOf(c.xkb_compose_table_new_from_locale),
xkb_compose_state_new: *const @TypeOf(c.xkb_compose_state_new),
xkb_compose_table_unref: *const @TypeOf(c.xkb_compose_table_unref),
xkb_keymap_mod_get_index: *const @TypeOf(c.xkb_keymap_mod_get_index),
xkb_state_update_mask: *const @TypeOf(c.xkb_state_update_mask),
xkb_state_mod_index_is_active: *const @TypeOf(c.xkb_state_mod_index_is_active),
xkb_state_key_get_syms: *const @TypeOf(c.xkb_state_key_get_syms),
xkb_compose_state_feed: *const @TypeOf(c.xkb_compose_state_feed),
xkb_compose_state_get_status: *const @TypeOf(c.xkb_compose_state_get_status),
xkb_compose_state_get_one_sym: *const @TypeOf(c.xkb_compose_state_get_one_sym),
xkb_keysym_to_utf32: *const @TypeOf(c.xkb_keysym_to_utf32),

pub const Modifiers = enum {
    none,
    control,
    alt,
    shift,
    super,
    caps_lock,
    num_lock,

    const STRING_TO_ENUM = std.StaticStringMap(Self).initComptime(.{
        .{ "Control", .control },
        .{ "Mod1", .alt },
        .{ "Shift", .shift },
        .{ "Mod4", .super },
        .{ "Lock", .caps_lock },
        .{ "Mod2", .num_lock },
    });

    pub fn toString(self: @This()) [*c]const u8 {
        return switch (self) {
            .none => "",
            .control => "Control",
            .alt => "Mod1",
            .shift => "Shift",
            .super => "Mod4",
            .caps_lock => "Lock",
            .num_lock => "Mod2",
        };
    }

    pub fn fromString(str: [*c]const u8) Self {
        return STRING_TO_ENUM.get(str) orelse .none;
    }
};

pub fn load() !Self {
    var result: Self = undefined;

    result.handle = try std.DynLib.open("libxkbcommon.so");

    inline for (@typeInfo(Self).@"struct".fields[1..]) |f| {
        const n = std.fmt.comptimePrint("{s}\x00", .{f.name});
        const name: [:0]const u8 = @ptrCast(n[0 .. n.len - 1]);
        @field(result, f.name) = result.handle.lookup(f.type, name) orelse {
            Log.err("Symbol lookup failed for {s}", .{name});
            return error.SymbolLookup;
        };
    }

    return result;
}

/// create a new xkb context
pub fn newContext(self: *Self) error{XkbContextNewFailed}!Context {
    const ctx: ?*c.xkb_context = @call(.auto, self.xkb_context_new, .{
        c.XKB_CONTEXT_NO_FLAGS,
    });

    if (ctx == null) {
        return error.XkbContextNewFailed;
    }

    var result: Context = .{ .xkb = self, .inner = ctx };
    result.ref();
    return result;
}

///
pub const Context = struct {
    xkb: *const Self,
    inner: ?*c.xkb_context,

    pub fn ref(self: *@This()) void {
        if (self.inner != null) {
            _ = @call(.auto, self.xkb.xkb_context_ref, .{
                self.inner,
            });
        }
    }

    pub fn unref(self: *@This()) void {
        if (self.inner != null) {
            @call(.auto, self.xkb.xkb_context_unref, .{
                self.inner,
            });
        }
    }

    pub fn newComposeTable(self: *@This(), locale: [*c]const u8) error{ XkbComposeTableNewFromLocaleFailed, XkbComposeStateNewFailed }!ComposeTable {
        const table: ?*c.xkb_compose_table = @call(.auto, self.xkb.xkb_compose_table_new_from_locale, .{
            self.inner,
            locale,
            c.XKB_COMPOSE_COMPILE_NO_FLAGS,
        });

        if (table == null) {
            return error.XkbComposeTableNewFromLocaleFailed;
        }

        const state: ?*c.xkb_compose_state = @call(.auto, self.xkb.xkb_compose_state_new, .{
            table,
            c.XKB_COMPOSE_STATE_NO_FLAGS,
        });

        if (state == null) {
            return error.XkbComposeStateNewFailed;
        }

        return .{
            .xkb = self.xkb,
            .inner = table,
            .state = state,
        };
    }

    pub fn newKeymap(self: *@This(), string: [*c]const u8) error{XkbKeymapNewFromStringFailed}!Keymap {
        Log.info("creating a new keymap {?p}", .{
            self.inner,
        });
        const keymap: ?*c.xkb_keymap = @call(.auto, self.xkb.xkb_keymap_new_from_string, .{
            self.inner,
            string,
            c.XKB_KEYMAP_FORMAT_TEXT_V1,
            c.XKB_KEYMAP_COMPILE_NO_FLAGS,
        });

        if (keymap == null) {
            return error.XkbKeymapNewFromStringFailed;
        }

        Log.debug(
            "new keymap {?p}",
            .{keymap},
        );

        return .{ .xkb = self.xkb, .inner = keymap };
    }
};

///
pub const Keymap = struct {
    xkb: *const Self,
    inner: ?*c.xkb_keymap,

    pub fn ref(self: *@This()) void {
        if (self.inner != null) {
            @call(
                .auto,
                self.xkb.xkb_keymap_ref,
                .{self.inner},
            );
        }
    }

    pub fn unref(self: *@This()) void {
        if (self.inner != null) {
            @call(
                .auto,
                self.xkb.xkb_keymap_unref,
                .{self.inner},
            );
        }
    }

    pub fn newState(self: *@This()) error{XkbStateNewFailed}!State {
        const state: ?*c.xkb_state = @call(
            .auto,
            self.xkb.xkb_state_new,
            .{
                self.inner,
            },
        );

        if (state == null) {
            return error.XkbStateNewFailed;
        }

        return .{ .xkb = self.xkb, .inner = state };
    }

    pub fn getModifierKey(self: *@This(), mod: Modifiers) u32 {
        return @call(.auto, self.xkb.xkb_keymap_mod_get_index, .{
            self.inner,
            mod.toString(),
        });
    }
};

pub const ComposeTable = struct {
    xkb: *const Self,
    inner: ?*c.xkb_compose_table,
    state: ?*c.xkb_compose_state,

    pub fn ref(self: *@This()) void {
        _ = self; // autofix

    }

    pub fn unref(self: *@This()) void {
        _ = self; // autofix

    }
};

///
pub const State = struct {
    xkb: *const Self,
    inner: ?*c.xkb_state,

    pub fn ref(self: *@This()) void {
        if (self.inner != null) {
            @call(.auto, self.xkb.xkb_state_ref, .{
                self.inner,
            });
        }
    }

    pub fn unref(self: *@This()) void {
        if (self.inner != null) {
            @call(.auto, self.xkb.xkb_state_unref, .{
                self.inner,
            });
        }
    }

    pub fn updateMask(self: *@This(), mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) void {
        _ = @call(.auto, self.xkb.xkb_state_update_mask, .{
            self.inner,
            mods_depressed,
            mods_latched,
            mods_locked,
            0,
            0,
            group,
        });
    }

    pub fn isIndexActive(self: *@This(), index: u32) bool {
        return @call(.auto, self.xkb.xkb_state_mod_index_is_active, .{
            self.inner,
            index,
            c.XKB_STATE_MODS_EFFECTIVE,
        }) == 1;
    }
};
