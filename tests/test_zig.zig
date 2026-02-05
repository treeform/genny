const std = @import("std");

// Direct extern declarations to test basic FFI
extern fn test_simple_call(a: i64) callconv(.C) i64;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Testing Zig bindings\n", .{});

    try stdout.print("Testing simpleCall\n", .{});
    const result = test_simple_call(42);
    try stdout.print("Result: {d}\n", .{result});

    if (result != 42) {
        try stdout.print("FAIL: expected 42, got {d}\n", .{result});
        return error.TestFailed;
    }

    try stdout.print("All Zig tests passed!\n", .{});
}
