internal enum YAMLResult<T> {
  case error(String)
  case value(T)
  
  public var error: String? {
    switch self {
    case .error(let e): return e
    case .value: return nil
    }
  }
  
  public var value: T? {
    switch self {
    case .error: return nil
    case .value(let v): return v
    }
  }
  
  public func map <U> (f: (T) -> U) -> YAMLResult<U> {
    switch self {
    case .error(let e): return .error(e)
    case .value(let v): return .value(f(v))
    }
  }
  
  public func flatMap <U> (f: (T) -> YAMLResult<U>) -> YAMLResult<U> {
    switch self {
    case .error(let e): return .error(e)
    case .value(let v): return f(v)
    }
  }
}


precedencegroup Functional {
  associativity: left
  higherThan: DefaultPrecedence
}

infix operator <*>: Functional
func <*> <T, U> (f: YAMLResult<(T) -> U>, x: YAMLResult<T>) -> YAMLResult<U> {
  switch (x, f) {
  case (.error(let e), _): return .error(e)
  case (.value, .error(let e)): return .error(e)
  case (.value(let x), .value(let f)): return . value(f(x))
  }
}

infix operator <^>: Functional
func <^> <T, U> (f: (T) -> U, x: YAMLResult<T>) -> YAMLResult<U> {
  return x.map(f: f)
}

infix operator >>-: Functional
func >>- <T, U> (x: YAMLResult<T>, f: (T) -> U) -> YAMLResult<U> {
  return x.map(f: f)
}

infix operator >>=-: Functional
func >>=- <T, U> (x: YAMLResult<T>, f: (T) -> YAMLResult<U>) -> YAMLResult<U> {
  return x.flatMap(f: f)
}

infix operator >>|: Functional
func >>| <T, U> (x: YAMLResult<T>, y: YAMLResult<U>) -> YAMLResult<U> {
  return x.flatMap { _ in y }
}

extension Yaml  {
  static func lift <V> (_ v: V) -> YAMLResult<V> {
    return .value(v)
  }
  
  static func fail <T> (_ e: String) -> YAMLResult<T> {
    return .error(e)
  }
  
  static func join <T> (_ x: YAMLResult<YAMLResult<T>>) -> YAMLResult<T> {
    return x >>=- { i in i }
  }
  
  static func `guard` (_ error: @autoclosure() -> String, check: Bool) -> YAMLResult<()> {
    return check ? lift(()) : .error(error())
  }
  
}
