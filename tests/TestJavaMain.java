import genny.*;

public class TestJavaMain {
  static void check(boolean ok, String what) {
    if (!ok) throw new AssertionError(what);
    System.out.println("ok " + what);
  }

  static void throwsType(Class<? extends Throwable> type, Runnable r, String what) {
    try {
      r.run();
    } catch (Throwable t) {
      check(type.isInstance(t), what + " (got " + t + ")");
      return;
    }
    check(false, what + " (nothing thrown)");
  }

  static boolean hasMethod(Class<?> c, String name) {
    for (java.lang.reflect.Method m : c.getMethods()) {
      if (m.getName().equals(name)) return true;
    }
    return false;
  }

  public static void main(String[] args) throws Exception {
    TestJava.load(new java.io.File(args[0]).getAbsolutePath());

    check(TestJava.getInitCount() == 1, "Nim initializes once");
    check(!TestJava.hotReloadable(), "normal build is not hot reloadable");
    throwsType(UnsupportedOperationException.class, () -> TestJava.reload("/nonexistent.so"),
      "reload on a normal build");
    check(TestJava.addInts(1, 2) == 3, "normal build still works after reload is refused");

    check(TestJava.JAVA_LONG_CONST == 123L, "long const");
    check(TestJava.JAVA_DOUBLE_CONST == 1.5, "double const");
    check(TestJava.JAVA_STRING_CONST.equals("genny"), "string const");
    check(TestJava.JAVA_TYPED_CONST == 42, "typed int32 const");
    check(TestJava.JAVA_UNSIGNED_CONST == -1, "uint32 const keeps its bits");
    check(TestJava.JAVA_BOOL_CONST, "bool const");
    check(TestJava.JAVA_FLOAT_CONST == 0.25f, "float32 const");
    check(TestJava.JAVA_ESCAPED_CONST.equals("a\0b\"\\\né😀"), "escaped string const");

    check(TestJava.addInts(40, 2) == 42, "addInts");
    check(TestJava.addInts(Long.MAX_VALUE - 1, 1) == Long.MAX_VALUE, "addInts 64-bit");
    check(TestJava.addInt32s(1, 2) == 3, "addInt32s");
    check(TestJava.mulFloats(1.5f, 2f) == 3f, "mulFloats");
    check(TestJava.mulDoubles(1.5, 2) == 3.0, "mulDoubles");
    check(TestJava.negate(true) == false, "negate true");
    check(TestJava.negate(false) == true, "negate false");
    check(TestJava.echoByte((byte)7) == 7, "echoByte");
    check(TestJava.greet("Java").equals("Hello, Java!"), "greet");
    check(TestJava.helloWorld().equals("Hello world from Nim!"), "helloWorld");
    check(TestJava.clampTo(-1, 5) == 5, "Java keyword parameter name");

    String unicode = "Jäva 😀";
    check(TestJava.greet(unicode).equals("Hello, " + unicode + "!"), "non-ASCII string round trip");
    check(TestJava.utf8Len("😀") == 4, "strings reach Nim as standard UTF-8");
    check(TestJava.utf8Len("a\0b") == 1, "embedded NUL truncates at the C boundary");
    check(TestJava.invalidUtf8().equals("a�b"), "invalid UTF-8 from Nim becomes U+FFFD");

    for (int i = 0; i < 3; i++) TestJava.bump();
    check(TestJava.getCallCount() == 3, "void proc + state");

    check(TestJava.nextColor(Color.BLUE) == Color.RED, "enum param and return");
    check(TestJava.nextLevel(Level.LOW) == Level.MID && TestJava.nextLevel(Level.MID) == Level.HIGH,
      "enum with explicit values");
    check(Level.HIGH.value == 10, "enum value");
    throwsType(NullPointerException.class, () -> TestJava.nextColor(null), "null enum param");

    Tile tile = TestJava.moveTile(new Tile(new Vec(1f, 2f), Color.GREEN, true), 0.5f, -1f);
    check(tile.pos.x == 1.5f && tile.pos.y == 1f, "nested value object");
    check(tile.color == Color.GREEN && tile.solid, "value object enum and bool fields");
    check(new Tile().color == Color.RED && new Tile().pos != null, "value object defaults");
    throwsType(NullPointerException.class, () -> TestJava.moveTile(null, 0f, 0f), "null value object");
    throwsType(NullPointerException.class,
      () -> TestJava.moveTile(new Tile(new Vec(), null, false), 0f, 0f), "null enum in value object");
    throwsType(NullPointerException.class,
      () -> TestJava.moveTile(new Tile(null, Color.RED, false), 0f, 0f), "null nested value object");

    Reading reading = TestJava.boostReading(new Reading(Level.LOW, 21));
    check(reading.level == Level.MID && reading.amount == 42, "4-byte enum in value object");
    check(TestJava.sumBig(new Big(1, 2, 3, 4)) == 10, "bycopy value object param");
    Big big = TestJava.makeBig(5);
    check(big.a == 5 && big.d == 8, "bycopy value object return");

    check(new Vec(0f, Float.NaN).equals(new Vec(0f, Float.NaN)), "NaN fields equal themselves");
    check(!new Vec(0f, 0f).equals(new Vec(-0f, 0f)), "0.0 and -0.0 differ like Float.equals");
    check(new Vec(1f, 2f).hashCode() == new Vec(1f, 2f).hashCode(), "value object hashCode");

    try (Counter counter = new Counter(10)) {
      counter.bumpCounter();
      counter.bumpCounter();
      check(counter.getCount() == 12, "ref object constructor and proc");
      counter.setColor(Color.BLUE);
      check(counter.getColor() == Color.BLUE, "ref object enum field");
      check(counter.historyLen() == 2 && counter.historyGet(1) == 12, "ref object seq field");
      throwsType(IndexOutOfBoundsException.class, () -> counter.historyGet(2), "seq field get bounds");
      throwsType(IndexOutOfBoundsException.class, () -> counter.historySet(-1, 0), "seq field set bounds");
      throwsType(IndexOutOfBoundsException.class, () -> counter.historyDelete(5), "seq field delete bounds");
      check(counter.scaled(3) == 36 && counter.scaledInt64(3) == 72, "overloads with the same Java signature");
      check(!hasMethod(Counter.class, "getData") && !hasMethod(Counter.class, "setData"),
        "pointer fields are not exported");
    }

    Counter closed = new Counter(1);
    closed.close();
    closed.close();
    throwsType(IllegalStateException.class, () -> closed.getCount(), "closed ref object");
    throwsType(IllegalStateException.class, () -> TestJava.sameCount(closed, closed), "closed ref object argument");

    try (Counter a = TestJava.makeCounter(4); Counter b = new Counter(4)) {
      check(TestJava.sameCount(a, b), "ref object arguments");
    }

    try (SeqString w = TestJava.words()) {
      check(w.len() == 2 && w.get(1).equals("beta"), "seq[string]");
      w.add("gamma");
      check(w.get(2).equals("gamma"), "seq[string] add");
      throwsType(IndexOutOfBoundsException.class, () -> w.get(3), "seq get bounds");
      throwsType(IndexOutOfBoundsException.class, () -> w.get(-1), "seq negative index");
      throwsType(IndexOutOfBoundsException.class, () -> w.set(3, "x"), "seq set bounds");
      throwsType(IndexOutOfBoundsException.class, () -> w.delete(3), "seq delete bounds");
    }

    check(TestJava.failIfNegative(5) == 5, "raising proc, no error");
    try {
      TestJava.failIfNegative(-3);
      check(false, "raising proc throws");
    } catch (TestJavaException e) {
      check(e.getMessage().equals("negative: -3 ✗"), "raising proc throws with UTF-8 message");
    }

    java.nio.ByteBuffer buf = java.nio.ByteBuffer.allocateDirect(16).order(java.nio.ByteOrder.nativeOrder());
    TestJava.fillBuffer(buf, 16, 40);
    check(buf.getInt(0) == 40 && buf.getInt(12) == 43, "direct ByteBuffer as pointer");
    TestJava.fillBuffer(null, 0, 0);
    check(true, "null ByteBuffer as nil pointer");
    throwsType(IllegalArgumentException.class, () -> TestJava.fillBuffer(java.nio.ByteBuffer.allocate(16), 16, 40),
      "heap ByteBuffer is rejected");

    long destroyedBefore = TestJava.getDestroyedCount();
    try (Counter c = TestJava.makeCounter(1)) {
      check(c.getCount() == 1, "proc returning a ref object");
    }
    check(TestJava.getDestroyedCount() == destroyedBefore + 1, "close releases the Nim object");

    int dropped = 1000;
    for (int i = 0; i < dropped; i++) TestJava.makeCounter(i);
    long want = destroyedBefore + 1 + dropped;
    long deadline = System.nanoTime() + 10_000_000_000L;
    while (TestJava.getDestroyedCount() < want && System.nanoTime() < deadline) {
      System.gc();
      Thread.sleep(20);
      TestJava.releasePending();
    }
    check(TestJava.getDestroyedCount() == want, "Cleaner releases unclosed ref objects");

    System.out.println("All Java tests passed");
  }
}
