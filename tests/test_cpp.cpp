// Test C++ bindings.
#include <iostream>
#include <cassert>
#include "test.hpp"

int main() {
    std::cout << "Testing C++ bindings" << std::endl;

    std::cout << "Testing simpleCall" << std::endl;
    assert(simpleCall(42) == 42);
    assert(simpleCall(0) == 0);

    std::cout << "Testing SIMPLE_CONST" << std::endl;
    assert(SIMPLE_CONST == 123);

    std::cout << "Testing SimpleObj" << std::endl;
    SimpleObj obj = simpleObj(10, 20, true);
    assert(obj.simple_a == 10);
    assert(obj.simple_b == 20);
    assert(obj.simple_c == true);

    std::cout << "Testing SimpleRefObj" << std::endl;
    SimpleRefObj refObj;
    refObj.setSimpleRefA(100);
    assert(refObj.getSimpleRefA() == 100);
    refObj.setSimpleRefB(50);
    assert(refObj.getSimpleRefB() == 50);
    refObj.doit();
    refObj.free();

    std::cout << "Testing SeqInt" << std::endl;
    SeqInt seqInt;
    seqInt.add(1);
    seqInt.add(2);
    seqInt.set(1, 20);
    assert(seqInt.size() == 2);
    assert(seqInt.get(0) == 1);
    assert(seqInt[1] == 20);
    seqInt.removeAt(0);
    assert(seqInt.size() == 1);
    seqInt.clear();
    assert(seqInt.size() == 0);
    seqInt.free();

    std::cout << "Testing RefObjWithSeq" << std::endl;
    RefObjWithSeq refObjWithSeq;
    refObjWithSeq.addData(7);
    assert(refObjWithSeq.dataSize() == 1);
    assert(refObjWithSeq.getData(0) == 7);
    refObjWithSeq.setData(0, 8);
    assert(refObjWithSeq.getData(0) == 8);
    refObjWithSeq.removeData(0);
    assert(refObjWithSeq.dataSize() == 0);
    refObjWithSeq.free();

    std::cout << "Testing SeqString via getDatas" << std::endl;
    SeqString datas = getDatas();
    assert(datas.size() == 3);
    assert(datas[0][0] == 'a');
    datas.free();

    std::cout << "All C++ tests passed!" << std::endl;
    return 0;
}
