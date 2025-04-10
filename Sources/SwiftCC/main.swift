import os
import Foundation

nonisolated(unsafe) var userInput = ""

let args = CommandLine.arguments

guard args.count > 1 else {
  print("\(args[0]): invalid number of arguments")
  exit(1)
}
if args.contains("-raw") {
  if args.count < 3 {
    print("\(args[0]): -raw option requires a file name")
    exit(1)
  }
  userInput = args[2]
} else {
  let fileName = args[1]

  guard let file = FileHandle(forReadingAtPath: fileName) else {
    print("\(args[0]): \(fileName): No such file")
    exit(1)
  }
  let data = file.readDataToEndOfFile()
  userInput = String(data: data, encoding: .utf8) ?? ""
}

var token = tokenize(userInput)
if args.contains("-D") {
  print(token ?? "")
}
var f = makeProgram(&token)
if args.contains("-D") {
  print(f)
}
var v = Optional(f)
addType(&v)

if args.contains("-D") {
  print(v!)
}

codeGen(program: v!)

exit(0)
