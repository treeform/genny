import generated/refs

var child: Child
doAssert childrenDestroyed() == 0
block:
  let parent = newParent()
  doAssert parent.child == nil
  parent.createChild()
  child = parent.child
  doAssert child.value == 42
  parent.child = child
  parent.child = nil
  doAssert parent.child == nil
  doAssert child.value == 42

# The returned reference stays alive after its parent and original wrapper.
doAssert child.value == 42
child.value = 7
doAssert child.value == 7
child = nil
doAssert childrenDestroyed() == 1
echo "Reference fields passed"
