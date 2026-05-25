const std = @import("std");
const test_lib = @import("generated/test.zig");

pub fn main() !void {
    std.debug.print("Testing Zig bindings\n", .{});

    std.debug.print("Testing simpleCall\n", .{});
    const result = test_lib.simpleCall(42);
    std.debug.print("Result: {d}\n", .{result});

    if (result != 42) {
        std.debug.print("FAIL: expected 42, got {d}\n", .{result});
        return error.TestFailed;
    }

    std.debug.print("Testing SimpleObj\n", .{});
    const obj = test_lib.SimpleObj.init(10, 20, true);
    if (obj.simple_a != 10) return error.TestFailed;
    if (obj.simple_b != 20) return error.TestFailed;
    if (obj.simple_c != true) return error.TestFailed;

    std.debug.print("All Zig tests passed!\n", .{});
}
