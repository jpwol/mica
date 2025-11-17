const std = @import("std");

pub fn build(b: *std.Build) void {
    const lib_mod = b.addModule("mica", .{
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
    });
    _ = lib_mod;
}
