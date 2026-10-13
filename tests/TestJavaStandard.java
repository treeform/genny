import genny.*;

public class TestJavaStandard {
  static void check(boolean ok, String what) {
    if (!ok) throw new AssertionError(what);
    System.out.println("ok " + what);
  }

  public static void main(String[] args) {
    Test.load(new java.io.File(args[0]).getAbsolutePath());

    check(Test.simpleCall(42) == 42, "simpleCall");
    check(Test.simpleCall(0) == 0, "simpleCall zero");
    check(Test.SIMPLE_CONST == 123L, "SIMPLE_CONST");
    check(SimpleEnum.values().length == 3 && SimpleEnum.THIRD.ordinal() == 2, "SimpleEnum");

    SimpleObj obj = new SimpleObj(10, (byte)20, true);
    check(obj.simpleA == 10 && obj.simpleB == 20 && obj.simpleC, "SimpleObj fields");
    check(obj.equals(new SimpleObj(10, (byte)20, true)), "SimpleObj equals");

    try (SimpleRefObj ref = new SimpleRefObj()) {
      ref.setSimpleRefA(100);
      check(ref.getSimpleRefA() == 100, "SimpleRefObj a");
      ref.setSimpleRefB((byte)50);
      check(ref.getSimpleRefB() == 50, "SimpleRefObj b");
      ref.doit();
    }

    try (SeqInt seq = new SeqInt()) {
      seq.add(1);
      seq.add(2);
      seq.add(3);
      check(seq.len() == 3, "SeqInt len");
      check(seq.get(0) == 1 && seq.get(1) == 2 && seq.get(2) == 3, "SeqInt get");
      seq.set(1, 20);
      check(seq.get(1) == 20, "SeqInt set");
      seq.delete(0);
      check(seq.len() == 2, "SeqInt delete");
      seq.clear();
      check(seq.len() == 0, "SeqInt clear");
    }

    try (RefObjWithSeq r = new RefObjWithSeq()) {
      r.dataAdd((byte)7);
      r.dataAdd((byte)8);
      check(r.dataLen() == 2 && r.dataGet(1) == 8, "RefObjWithSeq data");
    }

    new SimpleObjWithProc(1, (byte)2, false).extraProc();
    check(true, "SimpleObjWithProc.extraProc");

    try (SeqString datas = Test.getDatas()) {
      check(datas.len() == 3, "getDatas len");
      check(datas.get(0).equals("a") && datas.get(2).equals("c"), "getDatas get");
    }

    System.out.println("All Java standard tests passed");
  }
}
