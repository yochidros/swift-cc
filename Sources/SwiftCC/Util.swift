import os

func printInstruction(op: String, args: String..., comment: String = "") {
  let inst = "\(op)\t\(args.joined(separator: ", "))"
  let comment = comment.isEmpty ? "" : " // \(comment)"
  print("\t\(inst)\(comment)")
}

@inlinable func printErrorAt(_ userInput: String, pos: Int?, msg: String) -> Never {
  print(userInput)
  if let pos {
    print(String(repeating: " ", count: pos) + "^ \(msg)")
  } else {
    print(msg)
  }
  exit(1)
}
