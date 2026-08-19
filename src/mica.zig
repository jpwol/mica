const std = @import("std");
const builtin = @import("builtin");

// TODO: This whole struct/file should optimally be structured
//       as a vtable. This would avoid having functions look like
//
//           pub fn doThing() { backend.doThing(); }
//
//       We should also provide an option to NOT initialize
//       a specific backend if that backend is not requested (audio backend).
//       Defaulting to all backends requested is fine, but an "opt-out" feature
//       would be best.
//
//       Additionally, we should consider how much of this file should be exposed
//       to the user. Do we want them aware of all these structs?
//
//       Making certain things like Window an *opaque would probably be a good idea,
//       as allowing the user to see all the backend stuff is tricky business. This has
//       the downside of not exposing win.width and win.height which are useful.
//
//       In that case, a good tradeoff might be having a top-level Window struct, with an internal
//       "backend window" handle, and storing an immutable pointer to width and height to track their values.
//
//       This might be a good idiomatic solution for the structure of the rest of the api as well.
//
//       Worth considering a structure like 
//
//           mica.audio.playSound() and mica.video.createWindow();
//
//       This would allow the user to optionally do
//
//           const video = mica.video;
//           video.createWindow();
//
//           const audio = mica.audio;
//           audio.playSound();
//       
//       and also has the benefit of exposing utilities behind a different surface
//
//           mica.loader.loadWAVFile() / mica.loader.audio.loadWAVFile();
//
//           or
//
//           mica.utility.loadWAVFile();
//       

const Mica = @This();

// WARNING: The below implementation is a TEMPORARY implementation
//          for getting all the backend bits to the user end for testing.
//          The final version will not be this dangerously open/messy.

const video_backend = switch (builtin.target.os.tag) {
    .linux => @import("core/video/x11/window.zig"),
    .windows => @import("core/video/windows/window.zig"),
    else => @compileError("mica: unsupported platform"),
};

const event_handler = switch (builtin.target.os.tag) {
    .linux => @import("core/video/x11/event.zig"),
    .windows => @import("core/video/windows/event.zig"),
    else => @compileError("mica: unsupported platform"),
};

const render_backend = switch (builtin.target.os.tag) {
    .linux => @import("core/video/x11/software.zig"),
    .windows => @import("core/video/windows/software.zig"),
    else => @compileError("mica: unsupported platform"),
};

const audio_driver = switch (builtin.target.os.tag) {
    .linux => @import("core/audio/pulseaudio/pulse.zig"),
    .windows => @compileError("mica: WASAPI backend not yet implemented"),
    else => @compileError("mica: unsupported platform"),
};

const audio_loader = @import("loader/audio.zig");

io: std.Io,
allocator: std.mem.Allocator,
audio_backend: *audio_driver.AudioBackend,

pub const Window = video_backend.Window;
pub const WindowFlags = video_backend.WindowFlags;

const e = @import("core/events.zig");

pub const Key = e.Key;
pub const Event = e.Event;
pub const Modifiers =  e.Modifiers;
pub const MouseButton = e.MouseButton;

pub const render = @import("render/software.zig");
pub const Canvas = render.Canvas;
pub const Color = render.Color;

pub const audio = @import("core/audio.zig");
pub const Sound = audio.Sound;
pub const VoiceHandle = audio.VoiceHandle;
pub const PlayOptions = audio.PlayOptions;

pub const SoftwareRenderer = render_backend.SoftwareRenderer;

pub fn init(io: std.Io, allocator: std.mem.Allocator) !Mica {
    const bkend = try audio_driver.init(allocator);
    return .{
        .io = io,
        .allocator = allocator,
        .audio_backend = bkend,
    };
}

pub fn deinit(self: *Mica) void {
    audio_driver.deinit(self.audio_backend, self.allocator);
}

pub fn createWindow(self: *Mica, title: []const u8, w: u24, h: u24, flags: WindowFlags) !*Window {
    return try video_backend.createWindow(self.io, self.allocator, title, w, h, flags);
}

pub fn destroyWindow(self: *Mica, win: *Window) void {
    video_backend.destroyWindow(self.allocator, win);
}

pub fn close(self: *Mica, win: *Window) void {
    _ = self;
    video_backend.close(win);
}

pub fn sync(self: *Mica, win: *Window) void {
    _ = self;
    video_backend.sync(win);
}

pub fn windowShouldClose(self: *Mica, win: *Window) bool {
    _ = self;
    return video_backend.windowShouldClose(win);
}

pub fn toggleFullscreen(self: *Mica, win: *Window) !void {
    try video_backend.toggleFullscreen(self.io, win);
}

pub fn hideCursor(self: *Mica, win: *Window) void {
    _ = self;
    video_backend.hideCursor(win);
}

pub fn showCursor(self: *Mica, win: *Window) void {
    _ = self;
    video_backend.showCursor(win);
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
    return render_backend.createSoftwareRenderer(self.allocator, win);
}

pub fn getCanvas(self: *Mica, sr: *SoftwareRenderer) !Canvas {
    return render_backend.getCanvas(self.allocator, sr);
}

pub fn present(self: *Mica, win: *Window, sr: *SoftwareRenderer) void {
    _ = self;
    render_backend.present(win, sr);
}

pub fn resizeRenderer(self: *Mica, win: *Window, sr: *SoftwareRenderer) !void {
    try render_backend.resize(self.allocator, win, sr);
}

pub fn destroySoftwareRenderer(self: *Mica, win: *Window, sr: *SoftwareRenderer) void {
    render_backend.destroy(self.allocator, win, sr);
}

pub fn createSound(
    self: *Mica,
    samples: []const f32,
    opts: struct { 
        sample_rate: u32 = 44100,
        channels: u8 = 1,
        loop_start: ?usize = null,
        loop_end: ?usize = null,
    }) !Sound {
    _ = self;
    return .{
        .samples = @constCast(samples),
        .sample_rate = opts.sample_rate,
        .channels = opts.channels,
        .loop_start = opts.loop_start,
        .loop_end = opts.loop_end,
    };
}

pub fn playSound(self: *Mica, sound: Sound, opts: PlayOptions) !VoiceHandle {
    return try audio.playSound(self.audio_backend, sound, opts);
}

pub fn stopSound(self: *Mica, handle: VoiceHandle) void {
    audio.stopSound(self.audio_backend.state, handle);
}

pub fn stopLoop(self: *Mica, handle: VoiceHandle) void {
    audio.stopLoop(self.audio_backend.state, handle);
}

pub fn pauseSound(self: *Mica, handle: VoiceHandle) void {
    audio.pauseSound(self.audio_backend.state, handle);
}

pub fn resumeSound(self: *Mica, handle: VoiceHandle) void {
    audio.resumeSound(self.audio_backend.state, handle);
}

pub fn setVolume(self: *Mica, handle: VoiceHandle, volume: f32) void {
    audio.setVolume(&self.audio_state, handle, volume);
}

pub fn createAudioStream(self: *Mica, opts: PlayOptions, callback: audio.StreamCallback, ctx: ?*anyopaque) !audio.StreamHandle {
    return try audio.createAudioStream(self.audio_backend.state, opts, callback, ctx);
}

pub fn stopAudioStream(self: *Mica, handle: audio.StreamHandle) void {
    return audio.stopAudioStream(self.audio_backend.state, handle);
}
pub fn loadWAVFile(self: *Mica, path: []const u8, desired_channels: audio_loader.Channel) !audio_loader.WavSpec {
    return try audio_loader.loadWAVFile(self.io, self.allocator, path, desired_channels);
}

