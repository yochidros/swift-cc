
enum NodeKind {
  case add // +
  case sub // -
  case mul // *
  case div // /
  case eq  // ==
  case neq // !=
  case lt  // <
  case lte  // <=
  case gt  // >
  case gte // >=

  case assign // =
  case lvar // local variable
  case num // number
}

struct Node: Equatable {
  var kind: NodeKind
  var lhs: Ref<Node>?
  var rhs: Ref<Node>?

  /// has only when kind == .num
  var value: Int?

  /// has only when kind == .lvar
  var offset: Int?

  var rawValue: String?
}

extension Node: CustomDebugStringConvertible {
  var debugDescription: String {
    switch kind {
    case .num:
      return "\(value!)"
    case .lvar:
      return "lvar '\(rawValue!)'"
    default:
      if lhs == nil || rhs == nil {
        return "(\(kind))"
      }
      return "(\(lhs!.wrappedValue.debugDescription) \(kind) \(rhs!.wrappedValue.debugDescription))"
    }
  }
}

func newNode(kind: NodeKind, lhs: Node, rhs: Node) -> Node {
  return Node(kind: kind, lhs: .init(lhs), rhs: .init(rhs))
}
func newNodeNum(_ value: Int) -> Node {
  return Node(kind: .num, lhs: nil, rhs: nil, value: value)
}
/// program    = stmt*
func makeProgram(_ token: inout Token?) -> [Node] {
  var nodes: [Node] = []
  while !atEOF(token) {
    nodes.append(makeStmt(&token))
  }
  return nodes
}

/// stmt       = expr ";"
func makeStmt(_ token: inout Token?) -> Node {
  let node = makeExpr(&token)
  expect(&token, op: ";")
  return node
}

/// expr       = assign
func makeExpr(_ token: inout Token?) -> Node {
  return makeAssign(&token)
}

/// assign     = equality ("=" assign)?
func makeAssign(_ token: inout Token?) -> Node {
  var node = makeEquality(&token)
  if consume(&token, op: "=") {
    node = newNode(kind: .assign, lhs: node, rhs: makeAssign(&token))
  }
  return node
}

/// equality   = relational ("==" relational | "!=" relational)*
func makeEquality(_ token: inout Token?) -> Node {
  var node = makeRelational(&token)
  while token != nil {
    if consume(&token, op: "==") {
      node = newNode(kind: .eq, lhs: node, rhs: makeRelational(&token))
    } else if consume(&token, op: "!=") {
      node = newNode(kind: .neq, lhs: node, rhs: makeRelational(&token))
    } else {
      break
    }
  }
  return node
}
/// relational = add ("<" add | "<=" add | ">" add | ">=" add)*
func makeRelational(_ token: inout Token?) -> Node {
  var node = makeAdd(&token)
  while token != nil {
    if consume(&token, op: "<") {
      node = newNode(kind: .lt, lhs: node, rhs: makeAdd(&token))
    } else if consume(&token, op: "<=") {
      node = newNode(kind: .lte, lhs: node, rhs: makeAdd(&token))
    } else if consume(&token, op: ">") {
      node = newNode(kind: .gt, lhs: node, rhs: makeAdd(&token))
    } else if consume(&token, op: ">=") {
      node = newNode(kind: .gte, lhs: node, rhs: makeAdd(&token))
    } else {
      break
    }
  }
  return node
}
/// add        = mul ("+" mul | "-" mul)*
func makeAdd(_ token: inout Token?) -> Node {
  var mul = makeMul(&token)
  while token != nil {
    if consume(&token, op: "+") {
      mul = newNode(kind: .add, lhs: mul, rhs: makeMul(&token))
    } else if consume(&token, op: "-") {
      mul = newNode(kind: .sub, lhs: mul, rhs: makeMul(&token))
    } else {
      break
    }
  }
  return mul
}

/// mul     = unary ("*" unary | "/" unary)*
func makeMul(_ token: inout Token?) -> Node {
  var unary = makeUnary(&token)

  while token != nil {
    if consume(&token, op: "*") {
      unary = newNode(kind: .mul, lhs: unary, rhs: makeUnary(&token))
    } else if consume(&token, op: "/") {
      unary = newNode(kind: .div, lhs: unary, rhs: makeUnary(&token))
    } else {
      break
    }
  }
  return unary
}

/// primary    = num | identifier | "(" expr ")"
func makePrimary(_ token: inout Token?) -> Node {
  if consume(&token, op: "(") {
    let expr = makeExpr(&token)
    expect(&token, op: ")")
    return expr
  }

  if let identifier = consumeIndentifer(&token) {
    let offset = (Int(identifier.str.utf8.first!) - Int(Character("a").asciiValue!) + 1) * 8
    return Node(kind: .lvar, lhs: nil, rhs: nil, offset: offset, rawValue: identifier.str)
  }

  let num = newNodeNum(expectNumber(&token))
  return num
}
/// unary   = ("+" | "-")? primary
func makeUnary(_ token: inout Token?) -> Node {
  if consume(&token, op: "+") {
    return makeUnary(&token)
  } else if consume(&token, op: "-") {
    return newNode(kind: .sub, lhs: newNodeNum(0), rhs: makeUnary(&token))
  } else {
    return makePrimary(&token)
  }
}
