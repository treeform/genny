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

    std::cout << "Testing SeqString via getDatas" << std::endl;
    SeqString datas = getDatas();
    datas.free();

    std::cout << "All C++ tests passed!" << std::endl;
    return 0;
}
