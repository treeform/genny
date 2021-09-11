
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

/*
 * Returns the integer passed in.
 */
long long test_simple_call(long long);

void test_simple_ref_obj_unref(SimpleRefObj);

SimpleRefObj test_new_simple_ref_obj();

long long test_simple_ref_obj_get_simple_ref_a(SimpleRefObj);

void test_simple_ref_obj_set_simple_ref_a(SimpleRefObj, long long);

char test_simple_ref_obj_get_simple_ref_b(SimpleRefObj);

void test_simple_ref_obj_set_simple_ref_b(SimpleRefObj, char);

/*
 * Does some thing with SimpleRefObj.
 */
void test_simple_ref_obj_doit(SimpleRefObj);

void test_seq_int_unref(SeqInt);

SeqInt test_new_seq_int();

long long test_seq_int_len(SeqInt);

long long test_seq_int_get(SeqInt, long long);

void test_seq_int_set(SeqInt, long long, long long);

void test_seq_int_delete(SeqInt, long long);

void test_seq_int_add(SeqInt, long long);

void test_seq_int_clear(SeqInt);

