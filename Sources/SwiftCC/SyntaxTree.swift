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
  case addr // address
  case deref // dereference
  case exprStmt // expression statement
  case null
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

  var type: Type?

  var body: Ref<Node>?

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
      if let type {
        return "\(type.debugDescription)(\(value!))"
      } else {
        return "\(value!)"
      }
    case .`var`:
      if let type {
        return "\(type.debugDescription)(\(rawValue!))[\(variable!.offset)]"
      } else {
        return "\(rawValue!)[\(variable!.offset)]"
      }
    case .ret:
      if let type {
        return "\(type.debugDescription) return \(lhs!.wrappedValue.debugDescription)"
      } else {
        return "return \(lhs!.wrappedValue.debugDescription)"
      }
    case .if:
      if let type {
        return "\(type.debugDescription) if (\(condition!.wrappedValue.debugDescription)) {\(then!.wrappedValue.debugDescription)} else { \(`else`?.wrappedValue.debugDescription ?? "")}"
      }
      return "if (\(condition!.wrappedValue.debugDescription)) {\(then!.wrappedValue.debugDescription)} else { \(`else`?.wrappedValue.debugDescription ?? "")}"
    case .`while`:
      if let type {
        return "\(type.debugDescription) while \(condition!.wrappedValue.debugDescription) \(then!.wrappedValue.debugDescription)"
      }
      return "(while \(condition!.wrappedValue.debugDescription) \(then!.wrappedValue.debugDescription))"
    case .`for`:
      if let type {
        return "\(type.debugDescription) for \(lhs?.wrappedValue.debugDescription ?? "") \(condition?.wrappedValue.debugDescription ?? "") \(rhs?.wrappedValue.debugDescription ?? "") \(then!.wrappedValue.debugDescription)"
      }
      return "(for \(lhs?.wrappedValue.debugDescription ?? "") \(condition?.wrappedValue.debugDescription ?? "") \(rhs?.wrappedValue.debugDescription ?? "") \(then!.wrappedValue.debugDescription))"
    case .block:
      var str = ""
      var cur = body
      while let n = cur {
        if let ty = n.wrappedValue.type {
          str += "\(ty.debugDescription) \(n.wrappedValue.debugDescription) "
        } else {
          str += "\(n.wrappedValue.debugDescription) "
        }
        cur = n.wrappedValue.next
      }
      return "({ \(str) })"
    case .assign:
      return "\(lhs!.wrappedValue.debugDescription) = \(rhs!.wrappedValue.debugDescription)"
    case .addr:
      if let type {
        return "\(type.debugDescription) (&[\(lhs!.wrappedValue.debugDescription)])"
      }
      return "(&\(lhs!.wrappedValue.debugDescription))"
    case .deref:
      if let type {
        return "\(type.debugDescription) *(\(lhs!.wrappedValue.debugDescription))"
      }
      return "(*\(lhs!.wrappedValue.debugDescription))"
    case .exprStmt:
      return "\( lhs != nil ? lhs!.wrappedValue.debugDescription : "" )"
    default:
      if lhs == nil || rhs == nil {
        return "\(lhs != nil ? lhs!.wrappedValue.debugDescription: "") \(kind) \(rhs != nil ? rhs!.wrappedValue.debugDescription : "")"
      }
      return "\(lhs!.wrappedValue.debugDescription) \(kind) \(rhs!.wrappedValue.debugDescription)"
    }
  }
}
extension Node {
  func toRef() -> Ref<Node> {
    return Ref(self)
  }
}

struct VariableList: Equatable {
  var next: Ref<VariableList>?
  var variable: Variable?
}
extension VariableList {
  func toRef() -> Ref<VariableList> {
    return Ref(self)
  }
}

struct Variable: Equatable {
  var name: String
  var offset: Int

  var type: Ref<Type>?
}

extension Variable: CustomDebugStringConvertible {
  var debugDescription: String {
    return "\(name)[\(offset)]"
  }
}

struct Function: Equatable {
  var node: Node?
  var varList: VariableList?
  var stackSize: Int = 0
  var params: VariableList?
  var name: String = ""
  var next: Ref<Function>?
}
extension Function {
  func toRef() -> Ref<Function> {
    return Ref(self)
  }
}
extension Function: CustomDebugStringConvertible {
  var debugDescription: String {
    var str = ""
    var cur: Node? = node
    while let n = cur {
      str += " \(n.debugDescription)\n"
      cur = n.next?.wrappedValue
    }
    return "function \(name) {\n\(str)}"
  }
}
func readFunctionParams(_ token: inout Token?) -> VariableList? {
  guard !consume(&token, op: ")") else {
      return nil
  }

  func makeParam(_ tok: inout Token?, _ offset: Int?) -> VariableList {
    let ty = makeBaseType(&tok)
    var v = Variable(name: expectIndentifer(&tok), offset: (offset ?? 0) + 8)
    v.type = .init(ty)
    return VariableList(variable: v)
  }

  var varLists = [makeParam(&token, nil)]
  while !consume(&token, op: ")") {
    expect(&token, op: ",")
    varLists.append(makeParam(&token, varLists.last?.variable?.offset))
  }
  var tmp: VariableList?
  varLists.reverse()
  while var l = varLists.popLast() {
    l.next = tmp?.toRef()
    tmp = l
  }
  return tmp!
}

func findVariable(from token: Token?, vars root: VariableList?) -> Variable? {
  var cur = root
  while let l = cur {
    if l.variable?.name == token?.str {
      return l.variable
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

/// program    = function*
func makeProgram(_ token: inout Token?) -> Function {
  var functions: [Function] = []

  while !atEOF(token) {
    functions.append(makeFunction(&token))
  }
  var tmp: Function?
  for var f in functions.reversed() {
    f.next = tmp?.toRef()
    tmp = .init(f)
  }
  return tmp!
}

/// function = basetype identifier "(" params? ")" "{" stmt* "}"
/// params   = param ("," param)*
/// param    = baseType identifier
func makeFunction(_ token: inout Token?) -> Function {
  makeBaseType(&token)
  let identifier = expectIndentifer(&token)
  var program = Function(name: identifier)
  expect(&token, op: "(")
  program.params = readFunctionParams(&token)
  expect(&token, op: "{")

  var nodes: [Node] = []
  var varList: VariableList? = program.params
  while !consume(&token, op: "}") {
    nodes.append(makeStmt(&token, &varList))
  }

  var tmp: Node?
  for var node in nodes.reversed() {
    node.next = tmp?.toRef()
    tmp = .init(node)
  }
  program.node = tmp
  program.varList = varList
  if let stackSize = varList?.variable?.offset {
    // adjust memory align to 16 bytes.
    if stackSize % 16 != 0 {
      program.stackSize = stackSize + (16 - stackSize % 16)
    } else {
      program.stackSize = stackSize
    }
  } else {
    program.stackSize = 16
  }
  return program
}

/// declaration   = basetype identifier ("=" expr) ";"

func makeDeclaration(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
  let ty = makeBaseType(&token)

  var v = Variable(name: expectIndentifer(&token), offset: 8)
  v.type = .init(ty)
  var vl = VariableList(variable: v)
  if let _var = variable {
    vl.next = Ref<VariableList>(_var)
    vl.variable?.offset = (_var.variable?.offset ?? 0) + 8;
    v.offset = (_var.variable?.offset ?? 0) + 8;
  }
  variable = vl

  if consume(&token, op: ";") {
    return .init(kind: .null)
  }

  var node = Node(kind: .assign)
  expect(&token, op: "=")
  node.lhs = .init(.init(kind: .var, variable: v, rawValue: v.name))
  node.rhs = .init(makeExpr(&token, &variable))
  expect(&token, op: ";")

  return .init(kind: .exprStmt, lhs: .init(node), rhs: nil)
}

/// stmt       = expr ";"
///              | "{" stmt* "}"
///              | "if" "(" expr ")" stmt ("else" stmt)?
///              | "while" "(" expr ")" stmt
///              | "for" "(" expr? ";" expr? ";" expr? ")" stmt
///              | declaration
///              | "return" expr ";"
func makeStmt(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
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
    return Node(kind: .block, body: tmp)
  }

  if peek(token, to: "int") != nil {
    return makeDeclaration(&token, &variable)
  }

  let node = Node(kind: .exprStmt, lhs: .init(makeExpr(&token, &variable)), rhs: nil)
  expect(&token, op: ";")
  return node
}

/// expr       = assign
func makeExpr(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
  return makeAssign(&token, &variable)
}

/// assign     = equality ("=" assign)?
func makeAssign(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
  var node = makeEquality(&token, &variable)
  if consume(&token, op: "=") {
    node = newNode(kind: .assign, lhs: node, rhs: makeAssign(&token, &variable))
  }
  return node
}

/// equality   = relational ("==" relational | "!=" relational)*
func makeEquality(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
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
func makeRelational(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
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
func makeAdd(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
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
func makeMul(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
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
func makePrimary(_ token: inout Token?, _ varList: inout VariableList?) -> Node {
  if consume(&token, op: "(") {
    let expr = makeExpr(&token, &varList)
    expect(&token, op: ")")
    return expr
  }

  if let identifier = consumeIndentifer(&token) {
    if consume(&token, op: "(") {
      var n = Node(kind: .functionCall, lhs: nil, rhs: nil)
      n.functionName = identifier.str
      n.args = makeFuncArgs(&token, &varList)?.toRef()
      return n
    }

    let foundVar = findVariable(from: identifier, vars: varList)
    var node = Node(kind: .var, lhs: nil, rhs: nil, rawValue: identifier.str)
    if let foundVar {
      node.variable = foundVar
    } else {
      fatalError("variable \(identifier.str) not found")
      // var vl = VariableList(variable: Variable(name: identifier.str, offset: 8))
      // if let _var = varList {
      //   vl.next = Ref<VariableList>(_var)
      //   vl.variable?.offset = (_var.variable?.offset ?? 0) + 8;
      //   node.variable = vl.variable
      // }
      // node.variable = vl.variable
      // varList = vl
    }
    return node
  }

  let num = newNodeNum(expectNumber(&token))
  return num
}

/// unary   = "+"? primary
///         | "-"? primary
///         | "*" unary
///         | "&" unary
func makeUnary(_ token: inout Token?, _ variable: inout VariableList?) -> Node {
  if consume(&token, op: "+") {
    return makeUnary(&token, &variable)
  } else if consume(&token, op: "-") {
    return newNode(kind: .sub, lhs: newNodeNum(0), rhs: makeUnary(&token, &variable))
  } else if consume(&token, op: "*") {
    return Node(kind: .deref, lhs: .init(makeUnary(&token, &variable)), rhs: nil)
  } else if consume(&token, op: "&") {
    return Node(kind: .addr, lhs: .init(makeUnary(&token, &variable)), rhs: nil)
  } else {
    return makePrimary(&token, &variable)
  }
}

/// func-args = "(" (assign ("," assign)*)? ")"
func makeFuncArgs(_ token: inout Token?, _ variable: inout VariableList?) -> Node? {
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

/// basetype = "int" "*"*
@discardableResult
func makeBaseType(_ token: inout Token?) -> Type {
  expect(&token, op: "int")
  var type = Type(kind: .INT)

  while consume(&token, op: "*") {
    type = Type(kind: .PTR, base: .init(type))
  }
  return type
}

func makeVariable(_ name: String, type: Type, _ varlist: inout VariableList?) -> Variable {
  var v = Variable(name: name, offset: 8)
  v.type = .init(type)
  var vl = VariableList(variable: v)
  vl.next = varlist?.toRef()
  varlist = vl
  return v
}
