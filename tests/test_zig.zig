const std = @import("std");
const test_lib = @import("generated/test.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Testing Zig bindings\n", .{});

    try stdout.print("Testing simpleCall\n", .{});
    const result = test_lib.simpleCall(42);
    try stdout.print("Result: {d}\n", .{result});

    if (result != 42) {
        try stdout.print("FAIL: expected 42, got {d}\n", .{result});
        return error.TestFailed;
    }

    try stdout.print("Testing SimpleObj\n", .{});
    const obj = test_lib.SimpleObj.init(10, 20, true);
    if (obj.simple_a != 10) return error.TestFailed;
    if (obj.simple_b != 20) return error.TestFailed;
    if (obj.simple_c != true) return error.TestFailed;

    try stdout.print("All Zig tests passed!\n", .{});
}
