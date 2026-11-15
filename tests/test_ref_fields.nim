import genny

type
  ChildObj = object
    value: int
  Child = ref ChildObj
  Parent = ref object
    child: Child

var destroyed: int

when NimMajor < 2:
  proc `=destroy`(child: var ChildObj) =
    ## Tracks native child disposal.
    inc destroyed
else:
  proc `=destroy`(child: ChildObj) =
    ## Tracks native child disposal.
    inc destroyed

proc childrenDestroyed(): int =
  ## Returns the number of native children released.
  destroyed

proc newParent(): Parent =
  ## Creates a parent with an empty reference field.
  Parent()

proc createChild(parent: Parent) =
  ## Creates a child owned only by its parent.
  parent.child = Child(value: 42)

exportRefObject Child:
  fields:
    value

exportRefObject Parent:
  fields:
    child
  constructor:
    newParent()
  procs:
    createChild

exportProcs:
  childrenDestroyed

writeFiles("tests/generated", "refs")

include generated/internal
