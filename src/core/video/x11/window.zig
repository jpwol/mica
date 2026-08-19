const std = @import("std");
const xlib = @import("c");
const TS = std.Io.Timestamp;
const e = @import("../../events.zig");
const Key = e.Key;
const Event = e.Event;
const Modifiers = e.Modifiers;

// TODO:
//      Implement custom cursors?
//      Add flags, implementation for the following:
//          - No decorations
//          - Min/Max size

pub const WindowFlags = packed struct {
    resizable: bool = false,
    fullscreen: bool = false,
};

pub const Window = struct {
    display: *xlib.Display,
    window: xlib.Window,
    screen: c_int,
    wm_delete_window: xlib.Atom,
    fullscreen: bool,
    should_close: bool,
    key_held: [std.meta.fields(Key).len]bool,
    key_pressed_this_frame: [std.meta.fields(Key).len]bool,
    key_released_this_frame: [std.meta.fields(Key).len]bool,
    key_down_time: [std.meta.fields(Key).len]?i64,
    modifiers: Modifiers,
    events: std.ArrayList(Event),
    cursor: ?xlib.Cursor,

    width: u24,
    height: u24,
};

pub fn createWindow(io: std.Io, allocator: std.mem.Allocator, title: []const u8, width: u24, height: u24, flags: WindowFlags) !*Window {
    var win: *Window = try allocator.create(Window);

    win.width = width;
    win.height = height;

    win.events = try .initCapacity(allocator, 0);
    win.key_held = [_]bool{false} ** std.meta.fields(Key).len;
    win.key_pressed_this_frame = [_]bool{false} ** std.meta.fields(Key).len;
    win.key_released_this_frame = [_]bool{false} ** std.meta.fields(Key).len;
    win.key_down_time = [_]?i64{null} ** std.meta.fields(Key).len;
    win.should_close = false;
    win.modifiers = .{};

    win.cursor = null;

    const display: *xlib.Display = xlib.XOpenDisplay(null).?;
    var supported: xlib.Bool = undefined;
    _ = xlib.XkbSetDetectableAutoRepeat(display, xlib.True, &supported);

    const screen = xlib.DefaultScreen(display);

    var attrs: xlib.XSetWindowAttributes = std.mem.zeroes(xlib.XSetWindowAttributes);
    attrs.background_pixel = xlib.BlackPixel(display, screen);
    attrs.event_mask =
        xlib.ExposureMask |
        xlib.StructureNotifyMask |
        xlib.KeyPressMask |
        xlib.KeyReleaseMask |
        xlib.ButtonPressMask |
        xlib.ButtonReleaseMask |
        xlib.PointerMotionMask |
        xlib.FocusChangeMask;

    const origin = getPrimaryMonitorOrigin(display, xlib.RootWindow(display, screen));
    const window: xlib.Window = xlib.XCreateWindow(
        display,
        xlib.RootWindow(display, screen),
        origin.x,
        origin.y,
        @intCast(width),
        @intCast(height),
        0,
        xlib.DefaultDepth(display, screen),
        xlib.CopyFromParent,
        xlib.DefaultVisual(display, screen),
        xlib.CWBackPixel | xlib.CWEventMask,
        &attrs,
    );

    _ = xlib.XStoreName(display, window, @ptrCast(title.ptr));
    const sizehints: *xlib.XSizeHints = xlib.XAllocSizeHints();
    sizehints.flags = 0;

    // FIXME: possibly allow user to define window location, or make it so the window is placed at screen
    //        center based on screen resolution?
    sizehints.flags |= xlib.USPosition;
    sizehints.x = origin.x;
    sizehints.y = origin.y;

    // FIXME: Add more checks throughout to enable/disable min and max size
    if (flags.resizable == false and flags.fullscreen == false) {
        sizehints.flags |= (xlib.PMinSize | xlib.PMaxSize);
        sizehints.min_width = @intCast(width);
        sizehints.max_width = @intCast(width);
        sizehints.min_height = @intCast(height);
        sizehints.max_height = @intCast(height);
    }

    const wmhints: *xlib.XWMHints = xlib.XAllocWMHints();
    wmhints.input = xlib.True;
    wmhints.flags = xlib.InputHint;

    const classhints: *xlib.XClassHint = xlib.XAllocClassHint();
    classhints.res_name = @constCast(title.ptr);
    classhints.res_class = @constCast(title.ptr);

    _ = xlib.XSetWMProperties(display, window, null, null, null, 0, sizehints, wmhints, classhints);
    _ = xlib.XFree(sizehints);
    _ = xlib.XFree(wmhints);
    _ = xlib.XFree(classhints);

    const wm_window_type = xlib.XInternAtom(display, "_NET_WM_WINDOW_TYPE", xlib.False);
    var normal_atom = xlib.XInternAtom(display, "_NET_WM_WINDOW_TYPE_NORMAL", xlib.False);
    _ = xlib.XChangeProperty(
        display,
        window,
        wm_window_type,
        xlib.XA_ATOM,
        32,
        xlib.PropModeReplace,
        @ptrCast(&normal_atom),
        1,
    );

    var wm_delete_window = xlib.XInternAtom(display, "WM_DELETE_WINDOW", xlib.False);
    _ = xlib.XSetWMProtocols(display, window, &wm_delete_window, 1);
    win.wm_delete_window = wm_delete_window;

    _ = xlib.XMapWindow(display, window);

    if (flags.fullscreen) {
        try applyFullscreen(io, display, window, screen); 
        win.fullscreen = true;
    }
    win.display = display;
    win.window = window;
    win.screen = screen;

    return win;
}

pub fn waitForWM(io: std.Io, display: *xlib.Display, root: xlib.Window, timeout_ms: u64) !bool {
    const wm_check_atom = xlib.XInternAtom(display, "_NET_SUPPORTING_WM_CHECK", xlib.False);

    var actual_type: xlib.Atom = undefined;
    var actual_format: c_int = undefined;
    var nitems: c_ulong = undefined;
    var bytes_after: c_ulong = undefined;
    var prop: [*c]u8 = null;

    const start = TS.now(io, .awake).toMilliseconds();
    while (TS.now(io, .awake).toMilliseconds() - start < timeout_ms) {
        const status = xlib.XGetWindowProperty(
            display,
            root,
            wm_check_atom,
            0,
            1,
            xlib.False,
            xlib.XA_WINDOW,
            &actual_type,
            &actual_format,
            &nitems,
            &bytes_after,
            &prop,
        );

        if (status == xlib.Success and prop != null and nitems > 0) {
            _ = xlib.XFree(prop);
            return true;
        }
        if (prop != null) _ = xlib.XFree(prop);

        try io.sleep(.fromMilliseconds(10), .awake);
    }
    return false;
}

// fn applyFullscreen(io: std.Io, display: *xlib.Display, window: xlib.Window, screen: c_int) !void {
//     const result = try waitForWM(io, display, xlib.RootWindow(display, screen), 2000);
//     std.debug.print("{}\n", .{result});
//
//     var xev: xlib.XClientMessageEvent = std.mem.zeroes(xlib.XClientMessageEvent);
//     xev.type = xlib.ClientMessage;
//     xev.window = window;
//     xev.message_type = xlib.XInternAtom(display, "_NET_WM_STATE", xlib.False);
//     xev.format = 32;
//     xev.data.l[0] = 1;
//     xev.data.l[1] = @intCast(xlib.XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", xlib.False));
//     xev.data.l[2] = 0;
//     xev.data.l[3] = 1;
//
//     _ = xlib.XSendEvent(
//         display,
//         xlib.RootWindow(display, screen),
//         xlib.False,
//         xlib.SubstructureRedirectMask | xlib.SubstructureNotifyMask,
//         @ptrCast(&xev),
//     );
// }

fn applyFullscreen(io: std.Io, display: *xlib.Display, window: xlib.Window, screen: c_int) !void {
    const wm_state = xlib.XInternAtom(display, "_NET_WM_STATE", xlib.False);
    const fullscreen_atom = xlib.XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", xlib.False);

    const sendRequest = struct {
        fn call(d: *xlib.Display, w: xlib.Window, s: c_int, state_atom: xlib.Atom, fs_atom: xlib.Atom) void {
            var xev: xlib.XClientMessageEvent = std.mem.zeroes(xlib.XClientMessageEvent);
            xev.type = xlib.ClientMessage;
            xev.window = w;
            xev.message_type = state_atom;
            xev.format = 32;
            xev.data.l[0] = 1; // _NET_WM_STATE_ADD
            xev.data.l[1] = @intCast(fs_atom);
            xev.data.l[3] = 1;
            _ = xlib.XSendEvent(d, xlib.RootWindow(d, s), xlib.False, xlib.SubstructureRedirectMask | xlib.SubstructureNotifyMask, @ptrCast(&xev));
        }
    }.call;

    const timeout_ms: i64 = 2000;
    const start = TS.now(io, .awake).toMilliseconds();

    while (TS.now(io, .awake).toMilliseconds() - start < timeout_ms) {
        sendRequest(display, window, screen, wm_state, fullscreen_atom);

        // give satellite/niri a moment to process, then check if it landed
        try io.sleep(.fromMilliseconds(50), .awake);

        var actual_type: xlib.Atom = undefined;
        var actual_format: c_int = undefined;
        var nitems: c_ulong = undefined;
        var bytes_after: c_ulong = undefined;
        var prop: [*c]xlib.Atom = null;

        const status = xlib.XGetWindowProperty(
            display,
            window,
            wm_state,
            0,
            1024,
            xlib.False,
            xlib.XA_ATOM,
            &actual_type,
            &actual_format,
            &nitems,
            &bytes_after,
            @ptrCast(&prop),
        );

        if (status == xlib.Success and prop != null) {
            defer _ = xlib.XFree(prop);
            var i: usize = 0;
            while (i < nitems) : (i += 1) {
                if (prop[i] == fullscreen_atom) {
                    // setBypassCompositor(display, window, true);
                    return;
                    // confirmed — done
                } 
            }
        }
    }
}

pub fn toggleFullscreen(io: std.Io, win: *Window) !void {
    _ = try waitForWM(io, win.display, xlib.RootWindow(win.display, win.screen), 2000);

    var xev: xlib.XClientMessageEvent = std.mem.zeroes(xlib.XClientMessageEvent);
    xev.type = xlib.ClientMessage;
    xev.window = win.window;
    xev.message_type = xlib.XInternAtom(win.display, "_NET_WM_STATE", xlib.False);
    xev.format = 32;
    xev.data.l[0] = 2;
    xev.data.l[1] = @intCast(xlib.XInternAtom(win.display, "_NET_WM_STATE_FULLSCREEN", xlib.False));
    xev.data.l[2] = 0;
    xev.data.l[3] = 1;

    _ = xlib.XSendEvent(
        win.display,
        xlib.RootWindow(win.display, win.screen),
        xlib.False,
        xlib.SubstructureRedirectMask | xlib.SubstructureNotifyMask,
        @ptrCast(&xev),
    );

    win.fullscreen = !win.fullscreen;
    // setBypassCompositor(win.display, win.window, win.fullscreen);
}

pub fn sync(win: *Window) void {
    _ = xlib.XSync(win.display, xlib.False);
}

pub fn windowShouldClose(win: *Window) bool {
    return win.should_close;
}

pub fn wmSupportsFullscreen(display: *xlib.Display, root: xlib.Window) bool {
    const net_supported = xlib.XInternAtom(display, "_NET_SUPPORTED", xlib.False);
    const fullscreen_atom = xlib.XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", xlib.False);

    var actual_type: xlib.Atom = undefined;
    var actual_format: c_int = undefined;
    var nitems: c_ulong = undefined;
    var bytes_after: c_ulong = undefined;
    var prop: [*c]xlib.Atom = null;

    const status = xlib.XGetWindowProperty(
        display,
        root,
        net_supported,
        0,
        1024, // long enough to grab a reasonably-sized atom list
        xlib.False,
        xlib.XA_ATOM,
        &actual_type,
        &actual_format,
        &nitems,
        &bytes_after,
        @ptrCast(&prop),
    );

    if (status != xlib.Success or prop == null) return false;
    defer _ = xlib.XFree(prop);

    var i: usize = 0;
    while (i < nitems) : (i += 1) {
        if (prop[i] == fullscreen_atom) return true;
    }
    return false;
}

pub fn close(win: *Window) void {
    win.should_close = true;
}

pub fn destroyWindow(allocator: std.mem.Allocator, win: *Window) void {
    if (win.cursor) |c| {
        _ = xlib.XFreeCursor(win.display, c);
    }
    _ = xlib.XDestroyWindow(win.display, win.window);
    win.events.deinit(allocator);
    allocator.destroy(win);
}

fn setBypassCompositor(display: *xlib.Display, window: xlib.Window, bypass: bool) void {
    const bypass_atom = xlib.XInternAtom(display, "_NET_WM_BYPASS_COMPOSITOR", xlib.False);
    var value: c_long = @intFromBool(bypass);
    _ = xlib.XChangeProperty(display, 
        window,
        bypass_atom,
        xlib.XA_CARDINAL,
        32,
        xlib.PropModeReplace,
        @ptrCast(&value),
        1
    );
}

fn getPrimaryMonitorOrigin(display: *xlib.Display, root: xlib.Window) struct {x: i32, y: i32} {
    const primary_output = xlib.XRRGetOutputPrimary(display, root);
    const resources = xlib.XRRGetScreenResourcesCurrent(display, root);
    defer xlib.XRRFreeScreenResources(resources);

    if (primary_output != 0) {
        const output_info = xlib.XRRGetOutputInfo(display, resources, primary_output);
        defer xlib.XRRFreeOutputInfo(output_info);

        if (output_info.*.crtc != 0) {
            const crtc_info = xlib.XRRGetCrtcInfo(display, resources, output_info.*.crtc);
            defer xlib.XRRFreeCrtcInfo(crtc_info);
            return .{ .x = crtc_info.*.x, .y = crtc_info.*.y };
        }
    }

    return .{ .x = 0, .y = 0 };
}

pub fn hideCursor(win: *Window) void {
    if (win.cursor) |c| {
        _ = xlib.XDefineCursor(win.display, win.window, c);
    } else {
        const empty_data = [_]u8{0};

        const bitmap = xlib.XCreateBitmapFromData(
            win.display,
            win.window,
            &empty_data,
            1,
            1
        );

        var fg = xlib.XColor{};
        var bg = xlib.XColor{};

        const cursor = xlib.XCreatePixmapCursor(
            win.display,
            bitmap,
            bitmap,
            &fg,
            &bg,
            0,
            0,
        );

        _ = xlib.XDefineCursor(win.display, win.window, cursor);
        _ = xlib.XFreePixmap(win.display, bitmap);
        win.cursor = cursor;
    }
}

pub fn showCursor(win: *Window) void {
    _ = xlib.XUndefineCursor(win.display, win.window);
}
