const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = switch(builtin.os.tag) {
        .linux => b.addTranslateC(.{
            .root_source_file = b.path("include/linux.h"),
            .target = target,
            .optimize = optimize,
        }),
        .windows => null,
        // .windows => b.addTranslateC(.{
        //     .root_source_file = b.path("include/windows.h"),
        //     .target = target,
        //     .optimize = optimize,
        // }),
        else => @compileError("mica: unsupported platform"),
    };

    switch (builtin.os.tag) {
        .linux => {
            translate_c.linkSystemLibrary("X11", .{});
            translate_c.linkSystemLibrary("Xrandr", .{});
            translate_c.linkSystemLibrary("Xext", .{});
        },
        .windows => {
        },
        else => @compileError("mica: unsupported platform"),
    }

    const mod = b.addModule("mica", .{
        .root_source_file = b.path("src/mica.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    if (builtin.os.tag == .linux) {
        mod.addImport("c", translate_c.createModule());
    }

    // mod.linkSystemLibrary("user32", .{});
    // mod.linkSystemLibrary("kernel32", .{});
    //
    // const exe = b.addExecutable(.{
    //     .name = "",
    //     .root_module = mod,
    //     .use_llvm = true,
    // });

    // b.installArtifact(exe);
}
