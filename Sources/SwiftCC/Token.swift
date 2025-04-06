
enum TokenKind: String {
  case number
  case reserved
  case identifier
  case eof
}

struct Token: CustomDebugStringConvertible, Equatable {
  let kind: TokenKind
  let str: String
  let length: Int

  // has only when kind == .number
  var number: Int?

  var next: Ref<Token>?

  var pos: Int

  init(kind: TokenKind, str: String, number: Int? = nil, pos: Int) {
    self.kind = kind
    self.str = str
    self.length = str.count
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
          return "\(kind)('\(str)') -> \(next.wrappedValue)"
        }
      } else {
        if kind == .eof {
          return "\(kind)"
          } else {
            return "\(kind)('\(str)')"
          }
      }
  }
}

func consume(_ cur: inout Token?, op: String) -> Bool {
  if cur?.kind != .reserved || cur?.length != op.count || cur?.str != op {
    return false
  }
  cur = cur?.next?.wrappedValue
  return true
}

func consumeIndentifer(_ cur: inout Token?) -> Token? {
  if cur?.kind != .identifier {
    return nil
  }
  let ident = cur
  cur = cur?.next?.wrappedValue
  return ident
}

func expectIndentifer(_ cur: inout Token?) -> String {
  guard let token = cur, token.kind == .identifier else {
    printErrorAt(userInput, pos: cur!.pos, msg: "not identifier \(cur!.str)")
  }
  cur = token.next?.wrappedValue
  return token.str
}


func expect(_ cur: inout Token?, op: String) {
  if cur?.kind != .reserved || cur?.length != op.count || cur?.str != op {
    printErrorAt(userInput, pos: cur!.pos, msg: "'\(op)' is expected. actual is '\(cur!.str)'")
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

func startsWith(_ cur: Substring, prefix: String) -> Bool {
  guard cur.count >= prefix.count else {
    return false
  }
  let se = cur.index(cur.startIndex, offsetBy: prefix.count)
  let base =  cur[cur.startIndex ..< se]
  return base == prefix
}
func isAlnum(_ c: Character) -> Bool {
  return c.isLetter || c.isNumber || c == "_"
}

func startWithReserved(_ cur: Substring) -> String? {
  let keyword = ["return", "if", "else", "while", "for"]
  for k in keyword where k.count <= cur.count {
    let i = cur.index(cur.startIndex, offsetBy: k.count)
    if startsWith(cur, prefix: k), !isAlnum(cur[i]) {
      return k
    }
  }

  let ops = ["==", "!=", "<=", ">="]
  for op in ops where op.count <= cur.count {
    if startsWith(cur, prefix: op) {
      return op
    }
  }
  return nil
}

func tokenize(_ str: String) -> Token? {
  var cur: Token = Token(kind: .eof, str: "", pos: 0)
  var index = str.startIndex

  while index != str.endIndex {
    let c = str[index]

    if c.isWhitespace {
      index = str.index(after: index)
      continue
    }

    if let keyword = startWithReserved(str[index...]) {
      newToken(cur: &cur, kind: .reserved, str: keyword, pos: str.distance(from: str.startIndex, to: index))
      index = str.index(index, offsetBy: keyword.count)
      continue
    }

    if "a" <= c && c <= "z" {
      let start = index
      while index != str.endIndex, isAlnum(str[index]) {
        index = str.index(after: index)
      }
      let idStr = str[start ..< index]
      let pos = str.distance(from: str.startIndex, to: start)
      newToken(cur: &cur, kind: .identifier, str: .init(idStr), pos: pos)
      continue
    }

    if "+-*/()<>=;,{}&".contains(str[index]) {
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
  return cur.next?.wrappedValue
}
