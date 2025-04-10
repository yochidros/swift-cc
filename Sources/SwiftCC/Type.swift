enum TypeKind {
  case INT
  case PTR
}

struct Type: Equatable {
  let kind: TypeKind
  var base: Ref<Type>?
}
extension Type: CustomDebugStringConvertible {
  var debugDescription: String {
    if let b = base {
      return "\(kind) \(b.wrappedValue)"
    }
    switch kind {
    case .INT:
      return "int"
    case .PTR:
      return "ptr"
    }
  }
}

fileprivate func visit(_ node: inout Node?) {
  guard node != nil else { return }

  var lhs = node!.lhs?.wrappedValue
  visit(&lhs)
  if let lhs {
    node!.lhs?.wrappedValue = lhs
  }

  var rhs = node!.rhs?.wrappedValue
  visit(&rhs)
  if let rhs {
    node!.rhs?.wrappedValue = rhs
  }

  var cond = node!.condition?.wrappedValue
  visit(&cond)
  if let cond {
    node!.condition?.wrappedValue = cond
  }

  var then = node!.then?.wrappedValue
  visit(&then)
  if let then {
    node!.then?.wrappedValue = then
  }

  var els = node!.else?.wrappedValue
  visit(&els)
  if let els {
    node!.else?.wrappedValue = els
  }

  var args = node!.args?.wrappedValue
  visit(&args)
  if let args {
    node!.args?.wrappedValue = args
  }

  switch node!.kind {
  case .mul, .div, .eq, .neq, .lt, .lte, .gt, .gte, .var, .functionCall, .num:
    node!.type = Type(kind: .INT)
    return
  case .add:
    if node!.rhs?.wrappedValue.type?.kind == .PTR {
      let tmp = node!.lhs
      node!.lhs = node!.rhs
      node!.rhs = tmp
    }
    if node!.rhs?.wrappedValue.type?.kind == .PTR {
      fatalError("invalid pointer arithmetic operands")
    }
    node!.type = node!.lhs?.wrappedValue.type
    return
  case .sub:
    if node!.rhs?.wrappedValue.type?.kind == .PTR {
      fatalError("invalid pointer arithmetic operands")
    }
    node!.type = node!.lhs?.wrappedValue.type
    return
  case .assign:
    node!.type = node!.lhs?.wrappedValue.type
    return
  case .addr:
    var new = Type(kind: .PTR)
    if let ty = node!.lhs?.wrappedValue.type {
      new.base = .init(ty)
    }
    return
  case .deref:
    if node!.lhs?.wrappedValue.type?.kind == .PTR {
      node!.type = node!.lhs?.wrappedValue.type?.base?.wrappedValue
    } else {
      node!.type = .init(kind: .INT)
    }
    return
  default:
    return
  }
}

func visitBody(_ node: inout Node?) {
  guard node != nil else { return }
  visit(&node)

  var n = node!.next?.wrappedValue
  visitBody(&n)
  if let n {
    node!.next?.wrappedValue = n
  }
}

fileprivate func addTypeInNode(_ node: inout Node?) {
  guard node != nil else { return }

  visit(&node)

  var n = node!.next?.wrappedValue
  addTypeInNode(&n)
  if n != nil {
    node!.next?.wrappedValue = n!
  }
}

func addType(_ prog: inout Function?) {
  guard prog != nil else { return }
  if prog!.node != nil {
    addTypeInNode(&prog!.node)
  }
  var v = prog?.next?.wrappedValue
  addType(&v)
  if v != nil {
    prog!.next?.wrappedValue = v!
  }
}
