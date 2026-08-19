const std = @import("std");
const pa = @import("audio/pulseaudio/pulseaudio.zig");
const audio = @import("audio/pulseaudio/pulse.zig");

// TODO: Implement resampling. This is going to be a lot of work.
//       - Sound struct needs to be resampled from requested to server
//       - WAV files need to be resampled from internal to server

pub const AudioDevice = struct {
    id: []const u8,
    name: []const u8,
    is_default: bool,
};

pub fn enumerateDevices(allocator: std.mem.Allocator) ![]AudioDevice {
    _ = allocator;
}

pub const Sound = struct {
    samples: []f32,
    sample_rate: u32,
    channels: u8,
    loop_start: ?usize = null,
    loop_end: ?usize = null,
};

pub const PlayOptions = struct {
    volume: f32 = 1.0,
    loop: bool = false,
};

pub const VoiceHandle = struct {
    id: u32,
    generation: u32,
};

pub const Voice = struct {
    active: bool = false,
    sound: ?Sound = null,
    position: usize = 0, // current index into sound.samples
    volume: f32 = 1.0,
    loop: bool = false,
    paused: bool = false,
    generation: u32 = 0,
};

pub const MAX_VOICES = 64; // fixed cap. tune if it becomes limiting
pub const MAX_RAW_STREAMS = 16;

pub const AudioState = struct {
    voices: [MAX_VOICES]Voice = [_]Voice{.{}} ** MAX_VOICES,
    raw_streams: [MAX_RAW_STREAMS]RawStream = [_]RawStream{.{}} ** MAX_RAW_STREAMS,
    next_generation: u32 = 1,
};

pub const StreamCallback = *const fn (ctx: ?*anyopaque, out: []f32) void;

pub const RawStream = struct {
    active: bool = false,
    callback: ?StreamCallback = null,
    userdata: ?*anyopaque = null,
    volume: f32 = 1.0,
    generation: u32 = 0,
};

pub const StreamHandle = struct {
    id: u32,
    generation: u32,
};

// consider adding voice stealing to prevent crashes or sound overlap
pub fn playSound(backend: *audio.AudioBackend, sound: Sound, opts: PlayOptions) !VoiceHandle {
    for (&backend.state.voices, 0..) |*voice, i| {
        if (!voice.active) {
            const gen = backend.state.next_generation;
            backend.state.next_generation += 1;

            voice.* = .{
                .active = true,
                .sound = sound,
                .position = 0,
                .volume = opts.volume,
                .loop = opts.loop,
                .generation = gen,
            };

            return .{ .id = @intCast(i), .generation = gen };
        }
    }

    return error.NoFreeVoices; // all MAX_VOICES slots are in use
}

// FIXME: ~~consider using lock-free structures instead~~
//        currently we are NOT locking in these functions. This 
//        SHOULD be okay, as mix() is only called in a locked state anyways.
//        Worth investigating.

// NOTE: we could combine stopSound and stopLoop if we accept an enum
//       as an argument in stopSound, with options like .now or .loop
pub fn stopSound(state: *AudioState, handle: VoiceHandle) void {
    const voice = &state.voices[handle.id];
    if (voice.active and voice.generation == handle.generation) {
        voice.active = false;
    }
}
pub fn stopLoop(state: *AudioState, handle: VoiceHandle) void {
    const voice = &state.voices[handle.id];
    if (voice.active and voice.generation == handle.generation) {
        voice.loop = false;
        voice.sound.?.loop_end = null;
    }
}

pub fn setVolume(state: *AudioState, handle: VoiceHandle, volume: f32) void {
    const voice = &state.voices[handle.id];
    if (voice.active and voice.generation == handle.generation) {
        voice.volume = volume;
    }
}

pub fn pauseSound(state: *AudioState, handle: VoiceHandle) void {
    const voice = &state.voices[handle.id];
    if (voice.active and voice.generation == handle.generation) {
        voice.paused = true;
    }
}

pub fn resumeSound(state: *AudioState, handle: VoiceHandle) void {
    const voice = &state.voices[handle.id];
    if (voice.active and voice.generation == handle.generation) {
        voice.paused = false;
    }
}

pub fn createAudioStream(state: *AudioState, opts: PlayOptions, callback: StreamCallback, ctx: ?*anyopaque) !StreamHandle {
    for (&state.raw_streams, 0..) |*stream, i| {
        if (!stream.active) {
            const gen = state.next_generation;
            state.next_generation += 1;
            stream.* = .{
                .active = true,
                .userdata = ctx,
                .callback = callback,
                .volume = opts.volume,
                .generation = gen,
            };

            return .{ .id = @intCast(i), .generation = gen };
        }
    }

    return error.NoFreeStreams;
}

pub fn stopAudioStream(state: *AudioState, handle: StreamHandle) void {
    const stream = &state.raw_streams[handle.id];
    if (stream.active and stream.generation == handle.generation) stream.active = false;
}

pub fn mix(state: *AudioState, out: []f32) void {
    @memset(out, 0);

    for (&state.voices) |*voice| {
        if (!voice.active) continue;
        if (voice.paused) continue;
        const sound = voice.sound.?;

        for (out) |*sample| {
            if (voice.position >= sound.loop_end orelse sound.samples.len) {
                if (voice.loop) {
                    voice.position = sound.loop_start orelse 0;
                } else {
                    voice.active = false;
                    break;
                }
            }
            sample.* += sound.samples[voice.position] * voice.volume;
            voice.position += 1;
        }
    }

    var scratch: [1024]f32 = undefined;
    for (&state.raw_streams) |*stream| {
        if (!stream.active) continue;
        const chunk = scratch[0..out.len];
        stream.callback.?(stream.userdata, chunk);
        for (out, chunk) |*o, s| o.* += s * stream.volume;
    }
    
    for (out) |*sample| {
        sample.* = std.math.clamp(sample.*, -1.0, 1.0);
    }
}

