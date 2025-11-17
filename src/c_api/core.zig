const std = @import("std");

pub export fn sayHi() void {
    std.debug.print("Hello!{c}", .{'\n'});
}
