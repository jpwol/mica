const std = @import("std");
const Window = @import("../core/platform/x11/window.zig").Window;
const xlib = @import("xlib");

pub const Canvas = @This();

pixels: []u8,
width: u32,
height: u32,
stride: u32,

pub const Color = struct { r: u8, g: u8, b: u8, a: u8 = 255 };

pub fn setPixel(canvas: *Canvas, x: i32, y: i32, color: Color) void {
    if (x < 0 or y < 0 or x >= canvas.width or y >= canvas.height) return;

    const idx = @as(usize, @intCast(y)) * canvas.stride + @as(usize, @intCast(x)) * 4;
    canvas.pixels[idx + 0] = color.b;
    canvas.pixels[idx + 1] = color.g;
    canvas.pixels[idx + 2] = color.r;
    canvas.pixels[idx + 3] = color.a;
}

pub fn fillRect(canvas: *Canvas, x: i32, y: i32, w: u32, h: u32, color: Color) void {
    var row: u32 = 0;
    while (row < h) : (row += 1) {
        var col: u32 = 0;
        while (col < w) : (col += 1) {
            setPixel(canvas, x + @as(i32, @intCast(col)), y + @as(i32, @intCast(row)), color);
        }
    }
}

pub fn clear(canvas: *Canvas, color: Color) void {
    const packed_color: u32 = (@as(u32, color.a) << 24) | (@as(u32, color.r) << 16) | (@as(u32, color.g) << 8) | color.b;

    const pixels_u32: [*]u32 = @ptrCast(@alignCast(canvas.pixels.ptr));
    const pixel_count = canvas.width * canvas.height;
    @memset(pixels_u32[0..pixel_count], packed_color);
}
