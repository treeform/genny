from ctypes import *
import os, sys

dir = os.path.dirname(sys.modules["pixie"].__file__)
if sys.platform == "win32":
  libName = "pixie.dll"
elif sys.platform == "darwin":
  libName = "libpixie.dylib"
else:
  libName = "libpixie.so"
dll = cdll.LoadLibrary(os.path.join(dir, libName))

class PixieError(Exception):
    pass

SIMPLE_CONST = 123

SimpleEnum = c_byte
FIRST = 0
SECOND = 1
THIRD = 2

def simple_call(a):
    """
    Returns the integer passed in.
    """
    result = dll.test_simple_call(a)
    return result

class SimpleObj(Structure):
    _fields_ = [
        ("simple_a", c_longlong),
        ("simple_b", c_byte),
        ("simple_c", c_bool)
    ]

    def __init__(self, simple_a, simple_b, simple_c):
        self.simple_a = simple_a
        self.simple_b = simple_b
        self.simple_c = simple_c

    def __eq__(self, obj):
        return self.simple_a == obj.simple_a and self.simple_b == obj.simple_b and self.simple_c == obj.simple_c

class SimpleRefObj(Structure):
    _fields_ = [("ref", c_ulonglong)]

    def __bool__(self):
        return self.ref != None

    def __eq__(self, obj):
        return self.ref == obj.ref

    def __del__(self):
        dll.test_simple_ref_obj_unref(self)

    def __init__(self):
        result = dll.test_new_simple_ref_obj()
        self.ref = result

    @property
    def simple_ref_a(self):
        return dll.test_simple_ref_obj_get_simple_ref_a(self)

    @simple_ref_a.setter
    def simple_ref_a(self, simple_ref_a):
        dll.test_simple_ref_obj_set_simple_ref_a(self, simple_ref_a)

    @property
    def simple_ref_b(self):
        return dll.test_simple_ref_obj_get_simple_ref_b(self)

    @simple_ref_b.setter
    def simple_ref_b(self, simple_ref_b):
        dll.test_simple_ref_obj_set_simple_ref_b(self, simple_ref_b)

    def doit(self):
        """
        Does some thing with SimpleRefObj.
        """
        dll.test_simple_ref_obj_doit(self)

class SeqInt(Structure):
    _fields_ = [("ref", c_ulonglong)]

    def __bool__(self):
        return self.ref != None

    def __eq__(self, obj):
        return self.ref == obj.ref

    def __del__(self):
        dll.test_seq_int_unref(self)

    def __init__(self):
        self.ref = dll.test_new_seq_int()

    def __len__(self):
        return dll.test_seq_int_len(self)

    def __getitem__(self, index):
        return dll.test_seq_int_get(self, index)

    def __setitem__(self, index, value):
        dll.test_seq_int_set(self, index, value)

    def __delitem__(self, index):
        dll.test_seq_int_delete(self, index)

    def append(self, value):
        dll.test_seq_int_add(self, value)

    def clear(self):
        dll.test_seq_int_clear(self)

class RefObjWithSeq(Structure):
    _fields_ = [("ref", c_ulonglong)]

    def __bool__(self):
        return self.ref != None

    def __eq__(self, obj):
        return self.ref == obj.ref

    def __del__(self):
        dll.test_ref_obj_with_seq_unref(self)

    def __init__(self):
        result = dll.test_new_ref_obj_with_seq()
        self.ref = result

    class RefObjWithSeqData:

        def __init__(self, ref_obj_with_seq):
            self.ref_obj_with_seq = ref_obj_with_seq

        def __len__(self):
            return dll.test_ref_obj_with_seq_data_len(self.ref_obj_with_seq)

        def __getitem__(self, index):
            return dll.test_ref_obj_with_seq_data_get(self.ref_obj_with_seq, index)

        def __setitem__(self, index, value):
            dll.test_ref_obj_with_seq_data_set(self.ref_obj_with_seq, index, value)

        def __delitem__(self, index):
            dll.test_ref_obj_with_seq_data_delete(self.ref_obj_with_seq, index)

        def append(self, value):
            dll.test_ref_obj_with_seq_data_add(self.ref_obj_with_seq, value)

        def clear(self):
            dll.test_ref_obj_with_seq_data_clear(self.ref_obj_with_seq)

    @property
    def data(self):
        return self.RefObjWithSeqData(self)

class SimpleObjWithProc(Structure):
    _fields_ = [
        ("simple_a", c_longlong),
        ("simple_b", c_byte),
        ("simple_c", c_bool)
    ]

    def __init__(self, simple_a, simple_b, simple_c):
        self.simple_a = simple_a
        self.simple_b = simple_b
        self.simple_c = simple_c

    def __eq__(self, obj):
        return self.simple_a == obj.simple_a and self.simple_b == obj.simple_b and self.simple_c == obj.simple_c

    def extra_proc(self):
        dll.test_simple_obj_with_proc_extra_proc(self)

class ArrayObj(Structure):
    _fields_ = [
        ("arr_1", c_longlong * 3),
        ("arr_2", c_longlong * 3 * 3),
        ("arr_3", c_longlong * 3 * 3 * 3)
    ]

    def __init__(self, arr_1, arr_2, arr_3):
        self.arr_1 = arr_1
        self.arr_2 = arr_2
        self.arr_3 = arr_3

    def __eq__(self, obj):
        return self.arr_1[0] == obj.arr_1[0] and self.arr_1[1] == obj.arr_1[1] and self.arr_1[2] == obj.arr_1[2] and self.arr_2[0] == obj.arr_2[0] and self.arr_2[1] == obj.arr_2[1] and self.arr_2[2] == obj.arr_2[2] and self.arr_3[0] == obj.arr_3[0] and self.arr_3[1] == obj.arr_3[1] and self.arr_3[2] == obj.arr_3[2]

dll.test_simple_call.argtypes = [c_longlong]
dll.test_simple_call.restype = c_longlong

dll.test_simple_ref_obj_unref.argtypes = [SimpleRefObj]
dll.test_simple_ref_obj_unref.restype = None

dll.test_new_simple_ref_obj.argtypes = []
dll.test_new_simple_ref_obj.restype = c_ulonglong

dll.test_simple_ref_obj_get_simple_ref_a.argtypes = [SimpleRefObj]
dll.test_simple_ref_obj_get_simple_ref_a.restype = c_longlong

dll.test_simple_ref_obj_set_simple_ref_a.argtypes = [SimpleRefObj, c_longlong]
dll.test_simple_ref_obj_set_simple_ref_a.restype = None

dll.test_simple_ref_obj_get_simple_ref_b.argtypes = [SimpleRefObj]
dll.test_simple_ref_obj_get_simple_ref_b.restype = c_byte

dll.test_simple_ref_obj_set_simple_ref_b.argtypes = [SimpleRefObj, c_byte]
dll.test_simple_ref_obj_set_simple_ref_b.restype = None

dll.test_simple_ref_obj_doit.argtypes = [SimpleRefObj]
dll.test_simple_ref_obj_doit.restype = None

dll.test_seq_int_unref.argtypes = [SeqInt]
dll.test_seq_int_unref.restype = None

dll.test_new_seq_int.argtypes = []
dll.test_new_seq_int.restype = c_ulonglong

dll.test_seq_int_len.argtypes = [SeqInt]
dll.test_seq_int_len.restype = c_longlong

dll.test_seq_int_get.argtypes = [SeqInt, c_longlong]
dll.test_seq_int_get.restype = c_longlong

dll.test_seq_int_set.argtypes = [SeqInt, c_longlong, c_longlong]
dll.test_seq_int_set.restype = None

dll.test_seq_int_delete.argtypes = [SeqInt, c_longlong]
dll.test_seq_int_delete.restype = None

dll.test_seq_int_add.argtypes = [SeqInt, c_longlong]
dll.test_seq_int_add.restype = None

dll.test_seq_int_clear.argtypes = [SeqInt]
dll.test_seq_int_clear.restype = None

dll.test_ref_obj_with_seq_unref.argtypes = [RefObjWithSeq]
dll.test_ref_obj_with_seq_unref.restype = None

dll.test_new_ref_obj_with_seq.argtypes = []
dll.test_new_ref_obj_with_seq.restype = c_ulonglong

dll.test_ref_obj_with_seq_data_len.argtypes = [RefObjWithSeq]
dll.test_ref_obj_with_seq_data_len.restype = c_longlong

dll.test_ref_obj_with_seq_data_get.argtypes = [RefObjWithSeq, c_longlong]
dll.test_ref_obj_with_seq_data_get.restype = c_byte

dll.test_ref_obj_with_seq_data_set.argtypes = [RefObjWithSeq, c_longlong, c_byte]
dll.test_ref_obj_with_seq_data_set.restype = None

dll.test_ref_obj_with_seq_data_delete.argtypes = [RefObjWithSeq, c_longlong]
dll.test_ref_obj_with_seq_data_delete.restype = None

dll.test_ref_obj_with_seq_data_add.argtypes = [RefObjWithSeq, c_byte]
dll.test_ref_obj_with_seq_data_add.restype = None

dll.test_ref_obj_with_seq_data_clear.argtypes = [RefObjWithSeq]
dll.test_ref_obj_with_seq_data_clear.restype = None

dll.test_simple_obj_with_proc_extra_proc.argtypes = [SimpleObjWithProc]
dll.test_simple_obj_with_proc_extra_proc.restype = None

