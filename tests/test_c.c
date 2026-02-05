/* Test C bindings. */
#include <stdio.h>
#include <assert.h>
#include "test.h"

int main() {
    printf("Testing C bindings\n");

    printf("Testing test_simple_call\n");
    assert(test_simple_call(42) == 42);
    assert(test_simple_call(0) == 0);

    printf("Testing SIMPLE_CONST\n");
    assert(SIMPLE_CONST == 123);

    printf("Testing SimpleObj\n");
    SimpleObj obj = test_simple_obj(10, 20, 1);
    assert(obj.simple_a == 10);
    assert(obj.simple_b == 20);
    assert(obj.simple_c == 1);

    printf("Testing SimpleRefObj\n");
    SimpleRefObj ref_obj = test_new_simple_ref_obj();
    test_simple_ref_obj_set_simple_ref_a(ref_obj, 100);
    assert(test_simple_ref_obj_get_simple_ref_a(ref_obj) == 100);
    test_simple_ref_obj_set_simple_ref_b(ref_obj, 50);
    assert(test_simple_ref_obj_get_simple_ref_b(ref_obj) == 50);
    test_simple_ref_obj_doit(ref_obj);
    test_simple_ref_obj_unref(ref_obj);

    printf("Testing SeqInt\n");
    SeqInt seq_int = test_new_seq_int();
    test_seq_int_add(seq_int, 1);
    test_seq_int_add(seq_int, 2);
    test_seq_int_add(seq_int, 3);
    assert(test_seq_int_len(seq_int) == 3);
    assert(test_seq_int_get(seq_int, 0) == 1);
    assert(test_seq_int_get(seq_int, 1) == 2);
    assert(test_seq_int_get(seq_int, 2) == 3);
    test_seq_int_set(seq_int, 1, 20);
    assert(test_seq_int_get(seq_int, 1) == 20);
    test_seq_int_delete(seq_int, 0);
    assert(test_seq_int_len(seq_int) == 2);
    test_seq_int_clear(seq_int);
    assert(test_seq_int_len(seq_int) == 0);
    test_seq_int_unref(seq_int);

    printf("Testing test_get_datas\n");
    SeqString datas = test_get_datas();
    assert(test_seq_string_len(datas) == 3);
    test_seq_string_unref(datas);

    printf("All C tests passed!\n");
    return 0;
}
