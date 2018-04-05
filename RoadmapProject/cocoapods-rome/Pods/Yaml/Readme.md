# YamlSwift

Load [YAML](http://yaml.org) and [JSON](http://json.org) documents using [Swift](http://www.apple.com/swift/).

`YamlSwift` parses a string of YAML document(s) (or a JSON document) and returns a `Yaml` enum value representing that string.





## Install

Use [Carthage](https://github.com/Carthage/Carthage) to build and install.

Or use [CocoaPods](https://cocoapods.org/) :
Add `pod 'Yaml'` to your `Podfile` and run `pod install`.

It supports Swift Package Manager. 

```
        .package(
            url: "https://github.com/behrang/YamlSwift.git",
            from: "

```

And:

```
        .target(
            name: "YourProject",
            dependencies: ["Yaml"]),
```

## API





### import

To use it, you should import it using the following statement:

```swift
import Yaml
```





### Yaml

A Yaml value can be any of these cases:

```swift
enum Yaml {
  case null
  case bool(Bool)
  case int(Int)
  case double(Double)
  case string(String)
  case array([Yaml])
  case dictionary([Yaml: Yaml])
}
```





### Yaml.load

```swift
Yaml.load (String) throws -> Yaml
```

Takes a string of a YAML document and returns a `Yaml` enum.

```swift
let value = try! Yaml.load("a: 1\nb: 2")
print(value["a"])  // Int(1)
print(value["b"])  // Int(2)
print(value["c"])  // Null
```

If the input document is invalid or contains more than one YAML document, an error is thrown.

```swift
do {
  let value = try Yaml.load("a\nb: 2")
}
catch {
  print(error)  // expected end, near "b: 2"
}

```





### Yaml.loadMultiple

```swift
Yaml.loadMultiple (String) throws -> [Yaml]
```

Takes a string of one or more YAML documents and returns `[Yaml]`.

```swift
let value = try! Yaml.loadMultiple("---\na: 1\nb: 2\n---\na: 3\nb: 4")
print(value[0]["a"])  // Int(1)
print(value[1]["a"])  // Int(3)
```

It will throw an error if an error is encountered in any of the documents.





### Yaml#[Int] -> Yaml

```swift
value[Int] -> Yaml
value[Int] = Yaml
```

If used on a `Yaml.array` value, it will return the value at the specified index. If the index is invalid or the value is not a `Yaml.array`, `Yaml.null` is returned. You can also set a value at a specific index. Enough elements will be added to the wrapped array to set the specified index. If the value is not a `Yaml.array`, it will change to it after set.

```swift
var value = try! Yaml.load("- Behrang\n- Maryam")
print(value[0])  // String(Behrang)
print(value[1])  // String(Maryam)
print(value[2])  // Null
value[2] = "Radin"
print(value[2])  // String(Radin)
```





### Yaml#[Yaml] -> Yaml

```swift
value[Yaml] -> Yaml
value[Yaml] = Yaml
```

If used on a `Yaml.dictionary` value, it will return the value for the specified key. If a value for the specified key does not exist, or value is not a `Yaml.dictionary`, `Yaml.null` is returned. You can also set a value for a specific key. If the value is not a `Yaml.dictionary`, it will change to it after set.

Since `Yaml` is a literal convertible type, you can pass simple values to this method.

```swift
var value = try! Yaml.load("first name: Behrang\nlast name: Noruzi Niya")
print(value["first name"])  // String(Behrang)
print(value["last name"])  // String(Noruzi Niya)
print(value["age"])  // Null
value["first name"] = "Radin"
value["age"] = 1
print(value["first name"])  // String(Radin)
print(value["last name"])  // String(Noruzi Niya)
print(value["age"])  // Int(1)
```





### Yaml#bool

```swift
value.bool -> Bool?
```

Returns an `Optional<Bool>` value. If the value is a `Yaml.bool` value, the wrapped value is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("animate: true\nshow tip: false\nusage: 25")
print(value["animate"].bool)  // Optional(true)
print(value["show tip"].bool)  // Optional(false)
print(value["usage"].bool)  // nil
```





### Yaml#int

```swift
value.int -> Int?
```

Returns an `Optional<Int>` value. If the value is a `Yaml.int` value, the wrapped value is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("a: 1\nb: 2.0\nc: 2.5")
print(value["a"].int)  // Optional(1)
print(value["b"].int)  // Optional(2)
print(value["c"].int)  // nil
```





### Yaml#double

```swift
value.double -> Double?
```

Returns an `Optional<Double>` value. If the value is a `Yaml.double` value, the wrapped value is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("a: 1\nb: 2.0\nc: 2.5\nd: true")
print(value["a"].double)  // Optional(1.0)
print(value["b"].double)  // Optional(2.0)
print(value["c"].double)  // Optional(2.5)
print(value["d"].double)  // nil
```





### Yaml#string

```swift
value.string -> String?
```

Returns an `Optional<String>` value. If the value is a `Yaml.string` value, the wrapped value is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("first name: Behrang\nlast name: Noruzi Niya\nage: 33")
print(value["first name"].string)  // Optional("Behrang")
print(value["last name"].string)  // Optional("Noruzi Niya")
print(value["age"].string)  // nil
```





### Yaml#array

```swift
value.array -> [Yaml]?
```

Returns an `Optional<Array<Yaml>>` value. If the value is a `Yaml.array` value, the wrapped value is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("languages:\n - Swift: true\n - Objective C: false")
print(value.array)  // nil
print(value["languages"].array)  // Optional([Dictionary([String(Swift): Bool(true)]), Dictionary([String(Objective C): Bool(false)])])
```





### Yaml#dictionary

```swift
value.dictionary -> [Yaml: Yaml]?
```

Returns an `Optional<Dictionary<Yaml, Yaml>>` value. If the value is a `Yaml.dictionary` value, the wrapped value is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("- Swift: true\n- Objective C: false")
print(value.dictionary)  // nil
print(value[0].dictionary)  // Optional([String(Swift): Bool(true)])
```





### Yaml#count

```swift
value.count -> Int?
```

Returns an `Optional<Int>` value. If the value is either a `Yaml.array` or a `Yaml.dictionary` value, the count of elements is returned. Otherwise `nil` is returned.

```swift
let value = try! Yaml.load("- Swift: true\n- Objective C: false")
print(value.count)  // Optional(2)
print(value[0].count)  // Optional(1)
print(value[0]["Swift"].count)  // nil
```





## License

MIT
