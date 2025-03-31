
func generate(_ node: inout Node, isRoot: Bool = true) {
  switch node.kind {
  case .num:
    printInstruction(op: "mov", args: "x0", "#\(node.value!)", comment: "push")
    if !isRoot {
      printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push")
    }
    return
  case .lvar:
    generateLValue(&node)
    loadLValue()
    print()
    return
  case .assign:
    generateLValue(&node.lhs!.wrappedValue)
    generate(&node.rhs!.wrappedValue, isRoot: false)
    storeLValue()
    print()
    return
  default:
    break
  }

  generate(&node.lhs!.wrappedValue, isRoot: false)
  generate(&node.rhs!.wrappedValue, isRoot: false)

  printInstruction(op: "ldr", args: "x1", "[sp], #16", comment: "pop")
  printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop")

  switch node.kind {
  case .add:
    printInstruction(op: "add", args: "x0", "x0", "x1")
  case .sub:
    printInstruction(op: "sub", args: "x0", "x0", "x1")
  case .mul:
    printInstruction(op: "mul", args: "x0", "x0", "x1")
  case .div:
    printInstruction(op: "sdiv", args: "x0", "x0", "x1")
  case .eq:
    printInstruction(op: "cmp", args: "x0", "x1")
    printInstruction(op: "cset", args: "w0", "eq")
  case .neq:
    printInstruction(op: "cmp", args: "x0", "x1")
    printInstruction(op: "cset", args: "w0", "ne")
  case .lt:
    printInstruction(op: "cmp", args: "x0", "x1")
    printInstruction(op: "cset", args: "w0", "lt")
  case .lte:
    printInstruction(op: "cmp", args: "x0", "x1")
    printInstruction(op: "cset", args: "w0", "le")
  case .gt:
    printInstruction(op: "cmp", args: "x0", "x1")
    printInstruction(op: "cset", args: "w0", "gt")
  case .gte:
    printInstruction(op: "cmp", args: "x0", "x1")
    printInstruction(op: "cset", args: "w0", "ge")

  default:
    break
  }

  if !isRoot {
    printInstruction(op: "str", args: "x0", "[sp, #-16]!")
    print()
  }
}
func loadLValue() {
  printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop address")
  printInstruction(op: "ldr", args: "x0", "[x0]", comment: "load value")
  printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push value")
}

func storeLValue() {
  print("\t// store local variable result")
  printInstruction(op: "ldr", args: "x1", "[sp], #16", comment: "pop")
  printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop")
  printInstruction(op: "str", args: "x1", "[x0]")
}

func generateLValue(_ node: inout Node) {
  if node.kind != .lvar {
    printErrorAt("", pos: nil, msg: "not an lvalue")
  }
  printInstruction(op: "mov", args: "x0", "fp")
  printInstruction(op: "sub", args: "x0", "x0","#\(node.offset!)")
  printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push address as '\(node.rawValue ?? "")'")
  print()
}
