const std = @import("std");
const xlib = @import("xlib");
const sys = std.os.linux;

const Canvas = @import("../../../render/software.zig");
const window_mod = @import("window.zig");
const Window = window_mod.Window;

const IPC_PRIVATE = 0;
const IPC_CREAT = 0o1000;
const IPC_EXCL = 0o2000;
const IPC_RMID = 0;

pub const SoftwareRenderer = struct {
    use_shm: bool,
    shm_infos: *[2]xlib.XShmSegmentInfo,
    ximages: [2]*xlib.XImage,
    buffers: [2][]u8,
    front: u1,
    gc: xlib.GC,
    width: u32,
    height: u32,
    win: *Window,
};

pub fn createSoftwareRenderer(allocator: std.mem.Allocator, win: *Window) !SoftwareRenderer {
    const shm_available = xlib.XShmQueryExtension(win.display) != 0;
    // const shm_available = false;

    if (shm_available) {
        return try createShmRenderer(allocator, win);
    } else {
        return try createPlainRenderer(allocator, win);
    }

}

// #--------------------- SHM FUNCTIONS -----------------------#

fn createShmRenderer(allocator: std.mem.Allocator, win: *Window) !SoftwareRenderer {
    const width = win.width;
    const height = win.height;

    const visual = xlib.DefaultVisual(win.display, win.screen);
    const depth = xlib.DefaultDepth(win.display, win.screen);

    const shm_infos = try allocator.create([2]xlib.XShmSegmentInfo);
    shm_infos.* = undefined;
    errdefer allocator.destroy(shm_infos);

    var ximages: [2]*xlib.XImage = undefined;

    var i: usize = 0;
    errdefer {
        var j: usize = 0;
        while (j < i) : (j += 1) {
            _ = xlib.XShmDetach(win.display, &shm_infos.*[j]);

            ximages[j].*.data = null;
            _ = ximages[j].*.f.destroy_image.?(ximages[j]);

            _ = sys.syscall1(
                .shmdt,
                @intFromPtr(shm_infos.*[j].shmaddr),
            );

            _ = sys.syscall3(
                .shmctl,
                @intCast(shm_infos.*[j].shmid),
                IPC_RMID,
                0,
            );
        }
    }

    while (i < 2) : (i += 1) {
        const ximage = xlib.XShmCreateImage(
            win.display, 
            visual, 
            @intCast(depth),
            xlib.ZPixmap, 
            null,
            &shm_infos.*[i],
            width, 
            height,
        ) orelse return error.XShmCreateImageFailed;


        const size = 
            @as(usize, @intCast(ximage.*.bytes_per_line)) *
            @as(usize, @intCast(ximage.*.height));

        const shmid_raw = sys.syscall3(
            .shmget,
            IPC_PRIVATE,
            size,
            IPC_CREAT | 0o600
        );

        if (sys.errno(shmid_raw) != .SUCCESS){
            ximage.*.data = null;
            _ = ximage.*.f.destroy_image.?(ximage);
            return error.ShmGetFailed;
        }
        const shmid: i32 = @intCast(shmid_raw);

        const shmaddr_raw = sys.syscall3(
            .shmat,
            @intCast(shmid),
            0,
            0
        );

        if (sys.errno(shmaddr_raw) != .SUCCESS) {
            _ = sys.syscall3(
                .shmctl,
                @intCast(shmid),
                IPC_RMID,
                0,
            );

            ximage.*.data = null;
            _ = ximage.*.f.destroy_image.?(ximage);

            return error.ShmAttachFailed;
        }
        const shmaddr: *anyopaque = @ptrFromInt(shmaddr_raw);

        shm_infos.*[i].shmid = shmid;
        shm_infos.*[i].shmaddr = @ptrCast(shmaddr);
        shm_infos.*[i].readOnly = xlib.False;

        ximage.*.data = @ptrCast(shmaddr);

        if (xlib.XShmAttach(win.display, &shm_infos.*[i]) == 0) {
            ximage.*.data = null;
            _ = ximage.*.f.destroy_image.?(ximage);

            _ = sys.syscall1(
                .shmdt, 
                shmaddr_raw,
            );

            _ = sys.syscall3(
                .shmctl, 
                @intCast(shmid), 
                IPC_RMID, 
                0,
            );

            return error.XShmAttachFailed;
        }


        ximages[i] = ximage;
    }

    const gc = xlib.XCreateGC(
        win.display,
        win.window, 
        0, 
        null
    );


    return .{
        .use_shm = true,
        .win = win,
        .gc = gc,
        .width = width,
        .height = height,
        .front = 0,
        .shm_infos = shm_infos,
        .buffers = undefined,
        .ximages = ximages,
    };
}

fn presentShm(win: *Window, renderer: *SoftwareRenderer) void {
    // const back = 1 - renderer.front;
    const back = 0;
    _ = xlib.XShmPutImage(
        win.display, 
        win.window,
        renderer.gc,
        renderer.ximages[0],
        0, 0,
        0, 0,
        renderer.width,
        renderer.height,
        xlib.False
        );
    renderer.front = back;
}


fn destroyShm(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) void {
    var i: usize = 0;
    while (i < 2) : (i += 1) {
        _ = xlib.XShmDetach(
            win.display,
            &renderer.shm_infos.*[i]
        );
    }
    // _ = xlib.XSync(win.display, xlib.False);

    i = 0;
    while (i < 2) : (i += 1) {
        renderer.ximages[i].*.data = null;
        _ = renderer.ximages[i].*.f.destroy_image.?(renderer.ximages[i]);
        _ = sys.syscall1(.shmdt, @intFromPtr(renderer.shm_infos.*[i].shmaddr));
        _ = sys.syscall3(.shmctl, @intCast(renderer.shm_infos.*[i].shmid), IPC_RMID, 0);
    }
    allocator.destroy(renderer.shm_infos);
    _ = xlib.XFreeGC(win.display, renderer.gc);
}

// #------------------------ NON-SHM FUNCTIONS --------------------------#

fn createPlainRenderer(allocator: std.mem.Allocator, win: *Window) !SoftwareRenderer {
    const width = win.width;
    const height = win.height;
    const bytes_per_pixel = 4;

    var buffers: [2][]u8 = undefined;
    var ximages: [2]*xlib.XImage = undefined;

    const visual = xlib.DefaultVisual(win.display, win.screen);
    const depth = xlib.DefaultDepth(win.display, win.screen);

    var i: usize = 0;
    errdefer {
        var j: usize = 0;
        while (j < i) : (j += 1) {
            ximages[j].*.data = null;
            _ = ximages[j].*.f.destroy_image.?(ximages[j]);
            allocator.free(buffers[j]);
        }
    }
    while (i < 2) : (i += 1) {
        const buffer = try allocator.alloc(u8, width * height * bytes_per_pixel);
        buffers[i] = buffer;

        const ximage = xlib.XCreateImage(
            win.display, 
            visual, 
            @intCast(depth), 
            xlib.ZPixmap, 
            0, 
            @ptrCast(buffer.ptr), 
            width, 
            height, 
            32, 
            @intCast(width * bytes_per_pixel),
        ) orelse return error.XCreateImageFailed;
        ximages[i] = ximage;
    }


    const gc = xlib.XCreateGC(win.display, win.window, 0, null);

    return .{
        .use_shm = false,
        .win = win,
        .gc = gc,
        .width = width,
        .height = height,
        .front = 0,
        .shm_infos = undefined,
        .buffers = buffers,
        .ximages = ximages,
    };
}

fn presentPlain(win: *Window, renderer: *SoftwareRenderer) void {
    // const back = 1 - renderer.front;
    const back = 0;
    _ = xlib.XPutImage(
        win.display, 
        win.window, 
        renderer.gc, 
        renderer.ximages[0], 
        0, 0, 
        0, 0, 
        renderer.width, 
        renderer.height,
    );
    renderer.front = back;
}

fn destroyPlain(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) void {
    var i: usize = 0;
    while (i < 2) : (i += 1) {
        renderer.ximages[i].*.data = null;
        _ = renderer.ximages[i].*.f.destroy_image.?(renderer.ximages[i]);
        allocator.free(renderer.buffers[i]);
    }
    _ = xlib.XFreeGC(win.display, renderer.gc);
}

// #--------------------- Public Functions (shared) --------------------#

pub fn getCanvas(allocator: std.mem.Allocator, renderer: *SoftwareRenderer) !Canvas {
    if (renderer.width != renderer.win.width or renderer.height != renderer.win.height) {
        try resize(allocator, renderer.win, renderer);
    }
    // const back = 1 - renderer.front;
    // const back = 0;
    const pixels = if (renderer.use_shm)
        @as([*]u8, @ptrCast(renderer.ximages[0].*.data.?))[0 .. renderer.width * renderer.height * 4]
    else
        renderer.buffers[0];

    return .{
        .pixels = pixels,
        .width = renderer.width,
        .height = renderer.height,
        .stride = renderer.width * 4,
    };
}


pub fn present(win: *Window, renderer: *SoftwareRenderer) void {
    if (renderer.use_shm) presentShm(win, renderer) else presentPlain(win, renderer);
}

pub fn resize(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) !void {
    if (renderer.use_shm) {
        destroyShm(allocator, win, renderer);
        renderer.* = try createShmRenderer(allocator, win);
    } else {
        destroyPlain(allocator, win, renderer);
        renderer.* = try createPlainRenderer(allocator, win);
    }
    renderer.win = win;
}

pub fn destroy(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) void {
    if (renderer.use_shm) destroyShm(allocator, win, renderer) else destroyPlain(allocator, win, renderer);
}
