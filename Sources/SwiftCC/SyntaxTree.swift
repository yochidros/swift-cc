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
  case `var` // variable
  case num // number
  case ret // return
  case `if` // if
  case `while` // while
  case `for` // for
  case block // block
  case functionCall // function call
}

struct Node: Equatable {
  var kind: NodeKind
  var lhs: Ref<Node>?
  var rhs: Ref<Node>?

  /// has only when kind == .num
  var value: Int?

  /// has only when kind == .var
  var variable: Variable?

  var rawValue: String?

  var next: Ref<Node>?

  // has only when kind == .functionCall
  var functionName: String?
  var args: Ref<Node>?

  // has only when kind == .if
  var condition: Ref<Node>?
  var then: Ref<Node>?
  var `else`: Ref<Node>?
}

extension Node: CustomDebugStringConvertible {
  var debugDescription: String {
    switch kind {
    case .num:
      return "\(value!)"
    case .`var`:
      return "var '\(rawValue!)'[\(variable!.offset)]"
    case .ret:
      return "(ret \(lhs!.wrappedValue.debugDescription))"
    case .if:
      return "(if \(condition!.wrappedValue.debugDescription) \(then!.wrappedValue.debugDescription) \(`else`?.wrappedValue.debugDescription ?? ""))"
    case .`while`:
      return "(while \(condition!.wrappedValue.debugDescription) \(then!.wrappedValue.debugDescription))"
    case .`for`:
      return "(for \(lhs?.wrappedValue.debugDescription ?? "") \(condition?.wrappedValue.debugDescription ?? "") \(rhs?.wrappedValue.debugDescription ?? "") \(then!.wrappedValue.debugDescription)"
    case .block:
      var str = ""
      var cur = lhs
      while let n = cur {
        str += "\(n.wrappedValue.debugDescription) "
        cur = n.wrappedValue.next
      }
      return "({ \(str) })"
    default:
      if lhs == nil || rhs == nil {
        return "(\(kind))"
      }
      return "(\(lhs!.wrappedValue.debugDescription) \(kind) \(rhs!.wrappedValue.debugDescription))"
    }
  }
}
extension Node {
  func toRef() -> Ref<Node> {
    return Ref(self)
  }
}

struct Variable: Equatable {
  var name: String
  var offset: Int // offset from RBP
  var next: Ref<Variable>?
}

extension Variable: CustomDebugStringConvertible {
  var debugDescription: String {
    if let next {
      return "\(name)[\(offset)] -> \(next.wrappedValue)"
    } else {
      return "\(name)[\(offset)]"
    }
  }
}

struct Program {
  var node: Node?
  var variable: Variable?
  var stackSize: Int = 0
}

func findVariable(from token: Token?, vars root: Variable?) -> Variable? {
  var cur = root
  while let l = cur {
    if l.name == token?.str {
      return l
    }
    cur = cur?.next?.wrappedValue
  }
  return nil
}

func newNode(kind: NodeKind, lhs: Node, rhs: Node) -> Node {
  return Node(kind: kind, lhs: .init(lhs), rhs: .init(rhs))
}

func newNodeNum(_ value: Int) -> Node {
  return Node(kind: .num, lhs: nil, rhs: nil, value: value)
}

/// program    = stmt*
func makeProgram(_ token: inout Token?) -> Program {
  var nodes: [Node] = []
  var variable: Variable?
  while !atEOF(token) {
    nodes.append(makeStmt(&token, &variable))
  }

  var program = Program()
  var tmp: Node?
  for var node in nodes.reversed() {
    node.next = tmp?.toRef()
    tmp = .init(node)
  }
  program.node = tmp
  program.variable = variable
  return program
}

/// stmt       = expr ";"
///              | "{" stmt* "}"
///              | "if" "(" expr ")" stmt ("else" stmt)?
///              | "while" "(" expr ")" stmt
///              | "for" "(" expr? ";" expr? ";" expr? ")" stmt
///              | "return" expr ";"
func makeStmt(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  if consume(&token, op: "return") {
    var node = Node(kind: .ret, lhs: nil, rhs: nil)
    node.lhs = Ref(makeExpr(&token, &variable))
    expect(&token, op: ";")
    return node
  }
  if consume(&token, op: "if") {
    expect(&token, op: "(")
    var node = Node(kind: .`if`)
    node.condition = Ref(makeExpr(&token, &variable))
    expect(&token, op: ")")
    node.then = Ref(makeStmt(&token, &variable))
    if consume(&token, op: "else") {
      node.else = Ref(makeStmt(&token, &variable))
    }
    return node
  }

  if consume(&token, op: "while") {
    expect(&token, op: "(")
    var node = Node(kind: .`while`)
    node.condition = Ref(makeExpr(&token, &variable))
    expect(&token, op: ")")
    node.then = Ref(makeStmt(&token, &variable))
    return node
  }

  if consume(&token, op: "for") {
    expect(&token, op: "(")
    var node = Node(kind: .`for`)
    if !consume(&token, op: ";") {
      node.lhs = Ref(makeExpr(&token, &variable))
      expect(&token, op: ";")
    }
    if !consume(&token, op: ";") {
      node.condition = Ref(makeExpr(&token, &variable))
      expect(&token, op: ";")
    }
    if !consume(&token, op: ")") {
      node.rhs = Ref(makeExpr(&token, &variable))
      expect(&token, op: ")")
    }
    node.then = Ref(makeStmt(&token, &variable))
    return node
  }

  if consume(&token, op: "{") {
    var bodies: [Node] = []
    while !consume(&token, op: "}") {
      bodies.append(makeStmt(&token, &variable))
    }
    var tmp: Ref<Node>?
    for var b in bodies.reversed() {
      b.next = tmp
      tmp = .init(b)
    }
    return Node(kind: .block, lhs: tmp, rhs: nil)
  }

  let node = makeExpr(&token, &variable)
  expect(&token, op: ";")
  return node
}

/// expr       = assign
func makeExpr(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  return makeAssign(&token, &variable)
}

/// assign     = equality ("=" assign)?
func makeAssign(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  var node = makeEquality(&token, &variable)
  if consume(&token, op: "=") {
    node = newNode(kind: .assign, lhs: node, rhs: makeAssign(&token, &variable))
  }
  return node
}

/// equality   = relational ("==" relational | "!=" relational)*
func makeEquality(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  var node = makeRelational(&token, &variable)
  while token != nil {
    if consume(&token, op: "==") {
      node = newNode(kind: .eq, lhs: node, rhs: makeRelational(&token, &variable))
    } else if consume(&token, op: "!=") {
      node = newNode(kind: .neq, lhs: node, rhs: makeRelational(&token, &variable))
    } else {
      break
    }
  }
  return node
}
/// relational = add ("<" add | "<=" add | ">" add | ">=" add)*
func makeRelational(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  var node = makeAdd(&token, &variable)
  while token != nil {
    if consume(&token, op: "<") {
      node = newNode(kind: .lt, lhs: node, rhs: makeAdd(&token, &variable))
    } else if consume(&token, op: "<=") {
      node = newNode(kind: .lte, lhs: node, rhs: makeAdd(&token, &variable))
    } else if consume(&token, op: ">") {
      node = newNode(kind: .gt, lhs: node, rhs: makeAdd(&token, &variable))
    } else if consume(&token, op: ">=") {
      node = newNode(kind: .gte, lhs: node, rhs: makeAdd(&token, &variable))
    } else {
      break
    }
  }
  return node
}
/// add        = mul ("+" mul | "-" mul)*
func makeAdd(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  var mul = makeMul(&token, &variable)
  while token != nil {
    if consume(&token, op: "+") {
      mul = newNode(kind: .add, lhs: mul, rhs: makeMul(&token, &variable))
    } else if consume(&token, op: "-") {
      mul = newNode(kind: .sub, lhs: mul, rhs: makeMul(&token, &variable))
    } else {
      break
    }
  }
  return mul
}

/// mul     = unary ("*" unary | "/" unary)*
func makeMul(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  var unary = makeUnary(&token, &variable)

  while token != nil {
    if consume(&token, op: "*") {
      unary = newNode(kind: .mul, lhs: unary, rhs: makeUnary(&token, &variable))
    } else if consume(&token, op: "/") {
      unary = newNode(kind: .div, lhs: unary, rhs: makeUnary(&token, &variable))
    } else {
      break
    }
  }
  return unary
}

/// primary    = num
///              | identifier ("(" ")")?
///              | "(" expr ")"
func makePrimary(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  if consume(&token, op: "(") {
    let expr = makeExpr(&token, &variable)
    expect(&token, op: ")")
    return expr
  }

  if let identifier = consumeIndentifer(&token) {
    if consume(&token, op: "(") {
      var n = Node(kind: .functionCall, lhs: nil, rhs: nil)
      n.functionName = identifier.str
      n.args = makeFuncArgs(&token, &variable)?.toRef()
      return n
    }

    let foundVar = findVariable(from: identifier, vars: variable)
    var node = Node(kind: .var, lhs: nil, rhs: nil, rawValue: identifier.str)
    if let foundVar {
      node.variable = foundVar
    } else {
      var v = Variable(name: identifier.str, offset: 8)
      if let _var = variable {
        v.next = Ref<Variable>(_var)
        v.offset = _var.offset + 8;
        node.variable = v
        variable = v
      } else {
        node.variable = v
        variable = v
      }
    }
    return node
  }

  let num = newNodeNum(expectNumber(&token))
  return num
}
/// unary   = ("+" | "-")? primary
func makeUnary(_ token: inout Token?, _ variable: inout Variable?) -> Node {
  if consume(&token, op: "+") {
    return makeUnary(&token, &variable)
  } else if consume(&token, op: "-") {
    return newNode(kind: .sub, lhs: newNodeNum(0), rhs: makeUnary(&token, &variable))
  } else {
    return makePrimary(&token, &variable)
  }
}

/// func-args = "(" (assign ("," assign)*)? ")"
func makeFuncArgs(_ token: inout Token?, _ variable: inout Variable?) -> Node? {
  guard !consume(&token, op: ")") else {
    return nil
  }
  var args: [Node] = [makeAssign(&token, &variable)]
  while consume(&token, op: ",") {
    args.append(makeAssign(&token, &variable))
  }
  expect(&token, op: ")")

  var tmp: Node?
  for var arg in args.reversed() {
    arg.next = tmp?.toRef()
    tmp = .init(arg)
  }
  return tmp
}
