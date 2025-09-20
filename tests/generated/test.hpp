#ifndef INCLUDE_TEST_H
#define INCLUDE_TEST_H

#include <stdint.h>

#define SIMPLE_CONST 123

typedef char SimpleEnum;
#define FIRST 0
#define SECOND 1
#define THIRD 2

struct SimpleObj;

struct SimpleRefObj;

struct SeqInt;

struct RefObjWithSeq;

struct SimpleObjWithProc;

struct SeqString;

struct SimpleObj {
  int64_t simple_a;
  char simple_b;
  bool simple_c;
};

struct SimpleRefObj {

  private:

  uint64_t reference;

  public:

  SimpleRefObj();

  int64_t getSimpleRefA();
  void setSimpleRefA(int64_t value);

  char getSimpleRefB();
  void setSimpleRefB(char value);

  void free();

  /**
   * Does some thing with SimpleRefObj.
   */
  void doit();

};

struct SeqInt {

  private:

  uint64_t reference;

  public:

  void free();

};

struct RefObjWithSeq {

  private:

  uint64_t reference;

  public:

  RefObjWithSeq();

  void free();

};

struct SimpleObjWithProc {
  int64_t simple_a;
  char simple_b;
  bool simple_c;
  void extraProc();

};

struct SeqString {

  private:

  uint64_t reference;

  public:

  void free();

};

extern "C" {

int64_t test_simple_call(int64_t a);

SimpleObj test_simple_obj(int64_t simple_a, char simple_b, bool simple_c);

char test_simple_obj_eq(SimpleObj a, SimpleObj b);

void test_simple_ref_obj_unref(SimpleRefObj simple_ref_obj);

SimpleRefObj test_new_simple_ref_obj();

int64_t test_simple_ref_obj_get_simple_ref_a(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_a(SimpleRefObj simple_ref_obj, int64_t value);

char test_simple_ref_obj_get_simple_ref_b(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_b(SimpleRefObj simple_ref_obj, char value);

void test_simple_ref_obj_doit(SimpleRefObj s);

void test_seq_int_unref(SeqInt seq_int);

SeqInt test_new_seq_int();

int64_t test_seq_int_len(SeqInt seq_int);

int64_t test_seq_int_get(SeqInt seq_int, int64_t index);

void test_seq_int_set(SeqInt seq_int, int64_t index, int64_t value);

void test_seq_int_delete(SeqInt seq_int, int64_t index);

void test_seq_int_add(SeqInt seq_int, int64_t value);

void test_seq_int_clear(SeqInt seq_int);

void test_ref_obj_with_seq_unref(RefObjWithSeq ref_obj_with_seq);

RefObjWithSeq test_new_ref_obj_with_seq();

int64_t test_ref_obj_with_seq_data_len(RefObjWithSeq ref_obj_with_seq);

char test_ref_obj_with_seq_data_get(RefObjWithSeq ref_obj_with_seq, int64_t index);

void test_ref_obj_with_seq_data_set(RefObjWithSeq ref_obj_with_seq, int64_t index, char value);

void test_ref_obj_with_seq_data_delete(RefObjWithSeq ref_obj_with_seq, int64_t index);

void test_ref_obj_with_seq_data_add(RefObjWithSeq ref_obj_with_seq, char value);

void test_ref_obj_with_seq_data_clear(RefObjWithSeq ref_obj_with_seq);

SimpleObjWithProc test_simple_obj_with_proc(int64_t simple_a, char simple_b, bool simple_c);

char test_simple_obj_with_proc_eq(SimpleObjWithProc a, SimpleObjWithProc b);

void test_simple_obj_with_proc_extra_proc(SimpleObjWithProc s);

void test_seq_string_unref(SeqString seq_string);

SeqString test_new_seq_string();

int64_t test_seq_string_len(SeqString seq_string);

const char* test_seq_string_get(SeqString seq_string, int64_t index);

void test_seq_string_set(SeqString seq_string, int64_t index, const char* value);

void test_seq_string_delete(SeqString seq_string, int64_t index);

void test_seq_string_add(SeqString seq_string, const char* value);

void test_seq_string_clear(SeqString seq_string);

SeqString test_get_datas();

}

int64_t simpleCall(int64_t a) {
  return test_simple_call(a);
};

SimpleObj simpleObj(int64_t simpleA, char simpleB, bool simpleC) {
  return test_simple_obj(simpleA, simpleB, simpleC);
};

SimpleRefObj::SimpleRefObj() {
  this->reference = test_new_simple_ref_obj().reference;
}

int64_t SimpleRefObj::getSimpleRefA(){
  return test_simple_ref_obj_get_simple_ref_a(*this);
}

void SimpleRefObj::setSimpleRefA(int64_t value){
  test_simple_ref_obj_set_simple_ref_a(*this, value);
}

char SimpleRefObj::getSimpleRefB(){
  return test_simple_ref_obj_get_simple_ref_b(*this);
}

void SimpleRefObj::setSimpleRefB(char value){
  test_simple_ref_obj_set_simple_ref_b(*this, value);
}

void SimpleRefObj::free(){
  test_simple_ref_obj_unref(*this);
}

void SimpleRefObj::doit() {
  test_simple_ref_obj_doit(*this);
};

void SeqInt::free(){
  test_seq_int_unref(*this);
}

RefObjWithSeq::RefObjWithSeq() {
  this->reference = test_new_ref_obj_with_seq().reference;
}

void RefObjWithSeq::free(){
  test_ref_obj_with_seq_unref(*this);
}

SimpleObjWithProc simpleObjWithProc(int64_t simpleA, char simpleB, bool simpleC) {
  return test_simple_obj_with_proc(simpleA, simpleB, simpleC);
};

void SimpleObjWithProc::extraProc() {
  test_simple_obj_with_proc_extra_proc(*this);
};

void SeqString::free(){
  test_seq_string_unref(*this);
}

SeqString getDatas() {
  return test_get_datas();
};

#endif
