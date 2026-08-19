const std = @import("std");

pub const Canvas = @This();

pixels: []u8,
width: u32,
height: u32,
stride: u32,

pub const Color = struct { r: u8, g: u8, b: u8, a: u8 = 255 };

// consider bitshifting the color to a variable and assinging it in one step?
pub fn setPixel(canvas: *Canvas, x: i32, y: i32, color: Color) void {
    if (x < 0 or y < 0 or x >= canvas.width or y >= canvas.height) return;

    const idx = @as(usize, @intCast(y)) * canvas.stride + @as(usize, @intCast(x)) * 4;
    canvas.pixels[idx + 0] = color.b;
    canvas.pixels[idx + 1] = color.g;
    canvas.pixels[idx + 2] = color.r;
    canvas.pixels[idx + 3] = color.a;
}

// test performance on calling setPixel vs performing the buffer assignment locally
pub fn drawLine(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
    var x: i32 = x1;
    var y: i32 = y1;

    const dx: i32 = @intCast(@abs(x2 - x1));
    const sx: i32 = if (x1 < x2) 1 else -1;
    const dy: i32 = -@as(i32, @intCast(@abs(y2 - y1)));
    const sy: i32 = if (y1 < y2) 1 else -1;
    var err =  dx + dy;

    while (true) {
        setPixel(canvas, x, y, color);
        const e2 = 2 * err;
        if (e2 >= dy) {
            if (x == x2) break;
            err = err + dy;
            x = x + sx;
        }
        if (e2 <= dx) {
            if (y == y2) break;
            err = err + dx;
            y = y + sy;
        }
    }
}

// Below is Bresenham's four-way octant dispatch line drawing algorithm. It is unused in favor
// of the unified octant-agnostic version, as performance in this area will be dominated by
// memory writes instead of a couple extra if calls
//
// FIXME: Run some perf tests anyways and remove this if the difference is negligable

// pub fn drawLine(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
//     if (@abs(y2 - y1) < @abs(x2 - x1)) {
//         if (x1 > x2) {
//             plotLineLow(canvas, x2, y2, x1, y1, color);
//         } else {
//             plotLineLow(canvas, x1, y1, x2, y2, color);
//         }
//     } else {
//         if (y1 > y2) {
//             plotLineHigh(canvas, x2, y2, x1, y1, color);
//         } else {
//             plotLineHigh(canvas, x1, y1, x2, y2, color);
//         }
//     }
// }
//
//
// fn plotLineLow(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
//     const dx = x2 - x1;
//     var dy = y2 - y1;
//     var yi: i32 = 1;
//     if (dy < 0) {
//         yi = -1;
//         dy = -dy;
//     }
//     var D = (2 * dy) - dx;
//     var y = y1;
//
//     var x: i32 = x1;
//     while (x < x2) : (x += 1) {
//         setPixel(canvas, x, y, color);
//         if (D > 0) {
//             y = y + yi;
//             D = D + (2 * (dy - dx));
//         } else {
//             D = D + 2 * dy;
//         }
//     }
// }
//
// fn plotLineHigh(canvas: *Canvas, x1: i32, y1: i32, x2: i32, y2: i32, color: Color) void {
//     var dx = x2 - x1;
//     const dy = y2 - y1;
//     var xi: i32 = 1;
//     if (dx < 0) {
//         xi = -1;
//         dx = -dx;
//     }
//     var D = (2 * dx) - dy;
//     var x = x1;
//
//     var y: i32 = y1;
//     while (y < y2) : (y += 1) {
//         setPixel(canvas, x, y, color);
//         if (D > 0) {
//             x = x + xi;
//             D = D + (2 * (dx - dy));
//         } else {
//             D = D + 2 * dx;
//         }
//     }
// }

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
