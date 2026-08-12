# mica

**mica** (Multimedia Interface & Context API) is a cross-platform library for creating and handling window contexts and events, as well as rendering/rasterization.

> [!NOTE]
> mica is in active development. Not all targeted platforms may be functional yet, and not all intended features may be implemented yet.

### Installing to a Project

After initializing a Zig directory (either with `zig init`, `zig init --minimal`, or manually), use

```bash
zig fetch --save "git+https://github.com/jpwol/mica.git"
```

to add the dependency to your `build.zig.zon` file.

In your `build.zig` file,

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    ...

    const mica = b.dependency("mica", .{
        // assuming variables for standard target/optimize options
        .target = target,
        .optimize = optimize,
    });

    const mica_mod = mica.module("mica");

    const exe = b.addExecutable(.{
       ...
       .root_module = b.createModule(.{
            .imports = &.{
                .{
                    .name = "mica",
                    .module = mica_mod,
                },
            },
       }),
    })
}
```

**mica** will then be importable as

```zig
const Mica = @import("mica");
```

#### Basic Usage

After installing **mica** and setting up your build file, mica can be used as follows,

```zig
const std = @import("std");
const Mica = @import("mica");


pub fn main(init: std.process.Init) !void {
    var mica = Mica.init(init.io, init.gpa);

    const window = try mica.createWindow("title", width, height, .{});
    defer mica.destroyWindow(window);

    var sr = try mica.createSoftwareRenderer(win);
    defer mica.destroySoftwareRenderer(win, &sr);

    // you can define colors for reuse
    // or define them inline
    const RED = Mica.Color{ .r = 255, .g = 0, .b = 0 };

    while(!mica.windowShouldClose(win)) {
        // pollEvents polls inline and returns an array of events
        const ev = try mica.pollEvents(win);

        // certain events can be queried inline
        if (mica.isKeyDown(win, .space)) {
            // do something
        }
        if (mica.wasKeyPressed(win, .escape)) mica.close(win);
        if (mica.keyHeldDuration(win, .d)) |d| {
            // do something
        }

        // events can also be viewed in the for loop, which also
        // exposes extra information
        for (events) |e| {
            switch (e) {
                .key_down => |k| {
                    switch (k.key) {
                        .left_ctrl => {
                            if (k.mods.alt) {}
                            if (k.repeat) {}
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        // get a canvas for the SR to paint to
        var canvas = try mica.getCanvas(&sr);

        // clear the rendering target with a color. Colors may be defined in-place or predefined.
        // The alpha value is implicitly 255. It is unneccessary to define the alpha value unless
        // a value other than 255 is desired.
        canvas.clear(.{ .r = 40, .g = 40, .b = 40, .a = 255});

        canvas.fillRect(200, 200, 30, 30, .{ .r = 255, .g = 0, .b = 0 });

        // using a user-defined color
        canvas.setPixel(25, 39, RED);

        mica.present(win, &sr);
    }
}
```

> [!NOTE]
> The implementation of the `Canvas` object and `SoftwareRenderer` are going to change

---

Copyright 2026 Joshua Wolfe

mica is licensed under the Apache License, Version 2.0.
