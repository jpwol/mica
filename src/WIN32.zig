// Zig's translate-c breaks certain long macro chains, especially
// in the context of WIN32.
//
// In that context, certain values depend on obfuscated macros that chain together, 
// eventually going through MinGW.
//
// This file serves as lightweight bindings for the WIN32 API. As issues are encountered,
// this file will grow. Once the Windows implementation is complete, it would be smart
// to transfer all types, structures, and functions that are used to this file. This way,
// a user does not need to translate 100k+ lines of C to Zig, which *severely* slows down zls.

// Type Definitions
pub const WORD = u16;
pub const DWORD = u32;
pub const UINT = u32;
pub const LPARAM = isize;
pub const WPARAM = usize;
pub const LRESULT = isize;
pub const LPCSTR = ?[*:0]const u8;
pub const LPCWSTR = ?[*:0]const u16;
pub const HWND = *opaque{};
pub const HINSTANCE = *opaque{};
pub const HICON = *opaque{};
pub const HCURSOR = *opaque{};
pub const HBRUSH = *opaque{};
pub const HMENU = *opaque{};
pub const ATOM = c_ushort;
pub const LPVOID = *anyopaque;
// FIXME: update to convert to boolean maybe?
pub const WINBOOL = c_int;

pub const WINDOW_LONG_PTR_INDEX = enum(i32) {
    _EXSTYLE = -20,
    P_HINSTANCE = -6,
    P_HWNDPARENT = -8,
    P_ID = -12,
    _STYLE = -16,
    P_USERDATA = -21,
    P_WNDPROC = -4,
};

pub const MAPVK_VSC_TO_VK_EX: u32 = 3;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: ?WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: ?HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: LPCWSTR,
    lpszClassName: LPCWSTR,
    hIconSm: ?HICON,
};

// WinUser.h

// Keymaps
pub const VK_BACK: u32 = 0x08;
pub const VK_TAB: u32 = 0x09;
pub const VK_RETURN: u32 = 0x0D;
pub const VK_SHIFT: u32 = 0x10;
pub const VK_CONTROL: u32 = 0x11;
pub const VK_MENU: u32 = 0x12; // alt
pub const VK_ESCAPE: u32 = 0x1B;
pub const VK_SPACE: u32 = 0x20;
pub const VK_PRIOR: u32 = 0x21; // page up
pub const VK_NEXT: u32 = 0x22;  // page down
pub const VK_END: u32 = 0x23;
pub const VK_HOME: u32 = 0x24;
pub const VK_LEFT: u32 = 0x25;
pub const VK_UP: u32 = 0x26;
pub const VK_RIGHT: u32 = 0x27;
pub const VK_DOWN: u32 = 0x28;
pub const VK_INSERT: u32 = 0x2D;
pub const VK_DELETE: u32 = 0x2E;
// VK_0 - VK_9 are 0x30-0x39, same as ASCII digits
// VK_A - VK_Z are 0x41-0x5A, same as ASCII uppercase letters
pub const VK_LWIN: u32 = 0x5B;
pub const VK_RWIN: u32 = 0x5C;
pub const VK_NUMPAD0: u32 = 0x60;
pub const VK_NUMPAD1: u32 = 0x61;
pub const VK_NUMPAD2: u32 = 0x62;
pub const VK_NUMPAD3: u32 = 0x63;
pub const VK_NUMPAD4: u32 = 0x64;
pub const VK_NUMPAD5: u32 = 0x65;
pub const VK_NUMPAD6: u32 = 0x66;
pub const VK_NUMPAD7: u32 = 0x67;
pub const VK_NUMPAD8: u32 = 0x68;
pub const VK_NUMPAD9: u32 = 0x69;
pub const VK_MULTIPLY: u32 = 0x6A;
pub const VK_ADD: u32 = 0x6B;
pub const VK_SUBTRACT: u32 = 0x6D;
pub const VK_DECIMAL: u32 = 0x6E;
pub const VK_DIVIDE: u32 = 0x6F;
pub const VK_F1: u32 = 0x70;
pub const VK_F2: u32 = 0x71;
pub const VK_F3: u32 = 0x72;
pub const VK_F4: u32 = 0x73;
pub const VK_F5: u32 = 0x74;
pub const VK_F6: u32 = 0x75;
pub const VK_F7: u32 = 0x76;
pub const VK_F8: u32 = 0x77;
pub const VK_F9: u32 = 0x78;
pub const VK_F10: u32 = 0x79;
pub const VK_F11: u32 = 0x7A;
pub const VK_F12: u32 = 0x7B;
pub const VK_LSHIFT: u32 = 0xA0;
pub const VK_RSHIFT: u32 = 0xA1;
pub const VK_LCONTROL: u32 = 0xA2;
pub const VK_RCONTROL: u32 = 0xA3;
pub const VK_LMENU: u32 = 0xA4;
pub const VK_RMENU: u32 = 0xA5;
pub const VK_OEM_1: u32 = 0xBA;      // ;:
pub const VK_OEM_PLUS: u32 = 0xBB;   // =+
pub const VK_OEM_COMMA: u32 = 0xBC;  // ,
pub const VK_OEM_MINUS: u32 = 0xBD;  // -_
pub const VK_OEM_PERIOD: u32 = 0xBE; // .>
pub const VK_OEM_2: u32 = 0xBF;      // /?
pub const VK_OEM_3: u32 = 0xC0;      // `~
pub const VK_OEM_4: u32 = 0xDB;      // [{
pub const VK_OEM_5: u32 = 0xDC;      // \|
pub const VK_OEM_6: u32 = 0xDD;      // ]}
pub const VK_OEM_7: u32 = 0xDE;      // '"
pub const VK_CAPITAL: u32 = 0x14;    // Caps Lock
pub const VK_SNAPSHOT: u32 = 0x2C;   // Print Screen
pub const VK_SCROLL: u32 = 0x91;     // Scroll Lock
pub const VK_PAUSE: u32 = 0x13;

// Standard Cursor IDs
pub const IDC_ARROW       : ?[*:0]align(1) const u16 = @ptrFromInt(32512);
pub const IDC_IBEAM       : ?[*:0]align(1) const u16 = @ptrFromInt(32513);
pub const IDC_WAIT        : ?[*:0]align(1) const u16 = @ptrFromInt(32514);
pub const IDC_CROSS       : ?[*:0]align(1) const u16 = @ptrFromInt(32515);
pub const IDC_UPARROW     : ?[*:0]align(1) const u16 = @ptrFromInt(32516);
pub const IDC_SIZE        : ?[*:0]align(1) const u16 = @ptrFromInt(32640);
pub const IDC_ICON        : ?[*:0]align(1) const u16 = @ptrFromInt(32641);
pub const IDC_SIZENWSE    : ?[*:0]align(1) const u16 = @ptrFromInt(32642);
pub const IDC_SIZENESW    : ?[*:0]align(1) const u16 = @ptrFromInt(32643);
pub const IDC_SIZEWE      : ?[*:0]align(1) const u16 = @ptrFromInt(32644);
pub const IDC_SIZENS      : ?[*:0]align(1) const u16 = @ptrFromInt(32645);
pub const IDC_SIZEALL     : ?[*:0]align(1) const u16 = @ptrFromInt(32646);
pub const IDC_NO          : ?[*:0]align(1) const u16 = @ptrFromInt(32648);
pub const IDC_HAND        : ?[*:0]align(1) const u16 = @ptrFromInt(32649);
pub const IDC_APPSTARTING : ?[*:0]align(1) const u16 = @ptrFromInt(32650);
pub const IDC_HELP        : ?[*:0]align(1) const u16 = @ptrFromInt(32651);

// ShowWindow() Commands
pub const SW_HIDE            : c_int = 0;
pub const SW_SHOWNORMAL      : c_int = 1;
pub const SW_NORMAL          : c_int = 1;
pub const SW_SHOWMINIMIZED   : c_int = 2;
pub const SW_SHOWMAXIMIZED   : c_int = 3;
pub const SW_MAXIMIZE        : c_int = 3;
pub const SW_SHOWNOACTIVATE  : c_int = 4;
pub const SW_SHOW            : c_int = 5;
pub const SW_MINIMIZE        : c_int = 6;
pub const SW_SHOWMINNOACTIVE : c_int = 7;
pub const SW_SHOWNA          : c_int = 8;
pub const SW_RESTORE         : c_int = 9;
pub const SW_SHOWDEFAULT     : c_int = 10;
pub const SW_FORCEMINIMIZE   : c_int = 11;
pub const SW_MAX             : c_int = 11;

// Window Styles
pub const WS_OVERLAPPED       : DWORD = 0x00000000;   
pub const WS_POPUP            : DWORD = 0x80000000;   
pub const WS_CHILD            : DWORD = 0x40000000;   
pub const WS_MINIMIZE         : DWORD = 0x20000000;   
pub const WS_VISIBLE          : DWORD = 0x10000000;   
pub const WS_DISABLED         : DWORD = 0x08000000;   
pub const WS_CLIPSIBLINGS     : DWORD = 0x04000000;   
pub const WS_CLIPCHILDREN     : DWORD = 0x02000000;   
pub const WS_MAXIMIZE         : DWORD = 0x01000000;   
pub const WS_CAPTION          : DWORD = 0x00C00000;   
pub const WS_BORDER           : DWORD = 0x00800000;   
pub const WS_DLGFRAME         : DWORD = 0x00400000;   
pub const WS_VSCROLL          : DWORD = 0x00200000;   
pub const WS_HSCROLL          : DWORD = 0x00100000;   
pub const WS_SYSMENU          : DWORD = 0x00080000;   
pub const WS_THICKFRAME       : DWORD = 0x00040000;   
pub const WS_GROUP            : DWORD = 0x00020000;   
pub const WS_TABSTOP          : DWORD = 0x00010000;   

pub const WS_MINIMIZEBOX      : DWORD = 0x00020000;   
pub const WS_MAXIMIZEBOX      : DWORD = 0x00010000;   


pub const WS_TILED            = WS_OVERLAPPED;
pub const WS_ICONIC           = WS_MINIMIZE;
pub const WS_SIZEBOX          = WS_THICKFRAME;
pub const WS_TILEDWINDOW      = WS_OVERLAPPEDWINDOW;

pub const WS_OVERLAPPEDWINDOW = (WS_OVERLAPPED  |
                                 WS_CAPTION     |
                                 WS_SYSMENU     |
                                 WS_THICKFRAME  |
                                 WS_MINIMIZEBOX |
                                 WS_MAXIMIZEBOX);

pub const WS_POPUPWINDOW      = (WS_POPUP       | 
                                 WS_BORDER      | 
                                 WS_SYSMENU);

pub const WS_CHILDWINDOW = (WS_CHILD);


const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub extern "kernel32" fn GetModuleHandleW(
    lpModuleName: LPCWSTR
) callconv(.winapi) ?HINSTANCE;

pub extern "user32" fn DefWindowProcW(
    hWnd: ?HWND,
    Msg: u32,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.winapi) LRESULT;

pub extern "user32" fn SetWindowLongPtrW(
    hWnd: ?HWND,
    nIndex: WINDOW_LONG_PTR_INDEX,
    dwNewLong: isize,
) callconv(.winapi) isize;

pub extern "user32" fn GetWindowLongPtrW(
    hWnd: ?HWND,
    nIndex: WINDOW_LONG_PTR_INDEX,
) callconv(.winapi) isize;

pub extern "user32" fn LoadCursorW(
    hInstance: ?HINSTANCE,
    lpCursorName: LPCWSTR
) callconv(.winapi) HCURSOR;

pub extern "user32" fn RegisterClassExW(
    *const WNDCLASSEXW
) callconv(.winapi) ATOM;

pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: LPCWSTR,
    lpWindowName: LPCWSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: ?HINSTANCE,
    lpParam: ?LPVOID
) callconv(.winapi) ?HWND;

// FIXME: Update to convert return to boolean maybe?
pub extern "user32" fn ShowWindow(
    hWnd: HWND,
    nCmdShow: i32
) callconv(.winapi) WINBOOL;

pub extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;

pub extern "user32" fn MapVirtualKeyW(
    uCode: u32, uMapType: u32
) callconv(.winapi) u32;

pub inline fn getXLparam(lparam: LPARAM) i32 {
    return @as(i16, @bitCast(@as(u16, @truncate(@as(u64, @bitCast(lparam)) & 0xFFFF))));
}

pub inline fn getYLparam(lparam: LPARAM) i32 {
    return @as(i16, @bitCast(@as(u16, @truncate((@as(u64, @bitCast(lparam)) >> 16) & 0xFFFF))));
}

pub inline fn getWheelDelta(wparam: WPARAM) i32 {
    return @as(i16, @bitCast(@as(u16, @truncate((wparam >> 16) & 0xFFFF))));
}

pub extern "user32" fn GetKeyState(nVirtKey: i32) callconv(.winapi) i16;
