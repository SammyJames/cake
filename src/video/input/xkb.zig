//! Cake.Video

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

pub fn newContext(self: Self) error{XkbContextNewFailed}!Context {
    const ctx: ?*c.xkb_context = @call(.auto, self.xkb_context_new, .{
        c.XKB_CONTEXT_NO_FLAGS,
    });

    if (ctx == null) {
        return error.XkbContextNewFailed;
    }

    const result: Context = .{
        .xkb = &self,
        .inner = ctx,
    };
    result.ref();
    return result;
}

pub const Context = struct {
    xkb: *const Self,
    inner: ?*c.xkb_context,

    pub fn ref(self: @This()) void {
        if (self.inner != null) {
            _ = self.xkb.xkb_context_ref(self.inner);
        }
    }

    pub fn unref(self: @This()) void {
        if (self.inner != null) {
            self.xkb.xkb_context_unref(self.inner);
        }
    }

    pub fn newKeymap(self: @This(), string: [*c]const u8) error{XkbKeymapNewFromStringFailed}!Keymap {
        const keymap: ?*c.xkb_keymap = @call(.auto, self.xkb.xkb_keymap_new_from_string, .{
            self.inner,
            string,
            c.XKB_KEYMAP_FORMAT_TEXT_V1,
            c.XKB_KEYMAP_COMPILE_NO_FLAGS,
        });

        if (keymap == null) {
            return error.XkbKeymapNewFromStringFailed;
        }

        return .{
            .xkb = self.xkb,
            .inner = keymap,
        };
    }
};

pub const Keymap = struct {
    xkb: *const Self,
    inner: ?*c.xkb_keymap,

    pub fn ref(self: @This()) void {
        if (self.inner != null) {
            self.xkb.xkb_keymap_ref(self.inner);
        }
    }

    pub fn unref(self: @This()) void {
        if (self.inner != null) {
            self.xkb.xkb_keymap_unref(self.inner);
        }
    }

    pub fn newState(self: @This()) error{XkbStateNewFailed}!State {
        const state: ?*c.xkb_state = @call(.auto, self.xkb.xkb_state_new, .{
            self.inner,
        });

        if (state == null) {
            return error.XkbStateNewFailed;
        }

        return .{
            .xkb = self.xkb,
            .inner = state,
        };
    }
};

pub const State = struct {
    xkb: *const Self,
    inner: ?*c.xkb_state,

    pub fn ref(self: @This()) void {
        if (self.inner != null) {
            self.xkb.xkb_state_ref(self.inner);
        }
    }

    pub fn unref(self: @This()) void {
        if (self.inner != null) {
            self.xkb.xkb_state_unref(self.inner);
        }
    }
};
