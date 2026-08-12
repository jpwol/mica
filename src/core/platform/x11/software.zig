const std = @import("std");
const xlib = @import("c");
const sys = std.os.linux;

const Canvas = @import("../../../render/software.zig");
const Window = @import("window.zig").Window;

const IPC_PRIVATE = 0;
const IPC_CREAT = 0o1000;
const IPC_EXCL = 0o2000;
const IPC_RMID = 0;

pub const SoftwareRenderer = struct {
    use_shm: bool,
    shm_info: *xlib.XShmSegmentInfo,
    ximage: *xlib.XImage,
    buffer: []u8,
    gc: xlib.GC,
    width: u32,
    height: u32,
    win: *Window,
};

pub fn createSoftwareRenderer(allocator: std.mem.Allocator, win: *Window) !SoftwareRenderer {
    // const shm_available = xlib.XShmQueryExtension(win.display) != 0;
    const shm_available = false;

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

    const shm_info = try allocator.create(xlib.XShmSegmentInfo);
    errdefer allocator.destroy(shm_info);

    var ximage: *xlib.XImage = undefined;

    errdefer {
        _ = xlib.XShmDetach(win.display, shm_info);

        ximage.*.data = null;
        _ = ximage.*.f.destroy_image.?(ximage);

        _ = sys.syscall1(
            .shmdt,
            @intFromPtr(shm_info.*.shmaddr),
        );

        _ = sys.syscall3(
            .shmctl,
            @intCast(shm_info.*.shmid),
            IPC_RMID,
            0,
        );
    }

    ximage = xlib.XShmCreateImage(
        win.display, 
        visual, 
        @intCast(depth),
        xlib.ZPixmap, 
        null,
        &shm_info.*,
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

    shm_info.*.shmid = shmid;
    shm_info.*.shmaddr = @ptrCast(shmaddr);
    shm_info.*.readOnly = xlib.False;

    ximage.*.data = @ptrCast(shmaddr);

    if (xlib.XShmAttach(win.display, &shm_info.*) == 0) {
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
        .shm_info = shm_info,
        .buffer = &.{},
        .ximage = ximage,
    };
}

fn presentShm(win: *Window, renderer: *SoftwareRenderer) void {
    _ = xlib.XShmPutImage(
        win.display, 
        win.window,
        renderer.gc,
        renderer.ximage,
        0, 0,
        0, 0,
        renderer.width,
        renderer.height,
        xlib.False
        );
}


fn destroyShm(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) void {
    _ = xlib.XShmDetach(
        win.display,
        &renderer.shm_info.*,
    );

    _ = xlib.XSync(win.display, xlib.False);

    renderer.ximage.*.data = null;
    _ = renderer.ximage.*.f.destroy_image.?(renderer.ximage);
    _ = sys.syscall1(.shmdt, @intFromPtr(renderer.shm_info.*.shmaddr));
    _ = sys.syscall3(.shmctl, @intCast(renderer.shm_info.*.shmid), IPC_RMID, 0);
    allocator.destroy(renderer.shm_info);
    _ = xlib.XFreeGC(win.display, renderer.gc);
}

// #------------------------ NON-SHM FUNCTIONS --------------------------#

fn createPlainRenderer(allocator: std.mem.Allocator, win: *Window) !SoftwareRenderer {
    const width = win.width;
    const height = win.height;
    const bytes_per_pixel = 4;

    var buffer: []u8 = undefined;
    var ximage: *xlib.XImage = undefined;

    const visual = xlib.DefaultVisual(win.display, win.screen);
    const depth = xlib.DefaultDepth(win.display, win.screen);

    errdefer {
        ximage.*.data = null;
        _ = ximage.*.f.destroy_image.?(ximage);
        allocator.free(buffer);
    }

    buffer = try allocator.alloc(u8, width * height * bytes_per_pixel);

    ximage = xlib.XCreateImage(
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


    const gc = xlib.XCreateGC(win.display, win.window, 0, null);

    return .{
        .use_shm = false,
        .win = win,
        .gc = gc,
        .width = width,
        .height = height,
        .shm_info = undefined,
        .buffer = buffer,
        .ximage = ximage,
    };
}

fn presentPlain(win: *Window, renderer: *SoftwareRenderer) void {
    _ = xlib.XPutImage(
        win.display, 
        win.window, 
        renderer.gc, 
        renderer.ximage, 
        0, 0, 
        0, 0, 
        renderer.width, 
        renderer.height,
    );
}

fn destroyPlain(allocator: std.mem.Allocator, win: *Window, renderer: *SoftwareRenderer) void {
    renderer.ximage.*.data = null;
    _ = renderer.ximage.*.f.destroy_image.?(renderer.ximage);
    allocator.free(renderer.buffer);
    _ = xlib.XFreeGC(win.display, renderer.gc);
}

// #--------------------- Public Functions (shared) --------------------#

pub fn getCanvas(allocator: std.mem.Allocator, renderer: *SoftwareRenderer) !Canvas {
    if (renderer.width != renderer.win.width or renderer.height != renderer.win.height) {
        try resize(allocator, renderer.win, renderer);
    }
    const pixels = if (renderer.use_shm)
        @as([*]u8, @ptrCast(renderer.ximage.*.data.?))[0 .. renderer.width * renderer.height * 4]
    else
        renderer.buffer;

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
