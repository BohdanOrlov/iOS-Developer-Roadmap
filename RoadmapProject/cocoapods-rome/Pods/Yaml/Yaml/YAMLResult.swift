internal enum Result<T> {
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
  
  public func map <U> (f: (T) -> U) -> Result<U> {
    switch self {
    case .error(let e): return .error(e)
    case .value(let v): return .value(f(v))
    }
  }
  
  public func flatMap <U> (f: (T) -> Result<U>) -> Result<U> {
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
func <*> <T, U> (f: Result<(T) -> U>, x: Result<T>) -> Result<U> {
  switch (x, f) {
  case (.error(let e), _): return .error(e)
  case (.value, .error(let e)): return .error(e)
  case (.value(let x), .value(let f)): return . value(f(x))
  }
}

infix operator <^>: Functional
func <^> <T, U> (f: (T) -> U, x: Result<T>) -> Result<U> {
  return x.map(f: f)
}

infix operator >>-: Functional
func >>- <T, U> (x: Result<T>, f: (T) -> U) -> Result<U> {
  return x.map(f: f)
}

infix operator >>=-: Functional
func >>=- <T, U> (x: Result<T>, f: (T) -> Result<U>) -> Result<U> {
  return x.flatMap(f: f)
}

infix operator >>|: Functional
func >>| <T, U> (x: Result<T>, y: Result<U>) -> Result<U> {
  return x.flatMap { _ in y }
}

extension Yaml  {
  static func lift <V> (_ v: V) -> Result<V> {
    return .value(v)
  }
  
  static func fail <T> (_ e: String) -> Result<T> {
    return .error(e)
  }
  
  static func join <T> (_ x: Result<Result<T>>) -> Result<T> {
    return x >>=- { i in i }
  }
  
  static func `guard` (_ error: @autoclosure() -> String, check: Bool) -> Result<()> {
    return check ? lift(()) : .error(error())
  }
  
}
