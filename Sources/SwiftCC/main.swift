import os
nonisolated(unsafe) var userInput = ""


func printInstruction(op: String, args: String...) {
  print("\t\(op)\t\(args.joined(separator: ", "))")
}


@inlinable func printErrorAt(_ userInput: String, pos: Int, msg: String) -> Never {
  print(userInput)
  print(String(repeating: " ", count: pos) + "^ \(msg)")
  exit(1)
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
print(n)
exit(0)

print(".global _main")
print("_main:")

printInstruction(op: "mov", args: "w0", "#\(expectNumber(&head))")

while !atEOF(head) {
  if consume(&head, op: "+") {
    printInstruction(op: "add", args: "w0", "w0", "#\(expectNumber(&head))")
    continue
  }
  expect(&head, op: "-")
  printInstruction(op: "sub", args: "w0", "w0", "#\(expectNumber(&head))")
}

print("\tret")
exit(0)
