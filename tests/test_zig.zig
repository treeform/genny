const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Testing Zig bindings\n", .{});

    // Load the library explicitly at runtime
    var lib = std.DynLib.open("generated/libtest.so") catch |err| {
        try stdout.print("Failed to open library: {}\n", .{err});
        return err;
    };
    defer lib.close();

    // Look up the function
    const test_simple_call = lib.lookup(*const fn (i64) callconv(.C) i64, "test_simple_call") orelse {
        try stdout.print("Failed to find symbol test_simple_call\n", .{});
        return error.SymbolNotFound;
    };

    try stdout.print("Testing simpleCall\n", .{});
    const result = test_simple_call(42);
    try stdout.print("Result: {d}\n", .{result});

    if (result != 42) {
        try stdout.print("FAIL: expected 42, got {d}\n", .{result});
        return error.TestFailed;
    }

    try stdout.print("All Zig tests passed!\n", .{});
}
