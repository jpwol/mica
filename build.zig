const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const translate_c = b.dependency("translate_c", .{});

    const translator: Translator = .init(translate_c, switch(target.result.os.tag) { 
        .linux => .{
            .c_source_file = b.path("include/linux.h"),
            .target = target,
            .optimize = optimize,
            .link_system_libs = &.{
                .{ .name = "X11" },
                .{ .name = "Xrandr" },
                .{ .name = "Xext" },
            }
        },
        .windows => .{
            .c_source_file = b.path("include/windows.h"),
            .target = target,
            .optimize = optimize,
        },
        else => std.process.fatal("mica only supports linux and windows, got {s}", .{@tagName(target.result.os.tag)}),
    });

    const mod = b.addModule("mica", .{
        .root_source_file = b.path("src/mica.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("c", translator.mod);

    if (target.result.os.tag == .linux) {
        mod.linkSystemLibrary("pulse", .{});
    }

    const check_obj = b.addObject(.{
        .name = "mica_check",
        .root_module = mod,
    });

    const check = b.step("check", "Compile mica without linking");
    check.dependOn(&check_obj.step);
}
