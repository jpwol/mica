const std = @import("std");
const w = @import("../../../WIN32.zig");
// const win32 = @import("c");
const TS = std.Io.Timestamp;
const Window = @import("window.zig").Window;
const e = @import("../../events.zig");

const Event = e.Event;
const MouseButton = e.MouseButton;
const Key = e.Key;
const Modifiers = e.Modifiers;

pub fn pollEvents(io: std.Io, allocator: std.mem.Allocator, win: *Window) ![]const Event {
    _ = io;
    @memset(&win.key_pressed_this_frame, false);
    @memset(&win.key_released_this_frame, false);
    win.events.clearRetainingCapacity();

    var msg: w.MSG = undefined;
    while (w.PeekMessageW(
            &msg, 
            null, 
            0, 0, 
            w.PM_REMOVE,
        ) != 0) {

        if (msg.message == w.WM_QUIT) {
            win.should_close = true;
            try win.events.append(allocator, .close_requested);
            break;
        }

        _ = w.TranslateMessage(&msg);
        _ = w.DispatchMessageW(&msg);
    }

    return win.events.items;
}

pub fn windowProc(
    hwnd: w.HWND,
    msg: u32,
    wparam: w.WPARAM,
    lparam: w.LPARAM
    ) callconv(.winapi) w.LRESULT {
    if (msg == w.WM_NCCREATE) {
        const create_struct: *w.CREATESTRUCTW = @ptrFromInt(@as(usize, @intCast(lparam)));
        const win_ptr: *Window = @ptrCast(@alignCast(create_struct.lpCreateParams));
        _ = w.SetWindowLongPtrW(hwnd, .P_USERDATA, @intCast(@intFromPtr(win_ptr)));
        return w.DefWindowProcW(hwnd, msg, wparam, lparam);
    }

    const user_data = w.GetWindowLongPtrW(hwnd, .P_USERDATA);
    if (user_data == 0) {
        return w.DefWindowProcW(hwnd, msg, wparam, lparam);
    }
    const win: *Window = @ptrFromInt(@as(usize, @intCast(user_data)));

    switch (msg) {
        w.WM_KEYDOWN, w.WM_SYSKEYDOWN => {
            const key = vkToKey(wparam, lparam);
            const idx = @intFromEnum(key);
            const is_repeat = win.key_held[idx];
            win.key_held[idx] = true;
            if (!is_repeat) {
                win.key_pressed_this_frame[idx] = true;
                win.key_down_time[idx] = TS.now(win.io, .awake).toMilliseconds();
            }
            win.events.append(win.allocator, .{ 
                .key_down = .{ 
                    .key = key,
                    .mods = currentModifiers(),
                    .repeat = is_repeat ,
                }
            }) catch {};
            return 0;
        },
        w.WM_KEYUP, w.WM_SYSKEYUP => {
            const key = vkToKey(wparam, lparam);
            const idx = @intFromEnum(key);
            win.key_held[idx] = false;
            win.key_released_this_frame[idx] = true;
            win.key_down_time[idx] = null;
            win.events.append(win.allocator, .{ 
                .key_up = .{ 
                    .key = key, 
                    .mods = currentModifiers() 
                } 
            }) catch {};
            return 0;
        },
        w.WM_MOUSEMOVE => {
            const x = w.getXLparam(lparam);
            const y = w.getYLparam(lparam);
            win.events.append(win.allocator, .{
                .mouse_motion = .{
                    .x = x, 
                    .y = y,
                }
            }) catch {};
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            win.events.append(win.allocator, .{ 
                .mouse_button_down = .{ 
                    .button = .left,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                } 
            }) catch {};
            return 0;
        },
        w.WM_LBUTTONUP => {
            win.events.append(win.allocator, .{
                .mouse_button_up = .{
                    .button = .left,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                }
            }) catch {};
            return 0;
        },
        w.WM_RBUTTONDOWN => {
            win.events.append(win.allocator, .{ 
                .mouse_button_down = .{ 
                    .button = .right,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                } 
            }) catch {};
            return 0;
        },
        w.WM_RBUTTONUP => {
            win.events.append(win.allocator, .{
                .mouse_button_up = .{
                    .button = .right,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                }
            }) catch {};
            return 0;
        },
        w.WM_MBUTTONDOWN => {
            win.events.append(win.allocator, .{ 
                .mouse_button_down = .{ 
                    .button = .middle,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                }
            }) catch {};
            return 0;
        },
        w.WM_MBUTTONUP => {
            win.events.append(win.allocator, .{
                .mouse_button_up = .{
                    .button = .middle,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                }
            }) catch {};
            return 0;
        },
        w.WM_MOUSEWHEEL => {
            const delta = w.getWheelDelta(wparam);
            const button: MouseButton = if (delta > 0) .scroll_up else .scroll_down; 
            win.events.append(win.allocator, .{
                .mouse_button_down = .{
                    .button = button,
                    .x = w.getXLparam(lparam),
                    .y = w.getYLparam(lparam),
                    .mods = currentModifiers(),
                }
            }) catch {};
            return 0;
        },
        w.WM_SIZE => {
            win.width = @intCast(lparam & 0xFFFF);
            win.height = @intCast((lparam >> 16) & 0xFFFF);
            win.events.append(win.allocator, .{ .resize = .{ .width = win.width, .height = win.height } }) catch {};
            return 0;
        },
        w.WM_CLOSE => {
            win.should_close = true;
            win.events.append(win.allocator, .close_requested) catch {};
            return 0;
        },
        w.WM_DESTROY => {
            w.PostQuitMessage(0);
            return 0;
        },
        else => {
            return w.DefWindowProcW(hwnd, msg, wparam, lparam);
        },
    }
}

pub fn isKeyDown(win: *Window, key: Key) bool {
    return win.key_held[@intFromEnum(key)];
}

pub fn wasKeyPressed(win: *Window, key: Key) bool {
    return win.key_pressed_this_frame[@intFromEnum(key)];
}

pub fn keyHeldDuration(io: std.Io, win: *Window, key: Key) ?i64 {
    const idx = @intFromEnum(key);
    const down_time = win.key_down_time[idx] orelse return null;
    return TS.now(io, .awake).toMilliseconds() - down_time;
}

fn vkToKey(wparam: w.WPARAM, lparam: w.LPARAM) Key {
    const vk: u32 = @intCast(wparam);
    const extended = (lparam & (1 << 24)) != 0;
    return switch (vk) {
        'A'...'Z' => @enumFromInt(@intFromEnum(Key.a) + (vk - 'A')), // relies on Key.a..z being contiguous in that order
        '0'...'9' => @enumFromInt(@intFromEnum(Key.num_0) + (vk - '0')),

        w.VK_F1 => .f1, w.VK_F2 => .f2, w.VK_F3 => .f3, w.VK_F4 => .f4,
        w.VK_F5 => .f5, w.VK_F6 => .f6, w.VK_F7 => .f7, w.VK_F8 => .f8,
        w.VK_F9 => .f9, w.VK_F10 => .f10, w.VK_F11 => .f11, w.VK_F12 => .f12,

        w.VK_SPACE => .space,
        w.VK_RETURN => .enter,
        w.VK_TAB => .tab,
        w.VK_BACK => .backspace,
        w.VK_ESCAPE => .escape,
        w.VK_DELETE => .delete,
        w.VK_INSERT => .insert,

        w.VK_UP => .up, w.VK_DOWN => .down,
        w.VK_LEFT => .left, w.VK_RIGHT => .right,
        w.VK_HOME => .home, w.VK_END => .end,
        w.VK_PRIOR => .page_up, w.VK_NEXT => .page_down,

        w.VK_LSHIFT => .left_shift, w.VK_RSHIFT => .right_shift,
        w.VK_LCONTROL => .left_ctrl, w.VK_RCONTROL => .right_ctrl,
        w.VK_LMENU => .left_alt, w.VK_RMENU => .right_alt,
        w.VK_LWIN => .left_super, w.VK_RWIN => .right_super,
        w.VK_CAPITAL => .caps_lock,

        w.VK_OEM_MINUS => .minus, w.VK_OEM_PLUS => .equal,
        w.VK_OEM_4 => .left_bracket, w.VK_OEM_6 => .right_bracket,
        w.VK_OEM_5 => .backslash, w.VK_OEM_1 => .semicolon,
        w.VK_OEM_7 => .apostrophe, w.VK_OEM_3 => .grave,
        w.VK_OEM_COMMA => .comma, w.VK_OEM_PERIOD => .period, w.VK_OEM_2 => .slash,

        w.VK_NUMPAD0 => .kp_0, w.VK_NUMPAD1 => .kp_1, w.VK_NUMPAD2 => .kp_2,
        w.VK_NUMPAD3 => .kp_3, w.VK_NUMPAD4 => .kp_4, w.VK_NUMPAD5 => .kp_5,
        w.VK_NUMPAD6 => .kp_6, w.VK_NUMPAD7 => .kp_7, w.VK_NUMPAD8 => .kp_8,
        w.VK_NUMPAD9 => .kp_9,
        w.VK_ADD => .kp_add, w.VK_SUBTRACT => .kp_subtract,
        w.VK_MULTIPLY => .kp_multiply, w.VK_DIVIDE => .kp_divide,
        w.VK_DECIMAL => .kp_decimal,
        // note: there's no separate VK_NUMPAD_ENTER — Windows reports numpad
        // Enter as plain VK_RETURN with an extended-key bit set in lParam;
        // handling that distinction needs lParam bit 24, not just wParam

        w.VK_SNAPSHOT => .print_screen,
        w.VK_SCROLL => .scroll_lock,
        w.VK_PAUSE => .pause,
        w.VK_SHIFT => blk: {
            const scancode: u32 = @intCast((lparam >> 16) & 0xFF);
            const mapped = w.MapVirtualKeyW(scancode, w.MAPVK_VSC_TO_VK_EX);
            break :blk if (mapped == w.VK_RSHIFT) .right_shift else .left_shift;
        },
        w.VK_CONTROL => if (extended) .right_ctrl else .left_ctrl,
        w.VK_MENU => if (extended) .right_alt else .left_alt,

        else => .unknown,
    };
}

fn currentModifiers() Modifiers {
    return .{
        .shift = (@as(i32, @intCast(w.GetKeyState(@intCast(w.VK_SHIFT)))) & 0x8000) != 0,
        .ctrl = (@as(i32, @intCast(w.GetKeyState(@intCast(w.VK_CONTROL)))) & 0x8000) != 0,
        .alt = (@as(i32, @intCast(w.GetKeyState(@intCast(w.VK_MENU)))) & 0x8000) != 0,
        .super = (@as(i32, @intCast(w.GetKeyState(@intCast(w.VK_LWIN)))) & 0x8000) != 0 or (@as(i32, @intCast(w.GetKeyState(@intCast(w.VK_RWIN)))) & 0x8000) != 0,
        .caps_lock = (@as(i32, @intCast(w.GetKeyState(@intCast(w.VK_CAPITAL)))) & 0x1) != 0, // toggle state, different bit than held-state
    };
}
