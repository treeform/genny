#ifndef INCLUDE_TEST_H
#define INCLUDE_TEST_H
void *memcpy(void *dest, const void * src, size_t n);

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
SimpleObj simple_obj(long long simple_a, char simple_b, char simple_c) {
  SimpleObj result;
  result.simple_a = simple_a;
  result.simple_b = simple_b;
  result.simple_c = simple_c;
  return result;
}

typedef long long SimpleRefObj;

typedef long long SeqInt;

typedef long long RefObjWithSeq;

typedef struct SimpleObjWithProc {
  long long simple_a;
  char simple_b;
  char simple_c;
} SimpleObjWithProc;
SimpleObjWithProc simple_obj_with_proc(long long simple_a, char simple_b, char simple_c) {
  SimpleObjWithProc result;
  result.simple_a = simple_a;
  result.simple_b = simple_b;
  result.simple_c = simple_c;
  return result;
}

typedef struct ArrayObj {
  long long arr_1[3];
  long long arr_2[3][3];
  long long arr_3[3][3][3];
} ArrayObj;
ArrayObj array_obj(long long arr_1[3], long long arr_2[3][3], long long arr_3[3][3][3]) {
  ArrayObj result;
  memcpy(&result.arr_1, &arr_1, sizeof(arr_1));
  memcpy(&result.arr_2, &arr_2, sizeof(arr_2));
  memcpy(&result.arr_3, &arr_3, sizeof(arr_3));
  return result;
}

/**
 * Returns the integer passed in.
 */
long long test_simple_call(long long a);

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

#endif
