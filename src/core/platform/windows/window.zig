const std = @import("std");
const w = @import("../../../WIN32.zig");
const win32 = @import("c");
const e = @import("../../events.zig");
const Key = e.Key;
const Event = e.Event;
const Modifiers = e.Modifiers;

// TODO: 
//      Implement cursor hiding/showing
//      Implement custom cursor loading
//      Add flags, implementation for the following:
//          - Fullscreen
//          - No decorations
//          - Min/Max size?
//      Query screen size? Implement way to place window either in user designated area or in a sensible location

const windowProc = @import("event.zig").windowProc;

pub const WindowFlags = packed struct {
    resizable: bool = false,
};

pub const Window = struct {
    hinstance: w.HINSTANCE,
    window: w.HWND,
    width: u32,
    height: u32,

    should_close: bool,
    events: std.ArrayList(Event),
    title: []u16,
    key_held: [std.meta.fields(Key).len]bool,
    key_pressed_this_frame: [std.meta.fields(Key).len]bool,
    key_released_this_frame: [std.meta.fields(Key).len]bool,
    key_down_time: [std.meta.fields(Key).len]?i64,
    modifiers: Modifiers,

    allocator: std.mem.Allocator,
    io: std.Io,
};

pub fn createWindow(io: std.Io, allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32, flags: WindowFlags) !*Window {
    var win: *Window = try allocator.create(Window); 

    // initialize struct members
    win.events = try .initCapacity(allocator, 0);
    win.key_held = [_]bool{false} ** std.meta.fields(Key).len;
    win.key_pressed_this_frame = [_]bool{false} ** std.meta.fields(Key).len;
    win.key_released_this_frame = [_]bool{false} ** std.meta.fields(Key).len;
    win.key_down_time = [_]?i64{null} ** std.meta.fields(Key).len;
    win.modifiers = .{};
    win.allocator = allocator;
    win.io = io;
    win.width = width;
    win.height = height;
    win.should_close = false;
    // win.window = null;

    const hinstance = w.GetModuleHandleW(null) orelse @panic("could not get module handle!");

    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("MicaWindow");
    const w_title = try std.unicode.utf8ToUtf16LeAlloc(allocator, title);
    var ex_style: w.DWORD = 0;
    if (false) {
        ex_style = 1;
    }

    var wc: w.WNDCLASSEXW = .{
        .cbSize = @sizeOf(w.WNDCLASSEXW),
        .style = 0,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = w.LoadCursorW(null, @ptrCast(@alignCast(w.IDC_ARROW))),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
        .hIconSm = null,
    };

    const class_atom = w.RegisterClassExW(&wc);
    if (class_atom == 0) {
        std.debug.print("RegisterClassExW failed: {}\n", .{w.GetLastError()});
    }

    var style: w.DWORD = w.WS_OVERLAPPEDWINDOW;
    if (!flags.resizable) {
        style &= ~w.WS_THICKFRAME;
        style &= ~w.WS_MAXIMIZEBOX;
    }

    win.hinstance = hinstance;
    // win.window = null;
    win.title = w_title;
    const hwnd = w.CreateWindowExW(
        ex_style, 
        class_name, 
        @ptrCast(w_title), 
        style, 
        500, 100, 
        @intCast(width), @intCast(height), 
        null, 
        null, 
        hinstance, 
        @ptrCast(win),
    ) orelse { 
        // FIXME: better error handling (custom GetLastError preferrably)
        std.debug.print("CreateWindowExW failed: {}\n", .{w.GetLastError()});
        return error.CreateWindowFailed; 
    };
    
    // if (hwnd == null) {
    //     // TODO: Implement global error tracking
    //     return error.CreateWindowFailed;
    // }

    win.window = hwnd;

    _ = w.ShowWindow(hwnd, w.SW_SHOW);

    return win;
}


pub fn windowShouldClose(win: *Window) bool {
    return win.should_close;
}
pub fn close(win: *Window) void {
    win.should_close = true;
}

pub fn destroyWindow(allocator: std.mem.Allocator, win: *Window) void {
    win.events.deinit(allocator);  
    allocator.free(win.title);
    allocator.destroy(win);
}
