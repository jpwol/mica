const std = @import("std");
const xlib = @import("c");
const Win = @import("window.zig");
const TS = std.Io.Timestamp;

pub const Event = union(enum) {
    key_down:          struct { key: Key, mods: Modifiers, repeat: bool },
    key_up:            struct { key: Key, mods: Modifiers },
    mouse_button_down: struct { button: MouseButton, x: i32, y: i32, mods: Modifiers },
    mouse_button_up:   struct { button: MouseButton, x: i32, y: i32, mods: Modifiers },
    mouse_motion:      struct { x: i32, y: i32 },
    focus_gained,
    focus_lost,
    resize: struct { width: u32, height: u32 },
    close_requested,
};

pub const MouseButton = enum { left, right, middle, scroll_up, scroll_down, unknown };

pub const Key = enum {
    unknown,

    a, b, c, d, e, f, g, h, i, j, k, l, m,
    n, o, p, q, r, s, t, u, v, w, x, y, z,

    num_0, num_1, num_2, num_3, num_4, num_5, num_6, num_7, num_8, num_9, 

    f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12,

    space, enter, tab, backspace, escape, delete, insert,

    up, down, left, right, home, end, page_up, page_down,

    left_shift, right_shift,
    left_ctrl, right_ctrl,
    left_alt,  right_alt,
    left_super, right_super,
    caps_lock,

    minus, equal, left_bracket, right_bracket, backslash,
    semicolon, apostrophe, grave, comma, period, slash,

    kp_0, kp_1, kp_2, kp_3, kp_4, kp_5, kp_6, kp_7, kp_8, kp_9, 
    kp_add, kp_subtract, kp_multiply, kp_divide, kp_enter, kp_decimal,

    print_screen, scroll_lock, pause,
};

pub const Modifiers = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
};

pub fn pollEvents(io: std.Io, allocator: std.mem.Allocator, win: *Win.Window) ![]const Event {
    @memset(&win.key_pressed_this_frame, false);
    @memset(&win.key_released_this_frame, false);
    win.events.clearRetainingCapacity();

    var ev: xlib.XEvent = undefined;
    while (xlib.XPending(win.display) > 0) {
        _ = xlib.XNextEvent(win.display, &ev);
        switch (ev.type) {
            xlib.KeyPress => {
                const keysym = xlib.XLookupKeysym(&ev.xkey, 0);
                const key = keysymToKey(keysym);
                const mods = modifiersFromState(ev.xkey.state);
                const idx = @intFromEnum(key);
                const is_repeat = win.key_held[idx];

                win.key_held[idx] = true;
                if (!is_repeat) {
                    win.key_pressed_this_frame[idx] = true;
                    win.key_down_time[idx] = TS.now(io, .awake).toMilliseconds();
                }
                win.modifiers = mods;
                try win.events.append(allocator, .{ .key_down = .{ .key = key, .mods = mods, .repeat = is_repeat } });
                win.key_held[idx] = true;
            },
            xlib.KeyRelease => {
                const keysym = xlib.XLookupKeysym(&ev.xkey, 0);
                const key = keysymToKey(keysym);
                const mods = modifiersFromState(ev.xkey.state);
                const idx = @intFromEnum(key);

                win.key_held[@intFromEnum(key)] = false;
                win.key_released_this_frame[idx] = true;
                win.key_down_time[idx] = null;
                win.modifiers = mods;
                try win.events.append(allocator, .{ .key_up = .{ .key = key, .mods = mods } });
            },
            xlib.ButtonPress => {
                const button = mouseButtonFromXButton(ev.xbutton.button);
                try win.events.append(allocator, .{ .mouse_button_down = .{
                    .button = button, .x = ev.xbutton.x, .y = ev.xbutton.y,
                    .mods = modifiersFromState(ev.xbutton.state),
                } });
            },
            xlib.ButtonRelease => {
                const button = mouseButtonFromXButton(ev.xbutton.button);
                try win.events.append(allocator, .{ .mouse_button_up = .{ 
                    .button = button, .x = ev.xbutton.x, .y = ev.xbutton.y,
                .mods = modifiersFromState(ev.xbutton.state),
                } });
            },
            xlib.MotionNotify => {
                try win.events.append(allocator, .{ .mouse_motion = .{ .x = ev.xmotion.x, .y = ev.xmotion.y } });
            },
            xlib.FocusIn => try win.events.append(allocator, .focus_gained),
            xlib.FocusOut => try win.events.append(allocator, .focus_lost),
            xlib.ConfigureNotify => {
                try win.events.append(allocator, .{ .resize = .{
                    .width = @intCast(ev.xconfigure.width),
                    .height = @intCast(ev.xconfigure.height),
                } });
                win.width = @intCast(ev.xconfigure.width);
                win.height = @intCast(ev.xconfigure.height);
            },
            xlib.ClientMessage => {
                if (ev.xclient.data.l[0] == @as(c_long, @intCast(win.wm_delete_window))) {
                    win.should_close = true;
                    try win.events.append(allocator, .close_requested);
                }
            },
            else => {},
        }
    }
    return win.events.items;
}

pub fn isKeyDown(win: *Win.Window, key: Key) bool {
    return win.key_held[@intFromEnum(key)];
}

pub fn keysymToKey(keysym: xlib.KeySym) Key {
    return switch (keysym) {
        xlib.XK_a => .a, xlib.XK_b => .b, xlib.XK_c => .c, xlib.XK_d => .d,
        xlib.XK_e => .e, xlib.XK_f => .f, xlib.XK_g => .g, xlib.XK_h => .h,
        xlib.XK_i => .i, xlib.XK_j => .j, xlib.XK_k => .k, xlib.XK_l => .l,
        xlib.XK_m => .m, xlib.XK_n => .n, xlib.XK_o => .o, xlib.XK_p => .p,
        xlib.XK_q => .q, xlib.XK_r => .r, xlib.XK_s => .s, xlib.XK_t => .t,
        xlib.XK_u => .u, xlib.XK_v => .v, xlib.XK_w => .w, xlib.XK_x => .x,
        xlib.XK_y => .y, xlib.XK_z => .z,

        xlib.XK_0 => .num_0, xlib.XK_1 => .num_1, xlib.XK_2 => .num_2,
        xlib.XK_3 => .num_3, xlib.XK_4 => .num_4, xlib.XK_5 => .num_5,
        xlib.XK_6 => .num_6, xlib.XK_7 => .num_7, xlib.XK_8 => .num_8,
        xlib.XK_9 => .num_9,

        xlib.XK_F1 => .f1, xlib.XK_F2 => .f2, xlib.XK_F3 => .f3, xlib.XK_F4 => .f4,
        xlib.XK_F5 => .f5, xlib.XK_F6 => .f6, xlib.XK_F7 => .f7, xlib.XK_F8 => .f8,
        xlib.XK_F9 => .f9, xlib.XK_F10 => .f10, xlib.XK_F11 => .f11, xlib.XK_F12 => .f12,

        xlib.XK_space => .space,
        xlib.XK_Return => .enter,
        xlib.XK_Tab => .tab,
        xlib.XK_BackSpace => .backspace,
        xlib.XK_Escape => .escape,
        xlib.XK_Delete => .delete,
        xlib.XK_Insert => .insert,

        xlib.XK_Up => .up, xlib.XK_Down => .down,
        xlib.XK_Left => .left, xlib.XK_Right => .right,
        xlib.XK_Home => .home, xlib.XK_End => .end,
        xlib.XK_Page_Up => .page_up, xlib.XK_Page_Down => .page_down,

        xlib.XK_Shift_L => .left_shift, xlib.XK_Shift_R => .right_shift,
        xlib.XK_Control_L => .left_ctrl, xlib.XK_Control_R => .right_ctrl,
        xlib.XK_Alt_L => .left_alt, xlib.XK_Alt_R => .right_alt,
        xlib.XK_Super_L => .left_super, xlib.XK_Super_R => .right_super,
        xlib.XK_Caps_Lock => .caps_lock,

        xlib.XK_minus => .minus, xlib.XK_equal => .equal,
        xlib.XK_bracketleft => .left_bracket, xlib.XK_bracketright => .right_bracket,
        xlib.XK_backslash => .backslash, xlib.XK_semicolon => .semicolon,
        xlib.XK_apostrophe => .apostrophe, xlib.XK_grave => .grave,
        xlib.XK_comma => .comma, xlib.XK_period => .period, xlib.XK_slash => .slash,

        xlib.XK_KP_0 => .kp_0, xlib.XK_KP_1 => .kp_1, xlib.XK_KP_2 => .kp_2,
        xlib.XK_KP_3 => .kp_3, xlib.XK_KP_4 => .kp_4, xlib.XK_KP_5 => .kp_5,
        xlib.XK_KP_6 => .kp_6, xlib.XK_KP_7 => .kp_7, xlib.XK_KP_8 => .kp_8,
        xlib.XK_KP_9 => .kp_9,
        xlib.XK_KP_Add => .kp_add, xlib.XK_KP_Subtract => .kp_subtract,
        xlib.XK_KP_Multiply => .kp_multiply, xlib.XK_KP_Divide => .kp_divide,
        xlib.XK_KP_Enter => .kp_enter, xlib.XK_KP_Decimal => .kp_decimal,

        xlib.XK_Print => .print_screen,
        xlib.XK_Scroll_Lock => .scroll_lock,
        xlib.XK_Pause => .pause,

        else => .unknown,
    };
}

fn modifiersFromState(state: c_uint) Modifiers {
    return .{
        .shift = (state & xlib.ShiftMask) != 0,
        .ctrl = (state & xlib.ControlMask) != 0,
        .alt = (state & xlib.Mod1Mask) != 0,
        .super = (state & xlib.Mod4Mask) != 0,
        .caps_lock = (state & xlib.LockMask) != 0,
    };
}

fn mouseButtonFromXButton(button: c_uint) MouseButton {
    return switch (button) {
        1 => .left,
        2 => .middle,
        3 => .right,
        4 => .scroll_up,
        5 => .scroll_down,
        else => .unknown,
    };
}

pub fn keyHeldDuration(io: std.Io, win: *Win.Window, key: Key) ?i64 {
    const idx = @intFromEnum(key);
    const down_time = win.key_down_time[idx] orelse return null;
    return TS.now(io, .awake).toMilliseconds() - down_time;
}

pub fn wasKeyPressed(win: *Win.Window, key: Key) bool {
    return win.key_pressed_this_frame[@intFromEnum(key)];
}

pub fn getCursorPos(win: *Win.Window, x: *i64, y: *i64) void {
    var root_return: xlib.Window = undefined;
    var child_return: xlib.Window = undefined;
    var root_x_return: c_int = 0;
    var root_y_return: c_int = 0;
    var mask_return: c_uint = 0;
    _ = xlib.XQueryPointer(
        win.display, win.window , 
        &root_return, &child_return, 
        &root_x_return, &root_y_return,
        @ptrCast(x), @ptrCast(y), 
        &mask_return,
    );
}
