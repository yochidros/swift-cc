struct CodeGenContext {
  var localVariables: Variable?
  var labelSeq: Int = 0
  var functionName: String?
}

func codeGen(program: Function) {

  var head: Function? = program
  while let h = head {
    print(".global _\(h.name)")
    print("_\(h.name):")

    // prologue
    print("\t// prologue")
    printInstruction(op: "stp", args: "fp", "lr", "[sp, #-16]!", comment: "push fp and lr")
    printInstruction(op: "mov", args: "fp", "sp", comment: "set new frame pointer")
    // 16の倍数にしないとアライメント境界が不正になる
    printInstruction(op: "sub", args: "sp", "sp", "#\(h.stackSize)", comment: "allocate stack for local variables")
    print()

    var params = h.params
    var i = 0
    while params != nil {
      let variable = params!.variable!
      printInstruction(op: "str", args: "x\(i)", "[sp, #\(variable.offset)]", comment: "store parameter \(variable.name)")
      i += 1
      params = params!.next?.wrappedValue
    }

    var context = CodeGenContext(functionName: "\(h.name)")
    var node = h.node
    while node != nil {
      generate(&node!, context: &context, isRoot: true)
      node = node?.next?.wrappedValue
      print()
    }

    // epilogue
    print("\t// epilogue")
    print(".Lreturn.\(h.name):")
    if h.stackSize > 0 {
      printInstruction(op: "mov", args: "sp", "fp", comment: "restore sp")
      printInstruction(op: "ldp", args: "fp", "lr", "[sp], #16", comment: "pop fp and lr")
    }
    print("\tret")
    head = h.next?.wrappedValue
  }
}

func generate(_ node: inout Node, context: inout CodeGenContext, isRoot: Bool = true) {
  switch node.kind {
  case .ret:
    generate(&node.lhs!.wrappedValue, context: &context, isRoot: false)
    printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop result")
    printInstruction(op: "b", args: ".Lreturn.\(context.functionName!)", comment: "return \(context.functionName!)")
    return
  case .block:
    var tmp = node.lhs?.wrappedValue
    print()
    print("\t// block start -->")
    print()
    while tmp != nil {
      generate(&tmp!, context: &context, isRoot: false)
      tmp = tmp?.next?.wrappedValue
    }
    print("\t// <-- block end")
    print()
    return
  case .functionCall:
    var n = 0
    var args = node.args?.wrappedValue
    while var next = args {
      generate(&next, context: &context, isRoot: false)
      n += 1
      args = next.next?.wrappedValue
    }
    print()
    for i in 0..<min(6, n) {
      printInstruction(op: "ldr", args: "x\(i)", "[sp], #16", comment: "pop argument \(i)")
    }
    print()
    printInstruction(op: "bl", args: "_\(node.functionName!)", comment: "call _\(node.functionName!)()")
    printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push return value")
    return

  case .`if`:
    context.labelSeq += 1
    if let e = node.else {
      generate(&node.condition!.wrappedValue, context: &context, isRoot: false)
      printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop result")
      printInstruction(op: "cmp", args: "x0", "#0")
      printInstruction(op: "beq", args: ".Lelse\(context.labelSeq)")
      generate(&node.then!.wrappedValue, context: &context, isRoot: false)
      printInstruction(op: "b", args: ".Lend\(context.labelSeq)")
      print(".Lelse\(context.labelSeq):")
      generate(&e.wrappedValue, context: &context, isRoot: false)
      print(".Lend\(context.labelSeq):")
    } else {
      generate(&node.condition!.wrappedValue, context: &context, isRoot: false)
      printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop result")
      printInstruction(op: "cmp", args: "x0", "#0")
      printInstruction(op: "beq", args: ".Lend\(context.labelSeq)")
      generate(&node.then!.wrappedValue, context: &context, isRoot: false)
      print()
      print(".Lend\(context.labelSeq):")
    }
    return
  case .`while`:
    context.labelSeq += 1
    print(".Lbegin\(context.labelSeq):")
    generate(&node.condition!.wrappedValue, context: &context, isRoot: false)
    printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop result")
    printInstruction(op: "cmp", args: "x0", "#0")
    printInstruction(op: "beq", args: ".Lend\(context.labelSeq)")
    generate(&node.then!.wrappedValue, context: &context, isRoot: false)
    printInstruction(op: "b", args: ".Lbegin\(context.labelSeq)")
    print(".Lend\(context.labelSeq):")
    return
  case .`for`:
    context.labelSeq += 1
    if let e = node.lhs {
      generate(&e.wrappedValue, context: &context, isRoot: false)
    }
    print(".Lbegin\(context.labelSeq):")
    if let e = node.condition {
      generate(&e.wrappedValue, context: &context, isRoot: false)
      printInstruction(op: "ldr", args: "x0", "[sp], #16", comment: "pop result")
      printInstruction(op: "cmp", args: "x0", "#0")
      printInstruction(op: "beq", args: ".Lend\(context.labelSeq)")
    }
    generate(&node.then!.wrappedValue, context: &context, isRoot: false)
    if let e = node.rhs {
      generate(&e.wrappedValue, context: &context, isRoot: false)
    }
    printInstruction(op: "b", args: ".Lbegin\(context.labelSeq)")
    print(".Lend\(context.labelSeq):")
    return
  case .num:
    printInstruction(op: "mov", args: "x0", "#\(node.value!)", comment: "push")
    if !isRoot {
      printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push")
    }
    return
  case .`var`:
    generateLValue(&node)
    loadLValue()
    print()
    return
  case .assign:
    generateLValue(&node.lhs!.wrappedValue)
    generate(&node.rhs!.wrappedValue, context: &context, isRoot: false)
    storeLValue()
    print()
    return
  default:
    break
  }

  generate(&node.lhs!.wrappedValue, context: &context, isRoot: false)
  generate(&node.rhs!.wrappedValue, context: &context, isRoot: false)

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
  guard node.kind == .`var`, let val = node.variable else {
    printErrorAt("", pos: nil, msg: "not an variable")
  }
  printInstruction(op: "mov", args: "x0", "fp")
  printInstruction(op: "sub", args: "x0", "x0","#\(val.offset)")
  printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push address as '\(node.rawValue ?? "")'")
  print()
}
