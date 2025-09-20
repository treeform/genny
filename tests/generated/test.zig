const std = @import("std");

pub const simple_const = 123;

pub const SimpleEnum = enum(u8) {
    first = 0,
    second = 1,
    third = 2,
};

extern fn test_simple_call(a: isize) callconv(.C) isize;
/// Returns the integer passed in.
pub inline fn simpleCall(a: isize) isize {
    return test_simple_call(a);
}

pub const SimpleObj = extern struct {
    simple_a: isize,
    simple_b: u8,
    simple_c: bool,

    pub fn init(simple_a: isize, simple_b: u8, simple_c: bool) SimpleObj {
        return SimpleObj{
            .simple_a = simple_a,
            .simple_b = simple_b,
            .simple_c = simple_c,
        };
    }

    extern fn test_simple_obj_eq(self: SimpleObj, other: SimpleObj) callconv(.C) bool;
    pub inline fn eql(self: SimpleObj, other: SimpleObj) bool {
        return test_simple_obj_eq(self, other);
    }
};

pub const SimpleRefObj = opaque {
    extern fn test_simple_ref_obj_unref(self: *SimpleRefObj) callconv(.C) void;
    pub inline fn deinit(self: *SimpleRefObj) void {
        return test_simple_ref_obj_unref(self);
    }

    extern fn test_new_simple_ref_obj() callconv(.C) *SimpleRefObj;
    /// Creates new SimpleRefObj.
    pub inline fn init() *SimpleRefObj {
        return test_new_simple_ref_obj();
    }

    extern fn test_simple_ref_obj_get_simple_ref_a(self: *SimpleRefObj) callconv(.C) isize;
    pub inline fn getSimpleRefA(self: *SimpleRefObj) isize {
        return test_simple_ref_obj_get_simple_ref_a(self);
    }

    extern fn test_simple_ref_obj_set_simple_ref_a(self: *SimpleRefObj, value: isize) callconv(.C) void;
    pub inline fn setSimpleRefA(self: *SimpleRefObj, value: isize) void {
        return test_simple_ref_obj_set_simple_ref_a(self, value);
    }

    extern fn test_simple_ref_obj_get_simple_ref_b(self: *SimpleRefObj) callconv(.C) u8;
    pub inline fn getSimpleRefB(self: *SimpleRefObj) u8 {
        return test_simple_ref_obj_get_simple_ref_b(self);
    }

    extern fn test_simple_ref_obj_set_simple_ref_b(self: *SimpleRefObj, value: u8) callconv(.C) void;
    pub inline fn setSimpleRefB(self: *SimpleRefObj, value: u8) void {
        return test_simple_ref_obj_set_simple_ref_b(self, value);
    }

    extern fn test_simple_ref_obj_doit(self: *SimpleRefObj) callconv(.C) void;
    /// Does some thing with SimpleRefObj.
    pub inline fn doit(self: *SimpleRefObj) void {
        return test_simple_ref_obj_doit(self);
    }
};

pub const SeqInt = opaque {
    extern fn test_seq_int_unref(self: *SeqInt) callconv(.C) void;
    pub inline fn deinit(self: *SeqInt) void {
        return test_seq_int_unref(self);
    }

    extern fn test_new_seq_int() callconv(.C) *SeqInt;
    pub inline fn init() *SeqInt {
        return test_new_seq_int();
    }

    extern fn test_seq_int_len(self: *SeqInt) callconv(.C) isize;
    pub inline fn len(self: *SeqInt) isize {
        return test_seq_int_len(self);
    }

    extern fn test_seq_int_get(self: *SeqInt, index: isize) callconv(.C) isize;
    pub inline fn get(self: *SeqInt, index: isize) isize {
        return test_seq_int_get(self, index);
    }

    extern fn test_seq_int_set(self: *SeqInt, index: isize, value: isize) callconv(.C) void;
    pub inline fn set(self: *SeqInt, index: isize, value: isize) void {
        return test_seq_int_set(self, index, value);
    }

    extern fn test_seq_int_add(self: *SeqInt, value: isize) callconv(.C) void;
    pub inline fn append(self: *SeqInt, value: isize) void {
        return test_seq_int_add(self, value);
    }

    extern fn test_seq_int_delete(self: *SeqInt, index: isize) callconv(.C) void;
    pub inline fn remove(self: *SeqInt, index: isize) void {
        return test_seq_int_delete(self, index);
    }

    extern fn test_seq_int_clear(self: *SeqInt) callconv(.C) void;
    pub inline fn clear(self: *SeqInt) void {
        return test_seq_int_clear(self);
    }
};

pub const RefObjWithSeq = opaque {
    extern fn test_ref_obj_with_seq_unref(self: *RefObjWithSeq) callconv(.C) void;
    pub inline fn deinit(self: *RefObjWithSeq) void {
        return test_ref_obj_with_seq_unref(self);
    }

    extern fn test_new_ref_obj_with_seq() callconv(.C) *RefObjWithSeq;
    /// Creates new SimpleRefObj.
    pub inline fn init() *RefObjWithSeq {
        return test_new_ref_obj_with_seq();
    }

    extern fn test_ref_obj_with_seq_data_len(self: *RefObjWithSeq) callconv(.C) isize;
    pub inline fn lenData(self: *RefObjWithSeq) isize {
        return test_ref_obj_with_seq_data_len(self);
    }

    extern fn test_ref_obj_with_seq_data_get(self: *RefObjWithSeq, index: isize) callconv(.C) u8;
    pub inline fn getData(self: *RefObjWithSeq, index: isize) u8 {
        return test_ref_obj_with_seq_data_get(self, index);
    }

    extern fn test_ref_obj_with_seq_data_set(self: *RefObjWithSeq, index: isize, value: u8) callconv(.C) void;
    pub inline fn setData(self: *RefObjWithSeq, index: isize, value: u8) void {
        return test_ref_obj_with_seq_data_set(self, index, value);
    }

    extern fn test_ref_obj_with_seq_data_add(self: *RefObjWithSeq, value: u8) callconv(.C) void;
    pub inline fn appendData(self: *RefObjWithSeq, value: u8) void {
        return test_ref_obj_with_seq_data_add(self, value);
    }

    extern fn test_ref_obj_with_seq_data_delete(self: *RefObjWithSeq, index: isize) callconv(.C) void;
    pub inline fn removeData(self: *RefObjWithSeq, index: isize) void {
        return test_ref_obj_with_seq_data_delete(self, index);
    }

    extern fn test_ref_obj_with_seq_data_clear(self: *RefObjWithSeq) callconv(.C) void;
    pub inline fn clearData(self: *RefObjWithSeq) void {
        return test_ref_obj_with_seq_data_clear(self);
    }
};

pub const SimpleObjWithProc = extern struct {
    simple_a: isize,
    simple_b: u8,
    simple_c: bool,

    pub fn init(simple_a: isize, simple_b: u8, simple_c: bool) SimpleObjWithProc {
        return SimpleObjWithProc{
            .simple_a = simple_a,
            .simple_b = simple_b,
            .simple_c = simple_c,
        };
    }

    extern fn test_simple_obj_with_proc_eq(self: SimpleObjWithProc, other: SimpleObjWithProc) callconv(.C) bool;
    pub inline fn eql(self: SimpleObjWithProc, other: SimpleObjWithProc) bool {
        return test_simple_obj_with_proc_eq(self, other);
    }

    extern fn test_simple_obj_with_proc_extra_proc(self: SimpleObjWithProc) callconv(.C) void;
    pub inline fn extraProc(self: SimpleObjWithProc) void {
        return test_simple_obj_with_proc_extra_proc(self);
    }
};

pub const SeqString = opaque {
    extern fn test_seq_string_unref(self: *SeqString) callconv(.C) void;
    pub inline fn deinit(self: *SeqString) void {
        return test_seq_string_unref(self);
    }

    extern fn test_new_seq_string() callconv(.C) *SeqString;
    pub inline fn init() *SeqString {
        return test_new_seq_string();
    }

    extern fn test_seq_string_len(self: *SeqString) callconv(.C) isize;
    pub inline fn len(self: *SeqString) isize {
        return test_seq_string_len(self);
    }

    extern fn test_seq_string_get(self: *SeqString, index: isize) callconv(.C) [*:0]const u8;
    pub inline fn get(self: *SeqString, index: isize) [:0]const u8 {
        return std.mem.span(test_seq_string_get(self, index));
    }

    extern fn test_seq_string_set(self: *SeqString, index: isize, value: [*:0]const u8) callconv(.C) void;
    pub inline fn set(self: *SeqString, index: isize, value: [:0]const u8) void {
        return test_seq_string_set(self, index, value.ptr);
    }

    extern fn test_seq_string_add(self: *SeqString, value: [*:0]const u8) callconv(.C) void;
    pub inline fn append(self: *SeqString, value: [:0]const u8) void {
        return test_seq_string_add(self, value.ptr);
    }

    extern fn test_seq_string_delete(self: *SeqString, index: isize) callconv(.C) void;
    pub inline fn remove(self: *SeqString, index: isize) void {
        return test_seq_string_delete(self, index);
    }

    extern fn test_seq_string_clear(self: *SeqString) callconv(.C) void;
    pub inline fn clear(self: *SeqString) void {
        return test_seq_string_clear(self);
    }
};

extern fn test_get_datas() callconv(.C) *SeqString;
pub inline fn getDatas() *SeqString {
    return test_get_datas();
}

