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
