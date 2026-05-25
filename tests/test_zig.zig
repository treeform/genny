const std = @import("std");
const test_lib = @import("generated/test.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

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

    std.debug.print("Testing getMessage\n", .{});
    const message = try test_lib.getMessage(allocator);
    defer allocator.free(message);
    if (!std.mem.eql(u8, message, "alpha\x00omega")) return error.TestFailed;

    std.debug.print("Testing SeqString\n", .{});
    const datas = test_lib.getDatas();
    defer datas.deinit();
    if (datas.len() != 3) return error.TestFailed;
    const data0 = try datas.get(0, allocator);
    defer allocator.free(data0);
    const data1 = try datas.get(1, allocator);
    defer allocator.free(data1);
    const data2 = try datas.get(2, allocator);
    defer allocator.free(data2);
    if (!std.mem.eql(u8, data0, "a")) return error.TestFailed;
    if (!std.mem.eql(u8, data1, "b")) return error.TestFailed;
    if (!std.mem.eql(u8, data2, "c")) return error.TestFailed;

    std.debug.print("All Zig tests passed!\n", .{});
}
