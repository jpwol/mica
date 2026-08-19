const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var translate_c: ?*std.Build.Step.TranslateC = null;

    switch(target.result.os.tag) {
        .linux => {
            translate_c = b.addTranslateC(.{
                .root_source_file = b.path("include/linux.h"),
                .target = target,
                .optimize = optimize,
            });

            translate_c.?.linkSystemLibrary("X11", .{});
            translate_c.?.linkSystemLibrary("Xrandr", .{});
            translate_c.?.linkSystemLibrary("Xext", .{});
        },
        else => {},
    }

    const mod = b.addModule("mica", .{
        .root_source_file = b.path("src/mica.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });


    if (target.result.os.tag == .linux) {
        mod.addImport("c", translate_c.?.addModule("c"));
        mod.linkSystemLibrary("pulse", .{});
    }

    // mod.linkSystemLibrary("user32", .{});
    // mod.linkSystemLibrary("kernel32", .{});
}
