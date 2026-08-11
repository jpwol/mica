const std = @import("std");
const builtin = @import("builtin");

const Mica = @This();

const backend = switch (builtin.target.os.tag) {
    .linux => @import("core/platform/x11/window.zig"),
    .windows => @import("core/platform/windows/window.zig"),
    else => @compileError("mica: unsupported platform"),
};

const event_handler = switch (builtin.target.os.tag) {
    .linux => @import("core/platform/x11/event.zig"),
    .windows => @import("core/platform/windows/event.zig"),
    else => @compileError("mica: unsupported platform"),
};

const renderer = switch (builtin.target.os.tag) {
    .linux => @import("core/platform/x11/software.zig"),
    else => @compileError("mica: unsupported platform"),
};

allocator: std.mem.Allocator,
io: std.Io,

pub const Window = backend.Window;
pub const WindowFlags = backend.WindowFlags;

const e = @import("core/events.zig");

pub const Key = e.Key;
pub const Event = e.Event;
pub const Modifiers =  e.Modifiers;
pub const MouseButton = e.MouseButton;

pub const render = @import("render/software.zig");
pub const Canvas = render.Canvas;
pub const Color = render.Color;

pub const SoftwareRenderer = renderer.SoftwareRenderer;

pub fn init(io: std.Io, allocator: std.mem.Allocator) Mica {
    return .{
        .io = io,
        .allocator = allocator,
    };
}

pub fn createWindow(self: *Mica, title: []const u8, w: u32, h: u32, flags: WindowFlags) !*Window {
    return try backend.createWindow(self.io, self.allocator, title, w, h, flags);
}

pub fn destroyWindow(self: *Mica, win: *Window) void {
    backend.destroyWindow(self.allocator, win);
}

pub fn close(self: *Mica, win: *Window) void {
    _ = self;
    backend.close(win);
}

pub fn sync(self: *Mica, win: *Window) void {
    _ = self;
    backend.sync(win);
}

pub fn windowShouldClose(self: *Mica, win: *Window) bool {
    _ = self;
    return backend.windowShouldClose(win);
}

pub fn toggleFullscreen(self: *Mica, win: *Window) !void {
    try backend.toggleFullscreen(self.io, win);
}

pub fn hideCursor(self: *Mica, win: *Window) void {
    _ = self;
    backend.hideCursor(win);
}

pub fn showCursor(self: *Mica, win: *Window) void {
    _ = self;
    backend.showCursor(win);
}

pub fn pollEvents(self: *Mica, win: *Window) ![]const Event {
    return event_handler.pollEvents(self.io, self.allocator, win);
}

pub fn isKeyDown(self: *Mica, win: *Window, key: Key) bool {
    _ = self;
    return event_handler.isKeyDown(win, key);
}
pub fn wasKeyPressed(self: *Mica, win: *Window, key: Key) bool {
    _ = self;
    return event_handler.wasKeyPressed(win, key);
}

pub fn keyHeldDuration(self: *Mica, win: *Window, key: Key) ?i64 {
    return event_handler.keyHeldDuration(self.io, win, key);
}

pub fn getCursorPos(self: *Mica, win: *Window, x: *i64, y: *i64) void {
    _ = self;
    event_handler.getCursorPos(win, x, y);
}

pub fn createSoftwareRenderer(self: *Mica, win: *Window) !SoftwareRenderer {
    return renderer.createSoftwareRenderer(self.allocator, win);
}

pub fn getCanvas(self: *Mica, sr: *SoftwareRenderer) !Canvas {
    return renderer.getCanvas(self.allocator, sr);
}

pub fn present(self: *Mica, win: *Window, sr: *SoftwareRenderer) void {
    _ = self;
    renderer.present(win, sr);
}

pub fn resizeRenderer(self: *Mica, win: *Window, sr: *SoftwareRenderer) !void {
    try renderer.resize(self.allocator, win, sr);
}

pub fn destroySoftwareRenderer(self: *Mica, win: *Window, sr: *SoftwareRenderer) void {
    renderer.destroy(self.allocator, win, sr);
}
