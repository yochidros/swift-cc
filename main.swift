import os
var userInput = ""

enum TokenKind: String {
  case number
  case reserved
  case eof
}

@propertyWrapper
final class Ref<T: Equatable>: Equatable {
  private var value: T

  var wrappedValue: T {
    get { value }
    set { value = newValue }
  }

  init(_ value: T) {
    self.value = value
  }

  subscript<U>(keyPath: WritableKeyPath<T, U>) -> U {
    get { value[keyPath: keyPath] }
    set { value[keyPath: keyPath] = newValue }
  }

  static func == (lhs: Ref<T>, rhs: Ref<T>) -> Bool {
    return lhs.value == rhs.value
  }
}

struct Token: CustomDebugStringConvertible, Equatable {
  let kind: TokenKind
  let str: String

  var number: Int?

  var next: Ref<Token>?

  var pos: Int

  init(kind: TokenKind, str: String, number: Int? = nil, pos: Int) {
    self.kind = kind
    self.str = str
    self.pos = pos
    self.number = number
  }

  @discardableResult
  mutating func setEdge(_ newValue: Token) -> Bool {
    guard next == nil else {
      if next?.wrappedValue.setEdge(newValue) == true {
        return true
      }
      return false
    }
    next = Ref(newValue)
    return true
  }

  var debugDescription: String {
    if let next {
      if kind == .eof {
        return "\(kind) -> \(next.wrappedValue)"
        } else {
          return "\(kind)(\(str)) -> \(next.wrappedValue)"
        }
      } else {
        if kind == .eof {
          return "\(kind)"
          } else {
            return "\(kind)(\(str))"
          }
      }
  }
}

func printInstruction(op: String, args: String...) {
  print("\t\(op)\t\(args.joined(separator: ", "))")
}

func consume(_ cur: inout Token?, op: String) -> Bool {
  if cur?.kind != .reserved || cur?.str != op {
    return false
  }
  cur = cur?.next?.wrappedValue
  return true
}

func expect(_ cur: inout Token?, op: String) {
  if cur?.kind != .reserved || cur?.str != op {
    printErrorAt(userInput, pos: cur!.pos, msg: "not number \(cur!.str)")
  }
  cur = cur?.next?.wrappedValue
}

func expectNumber(_ cur: inout Token?) -> Int {
  guard let num = cur?.number, cur?.kind == .number else {
    printErrorAt(userInput, pos: cur!.pos, msg: "not number \(cur!.str)")
  }
  cur = cur?.next?.wrappedValue
  return num
}

func newToken(cur: inout Token, kind: TokenKind, str: String, number: Int? = nil, pos: Int) {
  let new = Token(kind: kind, str: str, number: number, pos: pos)
  cur.setEdge(new)
}

func atEOF(_ cur: Token?) -> Bool {
  return cur?.kind == .eof
}

func tokenize(_ str: String) -> Token? {
  var cur: Token = .init(kind: .eof, str: "", pos: 0)
  var index = str.startIndex

  while index != str.endIndex {
    let c = str[index]

    if c.isWhitespace {
      index = str.index(after: index)
      continue
    }

    if str[index] == "+" || str[index] == "-" {
      let op = str[index ... index]
      let pos = str.distance(from: str.startIndex, to: index)
      newToken(cur: &cur, kind: .reserved, str: .init(op), pos: pos)
      index = str.index(after: index)
      continue
    }

    if c.isNumber {
      let start = index
      while index != str.endIndex, str[index].isNumber {
        index = str.index(after: index)
      }
      let numStr = str[start ..< index]
    let pos = str.distance(from: str.startIndex, to: index)
      newToken(cur: &cur, kind: .number, str: .init(numStr), number: Int(numStr), pos: pos)
      continue
    }
    let pos = str.distance(from: str.startIndex, to: index)
    printErrorAt(userInput, pos: pos, msg: "invalid token")
  }
  cur.setEdge(Token(kind: .eof, str: "", pos: str.count))
  return cur.next!.wrappedValue
}


@inlinable func printErrorAt(_ userInput: String, pos: Int, msg: String) -> Never {
  print(userInput)
  print(String(repeating: " ", count: pos) + "^ \(msg)")
  exit(1)
}

func main() {
  let args = CommandLine.arguments

  guard args.count == 2 else {
    print("\(args[0]): invalid number of arguments")
    exit(1)
  }

  let str = args[1]
  userInput = str

  var head = tokenize(str)

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
}

main()
