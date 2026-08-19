
// FIXME: consider actually defining these structs
pub const pa_mainloop_api = opaque {};
pub const pa_threaded_mainloop = opaque {};
pub const pa_context = opaque {};
pub const pa_stream = opaque {};
pub const pa_sample_spec = extern struct {
    format: pa_sample_format,
    rate: u32,
    channels: u8,
};

pub const PA_STREAM_ADJUST_LATENCY: c_int = 0x2000;

pub const pa_buffer_attr = extern struct {
    /// Maximum length of the buffer in bytes. Setting this to (uint32_t) -1
    /// will initialize this to the maximum value supported by server,
    /// which is recommended.
    ///
    /// In strict low-latency playback scenarios you might want to set this to
    /// a lower value, likely together with the PA_STREAM_ADJUST_LATENCY flag.
    /// If you do so, you ensure that the latency doesn't grow beyond what is
    /// acceptable for the use case, at the cost of getting more underruns if
    /// the latency is lower than what the server can reliably handle.
    maxlength: u32,

    /// Playback only: target length of the buffer. The server tries
    /// to assure that at least tlength bytes are always available in
    /// the per-stream server-side playback buffer. The server will
    /// only send requests for more data as long as the buffer has
    /// less than this number of bytes of data.
    ///
    /// It is recommended to set this to (uint32_t) -1, which will
    /// initialize this to a value that is deemed sensible by the
    /// server. However, this value will default to something like 2s;
    /// for applications that have specific latency requirements
    /// this value should be set to the maximum latency that the
    /// application can deal with.
    ///
    /// When PA_STREAM_ADJUST_LATENCY is not set this value will
    /// influence only the per-stream playback buffer size. When
    /// PA_STREAM_ADJUST_LATENCY is set the overall latency of the sink
    /// plus the playback buffer size is configured to this value. Set
    /// PA_STREAM_ADJUST_LATENCY if you are interested in adjusting the
    /// overall latency. Don't set it if you are interested in
    /// configuring the server-side per-stream playback buffer
    /// size.
    tlength: u32,

    /// Playback only: pre-buffering. The server does not start with
    /// playback before at least prebuf bytes are available in the
    /// buffer. It is recommended to set this to (uint32_t) -1, which
    /// will initialize this to the same value as tlength, whatever
    /// that may be.
    ///
    /// Initialize to 0 to enable manual start/stop control of the stream.
    /// This means that playback will not stop on underrun and playback
    /// will not start automatically, instead pa_stream_cork() needs to
    /// be called explicitly. If you set this value to 0 you should also
    /// set PA_STREAM_START_CORKED. Should underrun occur, the read index
    /// of the output buffer overtakes the write index, and hence the
    /// fill level of the buffer is negative.
    ///
    /// Start of playback can be forced using pa_stream_trigger() even
    /// though the prebuffer size hasn't been reached. If a buffer
    /// underrun occurs, this prebuffering will be again enabled.
    prebuf: u32,

    /// Playback only: minimum request. The server does not request
    /// less than minreq bytes from the client, instead waits until the
    /// buffer is free enough to request more bytes at once. It is
    /// recommended to set this to (uint32_t) -1, which will initialize
    /// this to a value that is deemed sensible by the server. This
    /// should be set to a value that gives PulseAudio enough time to
    /// move the data from the per-stream playback buffer into the
    /// hardware playback buffer.
    minreq: u32,

    /// Recording only: fragment size. The server sends data in
    /// blocks of fragsize bytes size. Large values diminish
    /// interactivity with other operations on the connection context
    /// but decrease control overhead. It is recommended to set this to
    /// (uint32_t) -1, which will initialize this to a value that is
    /// deemed sensible by the server. However, this value will default
    /// to something like 2s; For applications that have specific
    /// latency requirements this value should be set to the maximum
    /// latency that the application can deal with.
    ///
    /// If PA_STREAM_ADJUST_LATENCY is set the overall source latency
    /// will be adjusted according to this value. If it is not set the
    /// source latency is left unmodified.
    fragsize: u32,

};

pub const pa_context_state = enum(c_int) {
    UNCONNECTED = 0,
    CONNECTING = 1,
    AUTHORIZING = 2,
    SETTING_NAME = 3,
    READY = 4,
    FAILED = 5,
    TERMINATED = 6,
};

pub const pa_stream_state = enum(c_int) {
    UNCONNECTED = 0,
    CREATING = 1,
    READY = 2,
    FAILED = 3,
    TERMINATED = 4
};

pub const pa_sample_format = enum(c_int) {
    /// Unsigned 8 Bit PCM
    U8,

    /// 8 Bit a-Law
    ALAW,

    /// 8 Bit mu-Law
    ULAW,

    /// Signed 16 Bit PCM, little endian (PC)
    S16LE,

    /// Signed 16 Bit PCM, big endian
    S16BE,

    /// 32 Bit IEEE floating point, little endian (PC), range -1.0 to 1.0
    FLOAT32LE,

    /// 32 Bit IEEE floating point, big endian, range -1.0 to 1.0
    FLOAT32BE,

    /// Signed 32 Bit PCM, little endian (PC)
    S32LE,

    /// Signed 32 Bit PCM, big endian
    S32BE,

    /// Signed 24 Bit PCM packed, little endian (PC). \since 0.9.15
    S24LE,

    /// Signed 24 Bit PCM packed, big endian. \since 0.9.15
    S24BE,

    /// Signed 24 Bit PCM in LSB of 32 Bit words, little endian (PC). \since 0.9.15
    S24_32LE,

    /// Signed 24 Bit PCM in LSB of 32 Bit words, big endian. \since 0.9.15
    S24_32BE,

    /// Upper limit of valid sample types
    MAX,

    /// An invalid value
    INVALID = -1
};

pub const pa_seek_mode = enum(c_int){
    /// Seek relative to the write index. */
    PA_SEEK_RELATIVE = 0,

    /// Seek relative to the start of the buffer queue. */
    PA_SEEK_ABSOLUTE = 1,

    /// Seek relative to the read index. */
    PA_SEEK_RELATIVE_ON_READ = 2,

    /// Seek relative to the current end of the buffer queue. */
    PA_SEEK_RELATIVE_END = 3
};

pub const pa_sink_flags = enum(c_uint){
    /// Flag to pass when no specific options are needed (used to avoid casting)  \since 0.9.19 */
    PA_SINK_NOFLAGS = 0x0000,

    /// Supports hardware volume control. This is a dynamic flag and may
    /// change at runtime after the sink has initialized */
    PA_SINK_HW_VOLUME_CTRL = 0x0001,

    /// Supports latency querying */
    PA_SINK_LATENCY = 0x0002,

    /// Is a hardware sink of some kind, in contrast to
    /// "virtual"/software sinks \since 0.9.3 */
    PA_SINK_HARDWARE = 0x0004,

    /// Is a networked sink of some kind. \since 0.9.7 */
    PA_SINK_NETWORK = 0x0008,

    /// Supports hardware mute control. This is a dynamic flag and may
    /// change at runtime after the sink has initialized \since 0.9.11 */
    PA_SINK_HW_MUTE_CTRL = 0x0010,

    /// Volume can be translated to dB with pa_sw_volume_to_dB(). This is a
    /// dynamic flag and may change at runtime after the sink has initialized
    /// \since 0.9.11 */
    PA_SINK_DECIBEL_VOLUME = 0x0020,

    /// This sink is in flat volume mode, i.e.\ always the maximum of
    /// the volume of all connected inputs. \since 0.9.15 */
    PA_SINK_FLAT_VOLUME = 0x0040,

    /// The latency can be adjusted dynamically depending on the
    /// needs of the connected streams. \since 0.9.15 */
    PA_SINK_DYNAMIC_LATENCY = 0x0080,

    /// The sink allows setting what formats are supported by the connected
    /// hardware. The actual functionality to do this might be provided by an
    /// extension. \since 1.0 */
    PA_SINK_SET_FORMATS = 0x0100,
};

pub extern "pulse" fn pa_threaded_mainloop_new() callconv(.c) ?*pa_threaded_mainloop;
pub extern "pulse" fn pa_threaded_mainloop_start(m: *pa_threaded_mainloop) callconv(.c) c_int;
pub extern "pulse" fn pa_threaded_mainloop_stop(m: *pa_threaded_mainloop) callconv(.c) void;
pub extern "pulse" fn pa_threaded_mainloop_free(m: *pa_threaded_mainloop) callconv(.c) void;
pub extern "pulse" fn pa_threaded_mainloop_lock(m: *pa_threaded_mainloop) callconv(.c) void;
pub extern "pulse" fn pa_threaded_mainloop_unlock(m: *pa_threaded_mainloop) callconv(.c) void;
pub extern "pulse" fn pa_threaded_mainloop_wait(m: *pa_threaded_mainloop) callconv(.c) void;
pub extern "pulse" fn pa_threaded_mainloop_signal(m: *pa_threaded_mainloop, wait_for_accept: c_int) callconv(.c) void;
pub extern "pulse" fn pa_threaded_mainloop_get_api(m: *pa_threaded_mainloop) callconv(.c) ?*pa_mainloop_api;

pub extern "pulse" fn pa_context_new(api: *pa_mainloop_api, name: [*:0]const u8) callconv(.c) ?*pa_context;
pub extern "pulse" fn pa_context_connect(c: *pa_context, server: ?[*:0]const u8, flags: c_int, api: ?*anyopaque) callconv(.c) c_int;
pub extern "pulse" fn pa_context_get_state(c: *pa_context) callconv(.c) pa_context_state;
pub extern "pulse" fn pa_context_set_state_callback(c: *pa_context, cb: *const fn (c: ?*pa_context, userdata: ?*anyopaque) callconv(.c) void, userdata: ?*anyopaque) callconv(.c) void;
pub extern "pulse" fn pa_context_disconnect(c: *pa_context) callconv(.c) void;
pub extern "pulse" fn pa_context_unref(c: *pa_context) callconv(.c) void;

pub extern "pulse" fn pa_stream_new(c: *pa_context, name: [*:0]const u8, ss: *const pa_sample_spec, map: ?*anyopaque) callconv(.c) ?*pa_stream;
pub extern "pulse" fn pa_stream_connect_playback(s: *pa_stream, dev: ?[*:0]const u8, attr: ?*pa_buffer_attr, flags: c_int, volume: ?*anyopaque, sync_stream: ?*pa_stream) callconv(.c) c_int;
pub extern "pulse" fn pa_stream_get_state(s: *pa_stream) callconv(.c) pa_stream_state;
pub extern "pulse" fn pa_stream_set_state_callback(s: *pa_stream, cb: *const fn (s: ?*pa_stream, userdata: ?*anyopaque) callconv(.c) void, userdata: ?*anyopaque) callconv(.c) void;
pub extern "pulse" fn pa_stream_set_write_callback(s: *pa_stream, cb: *const fn (s: ?*pa_stream, nbytes: usize, userdata: ?*anyopaque) callconv(.c) void, userdata: ?*anyopaque) callconv(.c) void;
pub extern "pulse" fn pa_stream_writable_size(s: *pa_stream) callconv(.c) usize;
pub extern "pulse" fn pa_stream_write(s: *pa_stream, data: [*]const u8, nbytes: usize, free_cb: ?*anyopaque, offset: i64, seek: pa_seek_mode) callconv(.c) c_int;
pub extern "pulse" fn pa_stream_disconnect(s: *pa_stream) callconv(.c) c_int;
pub extern "pulse" fn pa_stream_unref(s: *pa_stream) callconv(.c) void;
