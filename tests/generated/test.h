#ifndef INCLUDE_TEST_H
#define INCLUDE_TEST_H

#include <stdint.h>

typedef struct GennyBufferHandle* GennyBuffer;

#define SIMPLE_CONST 123

typedef char SimpleEnum;
#define FIRST 0
#define SECOND 1
#define THIRD 2

typedef struct SimpleObj {
  intptr_t simple_a;
  uint8_t simple_b;
  char simple_c;
} SimpleObj;

typedef struct SimpleRefObjHandle* SimpleRefObj;

typedef struct SeqIntHandle* SeqInt;

typedef struct RefObjWithSeqHandle* RefObjWithSeq;

typedef struct SimpleObjWithProc {
  intptr_t simple_a;
  uint8_t simple_b;
  char simple_c;
} SimpleObjWithProc;

typedef struct SeqStringHandle* SeqString;

#ifdef __cplusplus
extern "C" {
#endif

const char* test_genny_buffer_data(GennyBuffer buffer);
intptr_t test_genny_buffer_len(GennyBuffer buffer);
void test_genny_buffer_unref(GennyBuffer buffer);
/**
 * Returns the integer passed in.
 */
intptr_t test_simple_call(intptr_t a);

SimpleObj test_simple_obj(intptr_t simple_a, uint8_t simple_b, char simple_c);

char test_simple_obj_eq(SimpleObj a, SimpleObj b);

void test_simple_ref_obj_unref(SimpleRefObj simple_ref_obj);

SimpleRefObj test_new_simple_ref_obj();

intptr_t test_simple_ref_obj_get_simple_ref_a(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_a(SimpleRefObj simple_ref_obj, intptr_t value);

uint8_t test_simple_ref_obj_get_simple_ref_b(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_b(SimpleRefObj simple_ref_obj, uint8_t value);

/**
 * Does some thing with SimpleRefObj.
 */
void test_simple_ref_obj_doit(SimpleRefObj s);

void test_seq_int_unref(SeqInt seq_int);

SeqInt test_new_seq_int();

intptr_t test_seq_int_len(SeqInt seq_int);

intptr_t test_seq_int_get(SeqInt seq_int, intptr_t index);

void test_seq_int_set(SeqInt seq_int, intptr_t index, intptr_t value);

void test_seq_int_delete(SeqInt seq_int, intptr_t index);

void test_seq_int_add(SeqInt seq_int, intptr_t value);

void test_seq_int_clear(SeqInt seq_int);

void test_ref_obj_with_seq_unref(RefObjWithSeq ref_obj_with_seq);

RefObjWithSeq test_new_ref_obj_with_seq();

intptr_t test_ref_obj_with_seq_data_len(RefObjWithSeq ref_obj_with_seq);

uint8_t test_ref_obj_with_seq_data_get(RefObjWithSeq ref_obj_with_seq, intptr_t index);

void test_ref_obj_with_seq_data_set(RefObjWithSeq ref_obj_with_seq, intptr_t index, uint8_t value);

void test_ref_obj_with_seq_data_delete(RefObjWithSeq ref_obj_with_seq, intptr_t index);

void test_ref_obj_with_seq_data_add(RefObjWithSeq ref_obj_with_seq, uint8_t value);

void test_ref_obj_with_seq_data_clear(RefObjWithSeq ref_obj_with_seq);

SimpleObjWithProc test_simple_obj_with_proc(intptr_t simple_a, uint8_t simple_b, char simple_c);

char test_simple_obj_with_proc_eq(SimpleObjWithProc a, SimpleObjWithProc b);

void test_simple_obj_with_proc_extra_proc(SimpleObjWithProc s);

void test_seq_string_unref(SeqString seq_string);

SeqString test_new_seq_string();

intptr_t test_seq_string_len(SeqString seq_string);

GennyBuffer test_seq_string_get(SeqString seq_string, intptr_t index);

void test_seq_string_set(SeqString seq_string, intptr_t index, const char* value);

void test_seq_string_delete(SeqString seq_string, intptr_t index);

void test_seq_string_add(SeqString seq_string, const char* value);

void test_seq_string_clear(SeqString seq_string);

SeqString test_get_datas();

GennyBuffer test_get_message();

#ifdef __cplusplus
}
#endif

#endif
