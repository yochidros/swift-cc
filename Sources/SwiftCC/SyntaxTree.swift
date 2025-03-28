
enum NodeKind {
  case add // +
  case sub // -
  case mul // *
  case div // /
  case num // number
}

struct Node: Equatable {
  var kind: NodeKind
  var lhs: Ref<Node>?
  var rhs: Ref<Node>?

  /// has only when kind == .num
  var value: Int?
}
extension Node: CustomDebugStringConvertible {
  var debugDescription: String {
    switch kind {
    case .num:
      return "\(value!)"
    case .add, .sub, .mul, .div:
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

func makeExpr(_ token: inout Token?) -> Node {
  var mul = makeMul(&token)

  while token != nil {
    if consume(&token, op: "+") {
      let rhs = makeMul(&token)
      mul = newNode(kind: .add, lhs: mul, rhs: rhs)
    } else if consume(&token, op: "-") {
      mul = newNode(kind: .sub, lhs: mul, rhs: makeMul(&token))
    } else {
      break
    }
  }
  return mul
}

func makeMul(_ token: inout Token?) -> Node {
  var primary = makePrimary(&token)

  while token != nil {
    if consume(&token, op: "*") {
      primary = newNode(kind: .mul, lhs: primary, rhs: makePrimary(&token))
    } else if consume(&token, op: "/") {
      primary = newNode(kind: .div, lhs: primary, rhs: makePrimary(&token))
    } else {
      break
    }
  }
  return primary
}

func makePrimary(_ token: inout Token?) -> Node {
  if consume(&token, op: "(") {
    let expr = makeExpr(&token)
    expect(&token, op: ")")
    return expr
  } else {
    let num = newNodeNum(expectNumber(&token))
    return num
  }
}
