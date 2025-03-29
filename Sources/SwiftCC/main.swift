import os
nonisolated(unsafe) var userInput = ""


func printInstruction(op: String, args: String..., comment: String = "") {
  let inst = "\(op)\t\(args.joined(separator: ", "))"
  let comment = comment.isEmpty ? "" : " // \(comment)"
  print("\t\(inst)\(comment)")
}


@inlinable func printErrorAt(_ userInput: String, pos: Int, msg: String) -> Never {
  print(userInput)
  print(String(repeating: " ", count: pos) + "^ \(msg)")
  exit(1)
}

func generate(_ node: inout Node, isRoot: Bool = true) {
  if node.kind == .num {
    printInstruction(op: "mov", args: "x0", "#\(node.value!)", comment: "push")
    if !isRoot {
      printInstruction(op: "str", args: "x0", "[sp, #-16]!", comment: "push")
    }
    return
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
  default:
    break
  }

  if !isRoot {
    printInstruction(op: "str", args: "x0", "[sp, #-16]!")
    print()
  }
}

let args = CommandLine.arguments

guard args.count == 2 else {
  print("\(args[0]): invalid number of arguments")
  exit(1)
}

let str = args[1]
userInput = str

var head = tokenize(str)

var n = makeExpr(&head)

print(".global _main")
print("_main:")

generate(&n)

print("\tret")
exit(0)
