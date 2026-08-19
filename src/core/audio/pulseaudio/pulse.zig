const std = @import("std");
const pa = @import("pulseaudio.zig");
const audio = @import("../../audio.zig");

// TODO: Lots to do. 
//       1. Clean up structure from here to the user-facing API.
//       2. Allow user to define format (this will probably be challenging) 
//       2. Allow user defined channels (stereo or mono) instead of hardcoding to 1 (probably set a sane default though)
//       3. Allow user defined sample rate (default to 44.1kHz?)
//       4. Allow user to query information, such as sinks and their names (Backend should own this for the lifetime)
//       5. Allow changing of settings? Destroy and recreate backend probably

pub const AudioBackend = struct {
    mainloop: *pa.pa_threaded_mainloop,
    context: *pa.pa_context,
    stream: *pa.pa_stream,
    state: *audio.AudioState,
};

fn contextStateCallback(context: ?*pa.pa_context, userdata: ?*anyopaque) callconv(.c) void {
    const backend: *AudioBackend = @ptrCast(@alignCast(userdata.?));
    _ = context;
    pa.pa_threaded_mainloop_signal(backend.mainloop, 0);
}

fn streamStateCallback(stream: ?*pa.pa_stream, userdata: ?*anyopaque) callconv(.c) void {
    const backend: *AudioBackend = @ptrCast(@alignCast(userdata.?));
    _ = stream;
    pa.pa_threaded_mainloop_signal(backend.mainloop, 0);
}

fn writeCallback(stream: ?*pa.pa_stream, nbytes: usize, userdata: ?*anyopaque) callconv(.c) void {
    const backend: *AudioBackend = @ptrCast(@alignCast(userdata.?));

    var remaining_bytes = nbytes;
    var buf: [1024]f32 = undefined; // scratch chunk. make bigger if needed

    while (remaining_bytes > 0) {
        const max_chunk_bytes = buf.len * @sizeOf(f32);
        const chunk_bytes = @min(remaining_bytes, max_chunk_bytes);
        const chunk_frames = chunk_bytes / @sizeOf(f32);

        const samples = buf[0..chunk_frames];
        audio.mix(backend.state, samples);
        
        _ = pa.pa_stream_write(stream.?, @ptrCast(&buf), chunk_bytes, null, 0, .PA_SEEK_RELATIVE); // seek=PA_SEEK_RELATIVE(0)
        remaining_bytes -= chunk_bytes;
    }
}

pub fn init(allocator: std.mem.Allocator) !*AudioBackend {
    var backend = try allocator.create(AudioBackend);
    backend.state = try allocator.create(audio.AudioState);

    // backend.state.io = io;
    backend.state.next_generation = 1;
    backend.state.voices = [_]audio.Voice{.{}} ** 64;


    backend.mainloop = pa.pa_threaded_mainloop_new() orelse return error.MainLoopCreateFailed;
    const api = pa.pa_threaded_mainloop_get_api(backend.mainloop) orelse return error.ApiFetchFailed;

    backend.context = pa.pa_context_new(api, "mica") orelse return error.ContextCreateFailed;
    pa.pa_context_set_state_callback(backend.context, contextStateCallback, backend);

    const spec = pa.pa_sample_spec{ .format = .FLOAT32LE, .rate = 44100, .channels = 1 };
    backend.stream = pa.pa_stream_new(backend.context, "mica audio", &spec, null) orelse return error.StreamCreateFailed;
    pa.pa_stream_set_state_callback(backend.stream, streamStateCallback, backend);
    pa.pa_stream_set_write_callback(backend.stream, writeCallback, backend);

    _ = pa.pa_threaded_mainloop_start(backend.mainloop);

    pa.pa_threaded_mainloop_lock(backend.mainloop);

    _ = pa.pa_context_connect(backend.context, null, 0, null);
    while (true) {
        const state_ = pa.pa_context_get_state(backend.context);
        if (state_ == .READY) break;
        if (state_ == .FAILED or state_ == .TERMINATED) {
            pa.pa_threaded_mainloop_unlock(backend.mainloop);
            return error.ContextConnectFailed;
        }
        pa.pa_threaded_mainloop_wait(backend.mainloop);
    }

    const bytes_per_sample = @sizeOf(f32);
    const target_latency_ms = 20;
    // hard coding 44.1kHz, find solution
    const target_bytes: u32 = @intCast((44100 * target_latency_ms / 1000) * bytes_per_sample);
    var attr = pa.pa_buffer_attr{
        .maxlength = std.math.maxInt(u32),
        .tlength = target_bytes,
        .prebuf = 0,
        .minreq = std.math.maxInt(u32),
        .fragsize = std.math.maxInt(u32),
    };

    _ = pa.pa_stream_connect_playback(
        backend.stream,
        null,
        &attr,
        pa.PA_STREAM_ADJUST_LATENCY,
        null,
        null
    );
    while (true) {
        const state_ = pa.pa_stream_get_state(backend.stream);
        if (state_ == .READY) break;
        if (state_ == .FAILED or state_ == .TERMINATED) {
            pa.pa_threaded_mainloop_unlock(backend.mainloop);
            return error.StreamConnectFailed;
        }
        pa.pa_threaded_mainloop_wait(backend.mainloop);
    }

    pa.pa_threaded_mainloop_unlock(backend.mainloop);
    return backend;
}

pub fn deinit(backend: *AudioBackend, allocator: std.mem.Allocator) void {
    pa.pa_threaded_mainloop_lock(backend.mainloop);
    _ = pa.pa_stream_disconnect(backend.stream);
    pa.pa_stream_unref(backend.stream);
    pa.pa_context_disconnect(backend.context);
    pa.pa_context_unref(backend.context);
    pa.pa_threaded_mainloop_unlock(backend.mainloop);

    pa.pa_threaded_mainloop_stop(backend.mainloop);
    pa.pa_threaded_mainloop_free(backend.mainloop);
    allocator.destroy(backend.state);
    allocator.destroy(backend);
}
