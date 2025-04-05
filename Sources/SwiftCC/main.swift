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
var f = makeProgram(&token)
if args.contains("-D") {
  print(f)
}

codeGen(program: f)

exit(0)
