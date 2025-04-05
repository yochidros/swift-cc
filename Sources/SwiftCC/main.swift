import os

nonisolated(unsafe) var userInput = ""

let args = CommandLine.arguments

guard args.count > 1 else {
  print("\(args[0]): invalid number of arguments")
  exit(1)
}

let str = args[1]
userInput = str

var token = tokenize(str)
if args.contains("-D") {
  print(token ?? "")
}
var program = makeProgram(&token)
if args.contains("-D") {
  print(program)
}
if let stackSize = program.variable?.offset {
  // adjust memory align to 16 bytes.
  if stackSize % 16 != 0 {
    program.stackSize = stackSize + (16 - stackSize % 16)
  } else {
    program.stackSize = stackSize
  }
}

codeGen(program: program)

exit(0)
