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
