const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("include/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.linkSystemLibrary("X11", .{});
    translate_c.linkSystemLibrary("Xrandr", .{});
    translate_c.linkSystemLibrary("Xext", .{});

    const mod = b.addModule("mica", .{
        .root_source_file = b.path("src/mica.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{
                .name = "xlib",
                .module = translate_c.createModule(),
            },
        },
    });

    const exe = b.addExecutable(.{
        .name = "",
        .root_module = mod,
        .use_llvm = true,
    });

    b.installArtifact(exe);
}
