// Zig's translate-c breaks certain long macro chains, especially
// in the context of WIN32.
//
// In that context, certain values depend on obfuscated macros that chain together, 
// eventually going through MinGW.
//
// This file serves as lightweight bindings for the WIN32 API. As issues are encountered,
// this file will grow. Once the Windows implementation is complete, it would be smart
// to transfer all types, structures, and functions that are used to this file. This way,
// a user does not need to translate 100k+ lines of C to Zig, which *severely* slows down zls.


// WinUser.h

pub const IDC_ARROW       : ?[*:0]align(1) const u16 = @ptrFromInt(32512);
pub const IDC_IBEAM       : ?[*:0]align(1) const u16 = @ptrFromInt(32513);
pub const IDC_WAIT        : ?[*:0]align(1) const u16 = @ptrFromInt(32514);
pub const IDC_CROSS       : ?[*:0]align(1) const u16 = @ptrFromInt(32515);
pub const IDC_UPARROW     : ?[*:0]align(1) const u16 = @ptrFromInt(32516);
pub const IDC_SIZE        : ?[*:0]align(1) const u16 = @ptrFromInt(32640);
pub const IDC_ICON        : ?[*:0]align(1) const u16 = @ptrFromInt(32641);
pub const IDC_SIZENWSE    : ?[*:0]align(1) const u16 = @ptrFromInt(32642);
pub const IDC_SIZENESW    : ?[*:0]align(1) const u16 = @ptrFromInt(32643);
pub const IDC_SIZEWE      : ?[*:0]align(1) const u16 = @ptrFromInt(32644);
pub const IDC_SIZENS      : ?[*:0]align(1) const u16 = @ptrFromInt(32645);
pub const IDC_SIZEALL     : ?[*:0]align(1) const u16 = @ptrFromInt(32646);
pub const IDC_NO          : ?[*:0]align(1) const u16 = @ptrFromInt(32648);
pub const IDC_HAND        : ?[*:0]align(1) const u16 = @ptrFromInt(32649);
pub const IDC_APPSTARTING : ?[*:0]align(1) const u16 = @ptrFromInt(32650);
pub const IDC_HELP        : ?[*:0]align(1) const u16 = @ptrFromInt(32651);
