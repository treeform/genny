#ifndef INCLUDE_TEST_H
#define INCLUDE_TEST_H

#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string>

static constexpr auto SIMPLE_CONST = 123;

using SimpleEnum = std::uint8_t;
static constexpr SimpleEnum FIRST = 0;
static constexpr SimpleEnum SECOND = 1;
static constexpr SimpleEnum THIRD = 2;

struct SimpleObj;

struct SimpleRefObj;

struct SeqInt;

struct RefObjWithSeq;

struct SimpleObjWithProc;

struct ExternalObj;

struct SeqString;

struct GennyBuffer {

  private:

  std::uintptr_t reference;

  public:

  const char* data();
  std::intptr_t len();
  void free();

};

struct SimpleObj {
  std::intptr_t simple_a;
  std::uint8_t simple_b;
  bool simple_c;
};

struct SimpleRefObj {

  private:

  std::uintptr_t reference;

  public:

  SimpleRefObj();

  std::intptr_t getSimpleRefA();
  void setSimpleRefA(std::intptr_t value);

  std::uint8_t getSimpleRefB();
  void setSimpleRefB(std::uint8_t value);

  void free();

  /**
   * Does some thing with SimpleRefObj.
   */
  void doit();

};

struct SeqInt {

  private:

  std::uintptr_t reference;

  public:

  SeqInt();

  void free();

  std::intptr_t size();
  std::intptr_t get(std::intptr_t index);
  std::intptr_t operator[](std::intptr_t index);
  void set(std::intptr_t index, std::intptr_t value);
  void removeAt(std::intptr_t index);
  void add(std::intptr_t value);
  void clear();

};

struct RefObjWithSeq {

  private:

  std::uintptr_t reference;

  public:

  RefObjWithSeq();

  std::intptr_t dataSize();
  std::uint8_t getData(std::intptr_t index);
  void setData(std::intptr_t index, std::uint8_t value);
  void removeData(std::intptr_t index);
  void addData(std::uint8_t value);
  void clearData();

  void free();

};

struct SimpleObjWithProc {
  std::intptr_t simple_a;
  std::uint8_t simple_b;
  bool simple_c;
  void extraProc();

};

struct ExternalObj {
  std::int32_t external_a;
  bool external_b;
};

struct SeqString {

  private:

  std::uintptr_t reference;

  public:

  SeqString();

  void free();

  std::intptr_t size();
  std::string get(std::intptr_t index);
  std::string operator[](std::intptr_t index);
  void set(std::intptr_t index, const char* value);
  void removeAt(std::intptr_t index);
  void add(const char* value);
  void clear();

};

extern "C" {

const char* test_genny_buffer_data(GennyBuffer buffer);
std::intptr_t test_genny_buffer_len(GennyBuffer buffer);
void test_genny_buffer_unref(GennyBuffer buffer);

std::intptr_t test_simple_call(std::intptr_t a);

bool test_check_error();

GennyBuffer test_take_error();

GennyBuffer test_maybe_message(const char* message, bool fail);

std::intptr_t test_maybe_number(std::intptr_t value, bool fail);

SimpleObj test_simple_obj(std::intptr_t simple_a, std::uint8_t simple_b, bool simple_c);

bool test_simple_obj_eq(SimpleObj a, SimpleObj b);

void test_simple_ref_obj_unref(SimpleRefObj simple_ref_obj);

SimpleRefObj test_new_simple_ref_obj();

std::intptr_t test_simple_ref_obj_get_simple_ref_a(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_a(SimpleRefObj simple_ref_obj, std::intptr_t value);

std::uint8_t test_simple_ref_obj_get_simple_ref_b(SimpleRefObj simple_ref_obj);

void test_simple_ref_obj_set_simple_ref_b(SimpleRefObj simple_ref_obj, std::uint8_t value);

void test_simple_ref_obj_doit(SimpleRefObj s);

void test_seq_int_unref(SeqInt seq_int);

SeqInt test_new_seq_int();

std::intptr_t test_seq_int_len(SeqInt seq_int);

std::intptr_t test_seq_int_get(SeqInt seq_int, std::intptr_t index);

void test_seq_int_set(SeqInt seq_int, std::intptr_t index, std::intptr_t value);

void test_seq_int_delete(SeqInt seq_int, std::intptr_t index);

void test_seq_int_add(SeqInt seq_int, std::intptr_t value);

void test_seq_int_clear(SeqInt seq_int);

void test_ref_obj_with_seq_unref(RefObjWithSeq ref_obj_with_seq);

RefObjWithSeq test_new_ref_obj_with_seq();

std::intptr_t test_ref_obj_with_seq_data_len(RefObjWithSeq ref_obj_with_seq);

std::uint8_t test_ref_obj_with_seq_data_get(RefObjWithSeq ref_obj_with_seq, std::intptr_t index);

void test_ref_obj_with_seq_data_set(RefObjWithSeq ref_obj_with_seq, std::intptr_t index, std::uint8_t value);

void test_ref_obj_with_seq_data_delete(RefObjWithSeq ref_obj_with_seq, std::intptr_t index);

void test_ref_obj_with_seq_data_add(RefObjWithSeq ref_obj_with_seq, std::uint8_t value);

void test_ref_obj_with_seq_data_clear(RefObjWithSeq ref_obj_with_seq);

SimpleObjWithProc test_simple_obj_with_proc(std::intptr_t simple_a, std::uint8_t simple_b, bool simple_c);

bool test_simple_obj_with_proc_eq(SimpleObjWithProc a, SimpleObjWithProc b);

void test_simple_obj_with_proc_extra_proc(SimpleObjWithProc s);

ExternalObj test_external_obj(std::int32_t external_a, bool external_b);

bool test_external_obj_eq(ExternalObj a, ExternalObj b);

void test_seq_string_unref(SeqString seq_string);

SeqString test_new_seq_string();

std::intptr_t test_seq_string_len(SeqString seq_string);

GennyBuffer test_seq_string_get(SeqString seq_string, std::intptr_t index);

void test_seq_string_set(SeqString seq_string, std::intptr_t index, const char* value);

void test_seq_string_delete(SeqString seq_string, std::intptr_t index);

void test_seq_string_add(SeqString seq_string, const char* value);

void test_seq_string_clear(SeqString seq_string);

SeqString test_get_datas();

GennyBuffer test_get_message();

}

static inline std::string gennyBufferToString(GennyBuffer buffer) {
  const char* data = test_genny_buffer_data(buffer);
  std::intptr_t len = test_genny_buffer_len(buffer);
  std::string result;
  if (data != nullptr && len > 0) {
    result.assign(data, static_cast<std::size_t>(len));
  }
  test_genny_buffer_unref(buffer);
  return result;
}

const char* GennyBuffer::data() {
  return test_genny_buffer_data(*this);
}

std::intptr_t GennyBuffer::len() {
  return test_genny_buffer_len(*this);
}

void GennyBuffer::free() {
  test_genny_buffer_unref(*this);
}

struct testException : public std::runtime_error {
  explicit testException(const std::string& message) : std::runtime_error(message) {}
};

static inline void throwIfError() {
  if (test_check_error()) {
    throw testException(gennyBufferToString(test_take_error()));
  }
}

static inline void throwIfError(GennyBuffer buffer) {
  if (test_check_error()) {
    test_genny_buffer_unref(buffer);
    throw testException(gennyBufferToString(test_take_error()));
  }
}

std::intptr_t simpleCall(std::intptr_t a) {
  return test_simple_call(a);
};

bool checkError() {
  return test_check_error();
};

std::string takeError() {
  return gennyBufferToString(test_take_error());
};

std::string maybeMessage(const char* message, bool fail) {
  auto result = test_maybe_message(message, fail);
  throwIfError(result);
  return gennyBufferToString(result);
};

std::intptr_t maybeNumber(std::intptr_t value, bool fail) {
  auto result = test_maybe_number(value, fail);
  throwIfError();
  return result;
};

SimpleObj simpleObj(std::intptr_t simpleA, std::uint8_t simpleB, bool simpleC) {
  return test_simple_obj(simpleA, simpleB, simpleC);
};

SimpleRefObj::SimpleRefObj() {
  auto result = test_new_simple_ref_obj();
  this->reference = result.reference;
}

std::intptr_t SimpleRefObj::getSimpleRefA(){
  return test_simple_ref_obj_get_simple_ref_a(*this);
}

void SimpleRefObj::setSimpleRefA(std::intptr_t value){
  test_simple_ref_obj_set_simple_ref_a(*this, value);
}

std::uint8_t SimpleRefObj::getSimpleRefB(){
  return test_simple_ref_obj_get_simple_ref_b(*this);
}

void SimpleRefObj::setSimpleRefB(std::uint8_t value){
  test_simple_ref_obj_set_simple_ref_b(*this, value);
}

void SimpleRefObj::free(){
  test_simple_ref_obj_unref(*this);
}

void SimpleRefObj::doit() {
  test_simple_ref_obj_doit(*this);
};

SeqInt::SeqInt(){
  this->reference = test_new_seq_int().reference;
}

std::intptr_t SeqInt::size(){
  return test_seq_int_len(*this);
}

std::intptr_t SeqInt::get(std::intptr_t index){
  return test_seq_int_get(*this, index);
}

std::intptr_t SeqInt::operator[](std::intptr_t index){
  return get(index);
}

void SeqInt::set(std::intptr_t index, std::intptr_t value){
  test_seq_int_set(*this, index, value);
}

void SeqInt::removeAt(std::intptr_t index){
  test_seq_int_delete(*this, index);
}

void SeqInt::add(std::intptr_t value){
  test_seq_int_add(*this, value);
}

void SeqInt::clear(){
  test_seq_int_clear(*this);
}

void SeqInt::free(){
  test_seq_int_unref(*this);
}

RefObjWithSeq::RefObjWithSeq() {
  auto result = test_new_ref_obj_with_seq();
  this->reference = result.reference;
}

std::intptr_t RefObjWithSeq::dataSize(){
  return test_ref_obj_with_seq_data_len(*this);
}

std::uint8_t RefObjWithSeq::getData(std::intptr_t index){
  return test_ref_obj_with_seq_data_get(*this, index);
}

void RefObjWithSeq::setData(std::intptr_t index, std::uint8_t value){
  test_ref_obj_with_seq_data_set(*this, index, value);
}

void RefObjWithSeq::removeData(std::intptr_t index){
  test_ref_obj_with_seq_data_delete(*this, index);
}

void RefObjWithSeq::addData(std::uint8_t value){
  test_ref_obj_with_seq_data_add(*this, value);
}

void RefObjWithSeq::clearData(){
  test_ref_obj_with_seq_data_clear(*this);
}

void RefObjWithSeq::free(){
  test_ref_obj_with_seq_unref(*this);
}

SimpleObjWithProc simpleObjWithProc(std::intptr_t simpleA, std::uint8_t simpleB, bool simpleC) {
  return test_simple_obj_with_proc(simpleA, simpleB, simpleC);
};

void SimpleObjWithProc::extraProc() {
  test_simple_obj_with_proc_extra_proc(*this);
};

ExternalObj externalObj(std::int32_t externalA, bool externalB) {
  return test_external_obj(externalA, externalB);
};

SeqString::SeqString(){
  this->reference = test_new_seq_string().reference;
}

std::intptr_t SeqString::size(){
  return test_seq_string_len(*this);
}

std::string SeqString::get(std::intptr_t index){
  return gennyBufferToString(test_seq_string_get(*this, index));
}

std::string SeqString::operator[](std::intptr_t index){
  return get(index);
}

void SeqString::set(std::intptr_t index, const char* value){
  test_seq_string_set(*this, index, value);
}

void SeqString::removeAt(std::intptr_t index){
  test_seq_string_delete(*this, index);
}

void SeqString::add(const char* value){
  test_seq_string_add(*this, value);
}

void SeqString::clear(){
  test_seq_string_clear(*this);
}

void SeqString::free(){
  test_seq_string_unref(*this);
}

SeqString getDatas() {
  return test_get_datas();
};

std::string getMessage() {
  return gennyBufferToString(test_get_message());
};

#endif
