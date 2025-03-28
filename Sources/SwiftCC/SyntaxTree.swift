
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
