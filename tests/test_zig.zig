const std = @import("std");
const test_lib = @import("generated/test.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Testing Zig bindings\n", .{});

    try stdout.print("Testing simpleCall\n", .{});
    std.debug.assert(test_lib.simpleCall(42) == 42);
    std.debug.assert(test_lib.simpleCall(0) == 0);

    try stdout.print("Testing simple_const\n", .{});
    std.debug.assert(test_lib.simple_const == 123);

    try stdout.print("Testing SimpleObj\n", .{});
    const obj = test_lib.SimpleObj.init(10, 20, true);
    std.debug.assert(obj.simple_a == 10);
    std.debug.assert(obj.simple_b == 20);
    std.debug.assert(obj.simple_c == true);

    try stdout.print("Testing SimpleRefObj\n", .{});
    const ref_obj = test_lib.SimpleRefObj.init();
    ref_obj.setSimpleRefA(100);
    std.debug.assert(ref_obj.getSimpleRefA() == 100);
    ref_obj.setSimpleRefB(50);
    std.debug.assert(ref_obj.getSimpleRefB() == 50);
    ref_obj.doit();
    ref_obj.deinit();

    try stdout.print("Testing SeqInt\n", .{});
    const seq_int = test_lib.SeqInt.init();
    seq_int.append(1);
    seq_int.append(2);
    seq_int.append(3);
    std.debug.assert(seq_int.len() == 3);
    std.debug.assert(seq_int.get(0) == 1);
    std.debug.assert(seq_int.get(1) == 2);
    std.debug.assert(seq_int.get(2) == 3);
    seq_int.set(1, 20);
    std.debug.assert(seq_int.get(1) == 20);
    seq_int.remove(0);
    std.debug.assert(seq_int.len() == 2);
    seq_int.clear();
    std.debug.assert(seq_int.len() == 0);
    seq_int.deinit();

    try stdout.print("Testing getDatas\n", .{});
    const datas = test_lib.getDatas();
    std.debug.assert(datas.len() == 3);
    std.debug.assert(std.mem.eql(u8, datas.get(0), "a"));
    std.debug.assert(std.mem.eql(u8, datas.get(1), "b"));
    std.debug.assert(std.mem.eql(u8, datas.get(2), "c"));
    datas.deinit();

    try stdout.print("All Zig tests passed!\n", .{});
}
