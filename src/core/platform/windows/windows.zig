const std = @import("std");
const w = @import("../../../WIN32.zig");
const win32 = @import("c");

pub const WindowFlags = packed struct {
    resizable: bool = false,
};

pub const Window = struct {
    hinstance: win32.HINSTANCE,
    window: win32.HWND,
};

pub fn createWindow(io: std.Io, allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32, flags: WindowFlags) !*Window {
    _ = io;

    var win: *Window = try allocator.create(Window); 

    const hinstance = win32.GetModuleHandleW(null);
    const class_name = std.unicode.utf8ToUtf16LeStringLiteral("MicaWindow");
    const w_title = try std.unicode.utf8ToUtf16LeAlloc(allocator, title);
    var ex_style: win32.DWORD = 0;
    if (false) {
        ex_style = 1;
    }

    var wc: win32.WNDCLASSEXW = .{
        .cbSize = @sizeOf(win32.WNDCLASSEXW),
        .style = 0,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = win32.LoadCursorW(null, @ptrCast(@alignCast(w.IDC_ARROW))),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
        .hIconSm = null,
    };

    _ = win32.RegisterClassExW(&wc);

    const style: win32.DWORD = win32.WS_OVERLAPPEDWINDOW;
    if (!flags.resizable) {
        // style &= ~win32.WS_THICKFRAME;
        // style &= ~win32.WS_MAXIMIZEBOX;
    }

    const hwnd = win32.CreateWindowExW(
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
    );
    
    if (hwnd == null) {
        // TODO: Implement global error tracking
        return error.CreateWindowFailed;
    }

    _ = win32.ShowWindow(hwnd, win32.SW_SHOW);

    win.hinstance = hinstance;
    win.window = hwnd;

    return win;

}

fn windowProc(
    hwnd: win32.HWND,
    msg: u32,
    wparam: win32.WPARAM,
    lparam: win32.LPARAM
    ) callconv(.winapi) win32.LRESULT {
   switch (msg) {
       win32.WM_DESTROY => {
           win32.PostQuitMessage(0);
           return 0;
       },
       else => {
           return win32.DefWindowProcW(hwnd, msg, wparam, lparam);
       },
   }
}
