#ifndef INCLUDE_TEST_H
#define INCLUDE_TEST_H

#define SIMPLE_CONST 123

typedef char SimpleEnum;
#define FIRST 0
#define SECOND 1
#define THIRD 2

typedef struct SimpleObj {
  long long simple_a;
  char simple_b;
  char simple_c;
} SimpleObj;

typedef long long SimpleRefObj;

typedef long long SeqInt;

typedef long long RefObjWithSeq;

typedef struct SimpleObjWithProc {
  long long simple_a;
  char simple_b;
  char simple_c;
} SimpleObjWithProc;

typedef long long SeqString;

typedef long long GenRefInt;

/**
 * Returns the integer passed in.
 */
long long test_simple_call(long long a);

SimpleObj test_simple_obj(long long simple_a, char simple_b, char simple_c);

char test_simple_obj_eq(SimpleObj a, SimpleObj b);

void test_simple_ref_obj_unref(SimpleRefObj simple_ref_obj);

SimpleRefObj test_new_simple_ref_obj();

long long test_simple_ref_obj_get_simple_ref_a(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_a(SimpleRefObj simple_ref_obj, long long value);

char test_simple_ref_obj_get_simple_ref_b(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_b(SimpleRefObj simple_ref_obj, char value);

/**
 * Does some thing with SimpleRefObj.
 */
void test_simple_ref_obj_doit(SimpleRefObj s);

void test_seq_int_unref(SeqInt seq_int);

SeqInt test_new_seq_int();

long long test_seq_int_len(SeqInt seq_int);

long long test_seq_int_get(SeqInt seq_int, long long index);

void test_seq_int_set(SeqInt seq_int, long long index, long long value);

void test_seq_int_delete(SeqInt seq_int, long long index);

void test_seq_int_add(SeqInt seq_int, long long value);

void test_seq_int_clear(SeqInt seq_int);

void test_ref_obj_with_seq_unref(RefObjWithSeq ref_obj_with_seq);

RefObjWithSeq test_new_ref_obj_with_seq();

long long test_ref_obj_with_seq_data_len(RefObjWithSeq ref_obj_with_seq);

char test_ref_obj_with_seq_data_get(RefObjWithSeq ref_obj_with_seq, long long index);

void test_ref_obj_with_seq_data_set(RefObjWithSeq ref_obj_with_seq, long long index, char value);

void test_ref_obj_with_seq_data_delete(RefObjWithSeq ref_obj_with_seq, long long index);

void test_ref_obj_with_seq_data_add(RefObjWithSeq ref_obj_with_seq, char value);

void test_ref_obj_with_seq_data_clear(RefObjWithSeq ref_obj_with_seq);

SimpleObjWithProc test_simple_obj_with_proc(long long simple_a, char simple_b, char simple_c);

char test_simple_obj_with_proc_eq(SimpleObjWithProc a, SimpleObjWithProc b);

void test_simple_obj_with_proc_extra_proc(SimpleObjWithProc s);

void test_seq_string_unref(SeqString seq_string);

SeqString test_new_seq_string();

long long test_seq_string_len(SeqString seq_string);

char* test_seq_string_get(SeqString seq_string, long long index);

void test_seq_string_set(SeqString seq_string, long long index, char* value);

void test_seq_string_delete(SeqString seq_string, long long index);

void test_seq_string_add(SeqString seq_string, char* value);

void test_seq_string_clear(SeqString seq_string);

SeqString test_get_datas();

void test_gen_ref_int_unref(GenRefInt gen_ref_int);

GenRefInt test_new_gen_ref(long long v);

GenRefInt test_gen_ref_int_noop_gen_ref_int(GenRefInt);

#endif
