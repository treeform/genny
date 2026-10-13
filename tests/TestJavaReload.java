import genny.*;

/**
 * args: loader.so v1.so v2.so dropped-symbol.so
 * The loader is the generated C built with -DGENNY_JAVA_HOT_RELOAD.
 */
public class TestJavaReload {
  static void check(boolean ok, String what) {
    if (!ok) throw new AssertionError(what);
    System.out.println("ok " + what);
  }

  static Throwable throwsType(Class<? extends Throwable> type, Runnable r, String what) {
    try {
      r.run();
    } catch (Throwable t) {
      check(type.isInstance(t), what + " (got " + t + ")");
      return t;
    }
    check(false, what + " (nothing thrown)");
    return null;
  }

  static String abs(String path) {
    return new java.io.File(path).getAbsolutePath();
  }

  public static void main(String[] args) throws Exception {
    TestReload.load(abs(args[0]));
    check(TestReload.hotReloadable(), "loader is hot reloadable");
    Throwable t = throwsType(IllegalStateException.class, () -> TestReload.version(),
      "calls before the first reload throw");
    check(t.getMessage().equals("native library not loaded"), "not loaded message");

    TestReload.reload(abs(args[1]));
    check(TestReload.version() == 1, "v1 bound");
    check(TestReload.bonus() == 7, "v1 bonus");
    Box box = new Box(5);
    check(box.getValue() == 5, "ref object from v1");
    box.setValue(6);
    check(box.getValue() == 6, "ref object field from v1");

    TestReload.reload(abs(args[2]));
    check(TestReload.version() == 2, "v2 bound");
    t = throwsType(IllegalStateException.class, () -> box.getValue(), "v1 handle throws after reload");
    check(t.getMessage().equals("handle from a previous native library generation"), "stale handle message");
    box.close();
    check(true, "closing a stale handle does nothing");
    try (Box fresh = new Box(9)) {
      check(fresh.getValue() == 9, "ref object from v2");
    }

    for (int i = 0; i < 1000; i++) new Box(i);
    TestReload.reload(abs(args[2]));
    check(TestReload.version() == 2, "reloading again");
    for (int i = 0; i < 5; i++) {
      System.gc();
      Thread.sleep(20);
      TestReload.releasePending();
    }
    check(TestReload.version() == 2, "dropped stale handles are not released into the new library");

    throwsType(IllegalStateException.class, () -> TestReload.reload("/nonexistent.so"),
      "missing file is rejected");
    check(TestReload.version() == 2, "failed dlopen keeps the old library");

    t = throwsType(IllegalStateException.class, () -> TestReload.reload(abs(args[3])),
      "library missing a symbol is rejected");
    check(t.getMessage().contains("fingerprint"), "changed exported API is rejected before binding");
    check(TestReload.version() == 2 && TestReload.bonus() == 7, "rejected library keeps the old one");
    try (Box after = new Box(3)) {
      check(after.getValue() == 3, "handles still work after a failed reload");
    }

    throwsType(NullPointerException.class, () -> TestReload.reload(null), "null path");
    Box survivor = new Box(17);
    TestReload.prepareReload(abs(args[1]));
    check(TestReload.version() == 2 && survivor.getValue() == 17, "prepare preserves active generation and handles");
    TestReload.cancelReload();
    check(survivor.getValue() == 17, "cancel preserves active handles");
    TestReload.prepareReload(abs(args[1]));
    TestReload.activateReload();
    check(TestReload.version() == 1, "activation retains previous generation");
    throwsType(IllegalStateException.class, () -> survivor.getValue(), "activation invalidates old handles");
    Box candidate = new Box(19);
    TestReload.rollbackReload();
    check(TestReload.version() == 2, "rollback restores previous function table");
    throwsType(IllegalStateException.class, () -> survivor.getValue(), "rollback never revives old handles");
    throwsType(IllegalStateException.class, () -> candidate.getValue(), "rollback invalidates candidate handles");
    survivor.close(); candidate.close();
    try (Box current = new Box(23)) {
      throwsType(IllegalStateException.class, TestReload::activateReload, "unprepared activation rejected");
      check(current.getValue() == 23, "unprepared activation preserves handles");
    }
    System.out.println("All Java reload tests passed");
  }
}
