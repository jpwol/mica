const std = @import("std");
const w = @import("../../../WIN32.zig");
const win32 = @import("c");

const Canvas = @import("../../../render/software.zig");
const Window = @import("window.zig").Window;

pub const SoftwareRenderer = struct {
    hbitmap: w.HBITMAP,
    pixels: [*]u8,
    mem_dc: w.HDC,
    width: u32,
    height: u32,
    win: *Window,
};

fn makeBitmapInfo(width: u32, height: u32) w.BITMAPINFO {
    return .{ 
        .bmiHeader = .{
            .biSize = @sizeOf(w.BITMAPINFO),
            .biWidth = @intCast(width),
            .biHeight = -@as(i32, @intCast(height)),
            .biPlanes = 1,
            .biBitCount = 32,
            .biCompression = w.BI_RGB,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        },
        .bmiColors = .{0},
    };
}

pub fn createSoftwareRenderer(allocator: std.mem.Allocator, win: *Window) !SoftwareRenderer {
    _ = allocator;

    const width = win.width;
    const height = win.height;

    const screen_dc = w.GetDC(win.window) orelse return error.GetDCFailed;
    defer _ = w.ReleaseDC(win.window, screen_dc);

    const mem_dc = w.CreateCompatibleDC(screen_dc) orelse return error.CreateCompatibleDCFailed;
    errdefer _ = w.DeleteDC(mem_dc);

    const bmi = makeBitmapInfo(width, height);
    var bits: ?*anyopaque = null;
    const hbitmap = w.CreateDIBSection(
        mem_dc, 
        &bmi, 
        w.DIB_RGB_COLORS, 
        &bits, 
        null,
        0
    ) orelse return error.CreateDIBSectionFailed;

    return .{
        .hbitmap = hbitmap,
        .pixels = @ptrCast(bits.?),
        .mem_dc = mem_dc,
        .width = width,
        .height = height,
        .win = win,
    };
}

pub fn getCanvas(allocator: std.mem.Allocator, renderer: *SoftwareRenderer) !Canvas {
    if (renderer.width != renderer.win.width or renderer.height != renderer.win.height) {
        try resize(allocator, renderer.win, renderer);
    }
    return .{
        .pixels = renderer.pixels[0 .. renderer.width * renderer.height * 4],
        .width = renderer.width,
        .height = renderer.height,
        .stride = renderer.width * 4,
    };
}

pub fn present(win: *Window, renderer: *SoftwareRenderer) void {
    const screen_dc = w.GetDC(win.window) orelse return;
    defer _ = w.ReleaseDC(win.window, screen_dc);

    _ = w.SelectObject(renderer.mem_dc, renderer.hbitmap);
    _ = w.BitBlt(
        screen_dc, 
        0, 0, 
        @intCast(renderer.width), @intCast(renderer.height), 
        renderer.mem_dc, 
        0, 0, 
        w.SRCCOPY
    );
}

fn resize(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) !void {
    _ = w.DeleteObject(renderer.hbitmap); 
    _ = w.DeleteDC(renderer.mem_dc);
    renderer.* = try createSoftwareRenderer(allocator, win);
}

pub fn destroy(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) void {
    _ = allocator;
    _ = win;
    _ = w.DeleteObject(renderer.hbitmap);
    _ = w.DeleteDC(renderer.mem_dc);
}
