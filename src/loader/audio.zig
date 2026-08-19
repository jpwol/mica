const std = @import("std");

pub const Channel = enum(u16) {
    mono = 1,
    stereo = 2,
};

const WavFormat = enum(u16) {
    PCM = 0x0001,
    IEEE_FLOAT = 0x0003,

    // not parsing these yet. unsure if necessary
    // for this library's application
    ALAW = 0x0006,
    MULAW = 0x0007,
    EXTENSIBLE = 0xFFFE,
};

const ChunkId = enum {
    fmt,
    data,
    unknown,
};

const ChunkHeader = struct {
    chunkId: ChunkId,
    chunkSize: u32,
};

const FmtChunk = struct {
    FormatTag: WavFormat,
    Channel: Channel,
    SamplesPerSec: u32,
    AvgBytesPerSec: u32,
    BlockAlign: u16,
    BitsPerSample: u16,
};

const DataChunk = struct {
    dataChunkSize: usize,
    offset: usize,
};

const DataChunkList = struct {
    chunksFound: u16 = 0,
    chunkData: std.ArrayList(DataChunk) = .empty,
    fmt: FmtChunk = undefined,
    totalSamples: usize = 0,
};

pub const WavSpec = struct {
    format: WavFormat,
    channel: Channel,
    sample_count: usize,
    samples: []f32,
};

// TODO: create an exportWAVFile function that takes a buffer of samples as well as desired channel, sample rate, and
//       target format and encode buffer to a WAV file.

pub fn loadWAVFile(io: std.Io, allocator: std.mem.Allocator, path: []const u8, desired_channel: Channel) !WavSpec {
    const wav = try std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_only });
    defer wav.close(io);

    var buf: [1024]u8 = undefined;
    var rw = wav.reader(io, &buf);
    const reader = &rw.interface;

    var offset: usize = 0;

    if (!try validateWAVEFormat(reader, &offset)) return error.InvalidWAVEHeader;

    var dataChunks: DataChunkList = .{};
    defer dataChunks.chunkData.deinit(allocator);

    var fmtChunk: FmtChunk = undefined;

    while (try readChunkHeader(reader, &offset)) |chunk| {
        switch (chunk.chunkId) {
            .fmt => {
                fmtChunk = try parseFmt(reader, &offset);
            },
            .data => {
                dataChunks.chunksFound += 1;
                try dataChunks.chunkData.append(allocator, .{
                    .dataChunkSize = chunk.chunkSize,
                    .offset = offset,
                });

                try skipChunk(reader, chunk, &offset);
            },
            else => try skipChunk(reader, chunk, &offset),
        }
    }

    dataChunks.fmt = fmtChunk;
    dataChunks.totalSamples = totalNumSamples(dataChunks, fmtChunk);

    const outputSampleCount = blk: {
        if (desired_channel == fmtChunk.Channel) {
            break :blk dataChunks.totalSamples;
        } else if (desired_channel == .mono) {
            break :blk dataChunks.totalSamples / 2;
        } else {
            break :blk dataChunks.totalSamples * 2;
        }
    };

    const out_buf = try allocator.alloc(f32, outputSampleCount);
    errdefer allocator.free(out_buf);

    switch (fmtChunk.FormatTag) {
        .PCM => {
            switch (fmtChunk.BitsPerSample) {
                8 =>  try decodePCM8(&rw, allocator, dataChunks, desired_channel, out_buf),
                16 => try decodePCM16(&rw, allocator, dataChunks, desired_channel, out_buf),
                24 => try decodePCM24(&rw, allocator, dataChunks, desired_channel, out_buf),
                32 => try decodePCM32(&rw, allocator, dataChunks, desired_channel, out_buf),
                else => return error.MalformedBitsPerSample,
            }
        },
        .IEEE_FLOAT => {
            switch (fmtChunk.BitsPerSample) {
                32 => try decodeFloat32(&rw, allocator, dataChunks, desired_channel, out_buf),
                64 => try decodeFloat64(&rw, allocator, dataChunks, desired_channel, out_buf),
                else => return error.MalformedBitsPerSample,
            }
        },
        else => return error.UnsupportedWAVFormat,
    }

    return .{
        .format = fmtChunk.FormatTag,
        .channel = fmtChunk.Channel,
        .sample_count = dataChunks.totalSamples,
        .samples = out_buf,
    };
}

fn decodePCM8(reader: *std.Io.File.Reader, allocator: std.mem.Allocator, data: DataChunkList, desired_channel: Channel, out: []f32) !void {
    const buf = try allocator.alloc(u8, data.totalSamples);
    defer allocator.free(buf);
    var idx: usize = 0;
    for (data.chunkData.items) |i| {
        const n_chunk_samples = i.dataChunkSize / @sizeOf(u8);
        const next_idx = idx + n_chunk_samples;
        try reader.seekTo(i.offset);
        try reader.interface.readSliceAll(std.mem.sliceAsBytes(buf[idx..next_idx]));
        idx = next_idx;
    }

    if (desired_channel == data.fmt.Channel) {
        for (0..out.len) |i| {
            const sample_float: f32 = @floatFromInt(buf[i]);
            const half_u8: u8 = (std.math.maxInt(u8) + 1) / 2;
            out[i] = (sample_float - half_u8) / half_u8;
        }
    } else {
        if (desired_channel == .mono) {
            // desired is mono, source is stereo
            for (0..out.len) |i| {
                const half_u8: u8 = (std.math.maxInt(u8) + 1) / 2;
                const left: f32 = (@as(f32, @floatFromInt(buf[i * 2])) - half_u8) / half_u8;
                const right: f32 = (@as(f32, @floatFromInt(buf[i * 2 + 1])) - half_u8) / half_u8;
                out[i] = (left + right) * 0.5;
            }
        } else {
            // else desired is stereo and actual is mono
            for (0..buf.len) |i| {
                const sample_float: f32 = @floatFromInt(buf[i]);
                const half_u8: u8 = (std.math.maxInt(u8) + 1) / 2;
                const normalized_sample = (sample_float - half_u8) / half_u8;

                out[i * 2] = normalized_sample;
                out[i * 2 + 1] = normalized_sample;
            }
        }
    }
}

fn decodePCM16(reader: *std.Io.File.Reader, allocator: std.mem.Allocator, data: DataChunkList, desired_channel: Channel, out: []f32) !void {
    const buf = try allocator.alloc(i16, data.totalSamples);
    defer allocator.free(buf);
    var idx: usize = 0;
    for (data.chunkData.items) |i| {
        const n_chunk_samples = i.dataChunkSize / @sizeOf(i16);
        const next_idx = idx + n_chunk_samples;
        try reader.seekTo(i.offset);
        try reader.interface.readSliceAll(std.mem.sliceAsBytes(buf[idx..next_idx]));
        idx = next_idx;
    }

    if (desired_channel == data.fmt.Channel) {
        for (0..out.len) |i| {
            const sample_float: f32 = @floatFromInt(buf[i]);
            out[i] = sample_float / (std.math.maxInt(i16) + 1);
        }
    } else {
        if (desired_channel == .mono) {
            // desired is mono, source is stereo
            for (0..out.len) |i| {
                const left: f32 = @floatFromInt(buf[i * 2]);
                const right: f32 = @floatFromInt(buf[i * 2 + 1]);
                out[i] = (left + right) / (std.math.maxInt(i16) + 1);
            }
        } else {
            // else desired is stereo and actual is mono
            for (0..buf.len) |i| {
                const sample_float: f32 = @floatFromInt(buf[i]);
                const normalized_sample: f32 = sample_float / (std.math.maxInt(i16) + 1);

                out[i * 2] = normalized_sample;
                out[i * 2 + 1] = normalized_sample;
            }
        }
    }
}

fn decodePCM24(reader: *std.Io.File.Reader, allocator: std.mem.Allocator, data: DataChunkList, desired_channel: Channel, out: []f32) !void {
    const buf = try allocator.alloc(i32, data.totalSamples);
    defer allocator.free(buf);
    var idx: usize = 0;
    for (data.chunkData.items) |i| {
        try reader.seekTo(i.offset);
        const bytes_per_sample = data.fmt.BitsPerSample / 8;
        const n_chunk_samples = i.dataChunkSize / bytes_per_sample;
        for (0..n_chunk_samples) |j| {
            const b0 = try reader.interface.takeByte();
            const b1 = try reader.interface.takeByte();
            const b2 = try reader.interface.takeByte();
            const tmp: u32 = @as(u32, b0) | (@as(u32, b1) << 8) | (@as(u32, b2) << 16);
            var sample: i32 = @bitCast(tmp << 8);
            sample >>= 8;

            buf[idx + j] = sample;
        }
        const next_idx = idx + n_chunk_samples;
        idx = next_idx;
    }

    if (desired_channel == data.fmt.Channel) {
        for (0..out.len) |i| {
            const sample_float: f32 = @floatFromInt(buf[i]);
            out[i] = sample_float / (std.math.maxInt(i24) + 1);
        }
    } else {
        if (desired_channel == .mono) {
            // desired is mono, source is stereo
            for (0..out.len) |i| {
                const left: f32 = @floatFromInt(buf[i * 2]);
                const right: f32 = @floatFromInt(buf[i * 2 + 1]);
                out[i] = (left + right) / (std.math.maxInt(i24) + 1);
            }
        } else {
            // else desired is stereo and actual is mono
            for (0..buf.len) |i| {
                const sample_float: f32 = @floatFromInt(buf[i]);
                const normalized_sample: f32 = sample_float / (std.math.maxInt(i24) + 1);

                out[i * 2] = normalized_sample;
                out[i * 2 + 1] = normalized_sample;
            }
        }
    }
}

fn decodePCM32(reader: *std.Io.File.Reader, allocator: std.mem.Allocator, data: DataChunkList, desired_channel: Channel, out: []f32) !void {
    const buf = try allocator.alloc(i32, data.totalSamples);
    defer allocator.free(buf);
    var idx: usize = 0;
    for (data.chunkData.items) |i| {
        const n_chunk_samples = i.dataChunkSize / @sizeOf(i32);
        const next_idx = idx + n_chunk_samples;
        try reader.seekTo(i.offset);
        try reader.interface.readSliceAll(std.mem.sliceAsBytes(buf[idx..next_idx]));
        idx = next_idx;
    }

    if (desired_channel == data.fmt.Channel) {
        for (0..out.len) |i| {
            const sample_float: f32 = @floatFromInt(buf[i]);
            out[i] = sample_float / (std.math.maxInt(i32) + 1);
        }
    } else {
        if (desired_channel == .mono) {
            // desired is mono, source is stereo
            for (0..out.len) |i| {
                const left: f32 = @floatFromInt(buf[i * 2]);
                const right: f32 = @floatFromInt(buf[i * 2 + 1]);
                out[i] = (left + right) / (std.math.maxInt(i32) + 1);
            }
        } else {
            // else desired is stereo and actual is mono
            for (0..buf.len) |i| {
                const sample_float: f32 = @floatFromInt(buf[i]);
                const normalized_sample: f32 = sample_float / (std.math.maxInt(i32) + 1);

                out[i * 2] = normalized_sample;
                out[i * 2 + 1] = normalized_sample;
            }
        }
    }
}

fn decodeFloat32(reader: *std.Io.File.Reader, allocator: std.mem.Allocator, data: DataChunkList, desired_channel: Channel, out: []f32) !void {
    const buf = try allocator.alloc(f32, data.totalSamples);
    defer allocator.free(buf);
    var idx: usize = 0;
    for (data.chunkData.items) |i| {
        const n_chunk_samples = i.dataChunkSize / @sizeOf(f32);
        const next_idx = idx + n_chunk_samples;
        try reader.seekTo(i.offset);
        try reader.interface.readSliceAll(std.mem.sliceAsBytes(buf[idx..next_idx]));
        idx = next_idx;
    }

    if (desired_channel == data.fmt.Channel) {
        for (0..out.len) |i| {
            out[i] = buf[i];
        }
    } else {
        if (desired_channel == .mono) {
            // desired is mono, source is stereo
            for (0..out.len) |i| {
                const left: f32 = buf[i * 2];
                const right: f32 = buf[i * 2 + 1];
                out[i] = (left + right) * 0.5;
            }
        } else {
            // else desired is stereo and actual is mono
            for (0..buf.len) |i| {
                out[i * 2] = buf[i];
                out[i * 2 + 1] = buf[i];
            }
        }
    }
}

fn decodeFloat64(reader: *std.Io.File.Reader, allocator: std.mem.Allocator, data: DataChunkList, desired_channel: Channel, out: []f32) !void {
    const buf = try allocator.alloc(f64, data.totalSamples);
    defer allocator.free(buf);
    var idx: usize = 0;
    for (data.chunkData.items) |i| {
        const n_chunk_samples = i.dataChunkSize / @sizeOf(f64);
        const next_idx = idx + n_chunk_samples;
        try reader.seekTo(i.offset);
        try reader.interface.readSliceAll(std.mem.sliceAsBytes(buf[idx..next_idx]));
        idx = next_idx;
    }

    if (desired_channel == data.fmt.Channel) {
        for (0..out.len) |i| {
            out[i] = @floatCast(buf[i]);
        }
    } else {
        if (desired_channel == .mono) {
            // desired is mono, source is stereo
            for (0..out.len) |i| {
                const left = buf[i * 2];
                const right = buf[i * 2 + 1];
                out[i] = @floatCast((left + right) * 0.5);
            }
        } else {
            // else desired is stereo and actual is mono
            for (0..buf.len) |i| {
                out[i * 2] = @floatCast(buf[i]);
                out[i * 2 + 1] = @floatCast(buf[i]);
            }
        }
    }
}

/// Simply validates that the top-level chunk identifies the file as
/// a RIFF file with WAVE format. 
/// 
/// Returns `true` if this check succeeds, `false` if it fails
fn validateWAVEFormat(reader: *std.Io.Reader, offset: *usize) !bool {
    const riff_id = try reader.take(4);
    _ = try reader.takeInt(u32, .little);
    const wave_id = try reader.take(4);

    offset.* += 12;

    if (!std.mem.eql(u8, riff_id, "RIFF")) return false;
    if (!std.mem.eql(u8, wave_id, "WAVE")) return false;

    return true;
}

/// Parses the "fmt " chunk. This chunk contains important information
/// necessary for converting the WAV file into streamable data.
fn parseFmt(reader: *std.Io.Reader, offset: *usize) !FmtChunk {
    // zig fmt: off
    const format_tag         = try reader.takeInt(u16, .little);
    const nchannels          = try reader.takeInt(u16, .little);
    const nsamples_per_sec   = try reader.takeInt(u32, .little);
    const navg_bytes_per_sec = try reader.takeInt(u32, .little);
    const nblock_align       = try reader.takeInt(u16, .little);
    const wbits_per_sample   = try reader.takeInt(u16, .little);
    // zig fmt: on

    offset.* += 16;

    return .{
        .FormatTag = @enumFromInt(format_tag),
        .Channel = @enumFromInt(nchannels),
        .SamplesPerSec = nsamples_per_sec,
        .AvgBytesPerSec = navg_bytes_per_sec,
        .BlockAlign = nblock_align,
        .BitsPerSample = wbits_per_sample,
    };
}

/// Skips a chunk. This is useful for any chunk that is meaningless for the parsing
/// purpose, for example JUNK chunk is always skipped. This parser skips all chunks
/// but fmt  and data.
fn skipChunk(reader: *std.Io.Reader, chunk: ChunkHeader, offset: *usize) !void {
    _ = try reader.discard(.limited(chunk.chunkSize));
    offset.* += chunk.chunkSize;
}

/// Reads the Chunk ID and Chunk Size (bytes) for any given sub-chunk.
///
/// To recognize more sub-chunk types, add them to the ChunkId Enum and
/// compare against them in the if-else block below
fn readChunkHeader(reader: *std.Io.Reader, offset: *usize) !?ChunkHeader {
    const chunk_id = reader.take(4) catch |err| {
        if (err == error.EndOfStream) return null else return err;
    };

    const chunk_size = try reader.takeInt(u32, .little);

    offset.* += 8;

    return .{
        .chunkId = blk: {
            if (std.mem.eql(u8, chunk_id, "fmt ")) {
                break :blk .fmt;
            } else if (std.mem.eql(u8, chunk_id, "data")) {
                break :blk .data;
            } else {
                break :blk .unknown;
            }
        },
        .chunkSize = chunk_size,
    };
}

/// Gets the total samples in the file. This is different from total
/// frames, as frames are samples / channels.
fn totalNumSamples(data: DataChunkList, fmt: FmtChunk) usize {
    var total_bytes: usize = 0;
    for (data.chunkData.items) |i| {
        total_bytes += i.dataChunkSize;
    }

    return total_bytes / (fmt.BitsPerSample / 8);
}

/// Gets the total number of frames in the file. A frame is made up of
/// one sample per channel. 
/// For mono channel, this means
///     `total frames == total samples`
/// But for stereo,
///     `total frames == 0.5 * total samples`
fn totalNumFrames(data: DataChunkList, fmt: FmtChunk) usize {
    var total_bytes: usize = 0;
    for (data.chunkData.items) |i| {
        total_bytes += i.dataChunkSize;
    }

    return total_bytes / (fmt.BitsPerSample / fmt.BlockAlign);
}
