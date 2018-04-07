import Foundation

private typealias Resulter = Yaml


extension Yaml {

struct Context {
  let tokens: [Yaml.TokenMatch]
  let aliases: [String.SubSequence: Yaml]

  init (_ tokens: [Yaml.TokenMatch], _ aliases: [String.SubSequence: Yaml] = [:]) {
    self.tokens = tokens
    self.aliases = aliases
  }
  static func parseDoc (_ tokens: [Yaml.TokenMatch]) -> YAMLResult<Yaml> {
    let c = Resulter.lift(Context(tokens))
    let cv = c >>=- parseHeader >>=- parse
    let v = cv >>- getValue
    return cv
      >>- getContext
      >>- ignoreDocEnd
      >>=- expect(Yaml.TokenType.end, message: "expected end")
      >>| v
  }
  
  static func parseDocs (_ tokens: [Yaml.TokenMatch]) -> YAMLResult<[Yaml]> {
    return parseDocs([])(Context(tokens))
  }
  
  static func parseDocs (_ acc: [Yaml]) -> (Context) -> YAMLResult<[Yaml]> {
    return { context in
      if peekType(context) == .end {
        return Resulter.lift(acc)
      }
      let cv = Resulter.lift(context)
        >>=- parseHeader
        >>=- parse
      let v = cv
        >>- getValue
      let c = cv
        >>- getContext
        >>- ignoreDocEnd
      let a = appendToArray(acc) <^> v
      return parseDocs <^> a <*> c |> Resulter.join
    }
  }
  
  static func error (_ message: String) -> (Context) -> String {
    return { context in
      let text = recreateText("", context: context) |> Yaml.escapeErrorContext
      return "\(message), \(text)"
    }
  }

  

}

}

private typealias Context = Yaml.Context

private var error = Yaml.Context.error

private typealias ContextValue = (context: Context, value: Yaml)

private func createContextValue (_ context: Context) -> (Yaml) -> ContextValue {
  return { value in (context, value) }
}

private func getContext (_ cv: ContextValue) -> Context {
  return cv.context
}

private func getValue (_ cv: ContextValue) -> Yaml {
  return cv.value
}


private func peekType (_ context: Context) -> Yaml.TokenType {
  return context.tokens[0].type
}


private func peekMatch (_ context: Context) -> String {
  return context.tokens[0].match
}


private func advance (_ context: Context) -> Context {
  var tokens = context.tokens
  tokens.remove(at: 0)
  return Context(tokens, context.aliases)
}

private func ignoreSpace (_ context: Context) -> Context {
  if ![.comment, .space, .newLine].contains(peekType(context)) {
    return context
  }
  return ignoreSpace(advance(context))
}

private func ignoreDocEnd (_ context: Context) -> Context {
  if ![.comment, .space, .newLine, .docend].contains(peekType(context)) {
    return context
  }
  return ignoreDocEnd(advance(context))
}

private func expect (_ type: Yaml.TokenType, message: String) -> (Context) -> YAMLResult<Context> {
  return { context in
    let check = peekType(context) == type
    return Resulter.`guard`(error(message)(context), check: check)
        >>| Resulter.lift(advance(context))
  }
}

private func expectVersion (_ context: Context) -> YAMLResult<Context> {
  let version = peekMatch(context)
  let check = ["1.1", "1.2"].contains(version)
  return Resulter.`guard`(error("invalid yaml version")(context), check: check)
      >>| Resulter.lift(advance(context))
}


private func recreateText (_ string: String, context: Context) -> String {
  if string.count >= 50 || peekType(context) == .end {
    return string
  }
  return recreateText(string + peekMatch(context), context: advance(context))
}

private func parseHeader (_ context: Context) -> YAMLResult<Context> {
  return parseHeader(true)(Context(context.tokens, [:]))
}

private func parseHeader (_ yamlAllowed: Bool) -> (Context) -> YAMLResult<Context> {
  return { context in
    switch peekType(context) {

    case .comment, .space, .newLine:
      return Resulter.lift(context)
          >>- advance
          >>=- parseHeader(yamlAllowed)

    case .yamlDirective:
      let err = "duplicate yaml directive"
      return Resulter.`guard`(error(err)(context), check: yamlAllowed)
          >>| Resulter.lift(context)
          >>- advance
          >>=- expect(Yaml.TokenType.space, message: "expected space")
          >>=- expectVersion
          >>=- parseHeader(false)

    case .docStart:
      return Resulter.lift(advance(context))

    default:
      return Resulter.`guard`(error("expected ---")(context), check: yamlAllowed)
          >>| Resulter.lift(context)
    }
  }
}

private func parse (_ context: Context) -> YAMLResult<ContextValue> {
  switch peekType(context) {

  case .comment, .space, .newLine:
    return parse(ignoreSpace(context))

  case .null:
    return Resulter.lift((advance(context), nil))

  case ._true:
    return Resulter.lift((advance(context), true))

  case ._false:
    return Resulter.lift((advance(context), false))

  case .int:
    let m = peekMatch(context)
    // will throw runtime error if overflows
    let v = Yaml.int(parseInt(m, radix: 10))
    return Resulter.lift((advance(context), v))

  case .intOct:
    let m = peekMatch(context) |> Yaml.Regex.replace(Yaml.Regex.regex("0o"), template: "")
    // will throw runtime error if overflows
    let v = Yaml.int(parseInt(m, radix: 8))
    return Resulter.lift((advance(context), v))

  case .intHex:
    let m = peekMatch(context) |> Yaml.Regex.replace(Yaml.Regex.regex("0x"), template: "")
    // will throw runtime error if overflows
    let v = Yaml.int(parseInt(m, radix: 16))
    return Resulter.lift((advance(context), v))

  case .intSex:
    let m = peekMatch(context)
    let v = Yaml.int(parseInt(m, radix: 60))
    return Resulter.lift((advance(context), v))

  case .infinityP:
    return Resulter.lift((advance(context), .double(Double.infinity)))

  case .infinityN:
    return Resulter.lift((advance(context), .double(-Double.infinity)))

  case .nan:
    return Resulter.lift((advance(context), .double(Double.nan)))

  case .double:
    let m = NSString(string: peekMatch(context))
    return Resulter.lift((advance(context), .double(m.doubleValue)))

  case .dash:
    return parseBlockSeq(context)

  case .openSB:
    return parseFlowSeq(context)

  case .openCB:
    return parseFlowMap(context)

  case .questionMark:
    return parseBlockMap(context)

  case .stringDQ, .stringSQ, .string:
    return parseBlockMapOrString(context)

  case .literal:
    return parseliteral(context)

  case .folded:
    let cv = parseliteral(context)
    let c = cv >>- getContext
    let v = cv
        >>- getValue
        >>- { value in Yaml.string(foldBlock(value.string ?? "")) }
    return createContextValue <^> c <*> v

  case .indent:
    let cv = parse(advance(context))
    let v = cv >>- getValue
    let c = cv
        >>- getContext
        >>- ignoreSpace
        >>=- expect(Yaml.TokenType.dedent, message: "expected dedent")
    return createContextValue <^> c <*> v

  case .anchor:
    let m = peekMatch(context)
    let name = m[m.index(after: m.startIndex)...]
    let cv = parse(advance(context))
    let v = cv >>- getValue
    let c = addAlias(name) <^> v <*> (cv >>- getContext)
    return createContextValue <^> c <*> v

  case .alias:
    let m = peekMatch(context)
    let name = m[m.index(after: m.startIndex)...]
    let value = context.aliases[name]
    let err = "unknown alias \(name)"
    return Resulter.`guard`(error(err)(context), check: value != nil)
        >>| Resulter.lift((advance(context), value ?? nil))

  case .end, .dedent:
    return Resulter.lift((context, nil))

  default:
    return Resulter.fail(error("unexpected type \(peekType(context))")(context))

  }
}

private func addAlias (_ name: String.SubSequence) -> (Yaml) -> (Context) -> Context {
  return { value in
    return { context in
      var aliases = context.aliases
      aliases[name] = value
      return Context(context.tokens, aliases)
    }
  }
}

private func appendToArray (_ array: [Yaml]) -> (Yaml) -> [Yaml] {
  return { value in
    return array + [value]
  }
}

private func putToMap (_ map: [Yaml: Yaml]) -> (Yaml) -> (Yaml) -> [Yaml: Yaml] {
  return { key in
    return { value in
      var map = map
      map[key] = value
      return map
    }
  }
}

private func checkKeyUniqueness (_ acc: [Yaml: Yaml]) -> (_ context: Context, _ key: Yaml)
    -> YAMLResult<ContextValue> {
      return { (context, key) in
        let err = "duplicate key \(key)"
        return Resulter.`guard`(error(err)(context), check: !acc.keys.contains(key))
            >>| Resulter.lift((context, key))
      }
}

private func parseFlowSeq (_ context: Context) -> YAMLResult<ContextValue> {
  return Resulter.lift(context)
      >>=- expect(Yaml.TokenType.openSB, message: "expected [")
      >>=- parseFlowSeq([])
}

private func parseFlowSeq (_ acc: [Yaml]) -> (Context) -> YAMLResult<ContextValue> {
  return { context in
    if peekType(context) == .closeSB {
      return Resulter.lift((advance(context), .array(acc)))
    }
    let cv = Resulter.lift(context)
        >>- ignoreSpace
        >>=- (acc.count == 0 ? Resulter.lift : expect(Yaml.TokenType.comma, message: "expected comma"))
        >>- ignoreSpace
        >>=- parse
    let v = cv >>- getValue
    let c = cv
        >>- getContext
        >>- ignoreSpace
    let a = appendToArray(acc) <^> v
    return parseFlowSeq <^> a <*> c |> Resulter.join
  }
}


private func parseFlowMap (_ context: Context) -> YAMLResult<ContextValue> {
  return Resulter.lift(context)
      >>=- expect(Yaml.TokenType.openCB, message: "expected {")
      >>=- parseFlowMap([:])
}

private func parseFlowMap (_ acc: [Yaml: Yaml]) -> (Context) -> YAMLResult<ContextValue> {
  return { context in
    if peekType(context) == .closeCB {
      return Resulter.lift((advance(context), .dictionary(acc)))
    }
    let ck = Resulter.lift(context)
        >>- ignoreSpace
        >>=- (acc.count == 0 ? Resulter.lift : expect(Yaml.TokenType.comma, message: "expected comma"))
        >>- ignoreSpace
        >>=- parseString
        >>=- checkKeyUniqueness(acc)
    let k = ck >>- getValue
    let cv = ck
        >>- getContext
        >>=- expect(Yaml.TokenType.colon, message: "expected colon")
        >>=- parse
    let v = cv >>- getValue
    let c = cv
        >>- getContext
        >>- ignoreSpace
    let a = putToMap(acc) <^> k <*> v
    return parseFlowMap <^> a <*> c |> Resulter.join
  }
}

private func parseBlockSeq (_ context: Context) -> YAMLResult<ContextValue> {
  return parseBlockSeq([])(context)
}

private func parseBlockSeq (_ acc: [Yaml]) -> (Context) -> YAMLResult<ContextValue> {
  return { context in
    if peekType(context) != .dash {
      return Resulter.lift((context, .array(acc)))
    }
    let cv = Resulter.lift(context)
        >>- advance
        >>=- expect(Yaml.TokenType.indent, message: "expected indent after dash")
        >>- ignoreSpace
        >>=- parse
    let v = cv >>- getValue
    let c = cv
        >>- getContext
        >>- ignoreSpace
        >>=- expect(Yaml.TokenType.dedent, message: "expected dedent after dash indent")
        >>- ignoreSpace
    let a = appendToArray(acc) <^> v
    return parseBlockSeq <^> a <*> c |> Resulter.join
  }
}

private func parseBlockMap (_ context: Context) -> YAMLResult<ContextValue> {
  return parseBlockMap([:])(context)
}

private func parseBlockMap (_ acc: [Yaml: Yaml]) -> (Context) -> YAMLResult<ContextValue> {
  return { context in
    switch peekType(context) {

    case .questionMark:
      return parseQuestionMarkkeyValue(acc)(context)

    case .string, .stringDQ, .stringSQ:
      return parseStringKeyValue(acc)(context)

    default:
      return Resulter.lift((context, .dictionary(acc)))
    }
  }
}

private func parseQuestionMarkkeyValue (_ acc: [Yaml: Yaml]) -> (Context) -> YAMLResult<ContextValue> {
  return { context in
    let ck = Resulter.lift(context)
        >>=- expect(Yaml.TokenType.questionMark, message: "expected ?")
        >>=- parse
        >>=- checkKeyUniqueness(acc)
    let k = ck >>- getValue
    let cv = ck
        >>- getContext
        >>- ignoreSpace
        >>=- parseColonValueOrNil
    let v = cv >>- getValue
    let c = cv
        >>- getContext
        >>- ignoreSpace
    let a = putToMap(acc) <^> k <*> v
    return parseBlockMap <^> a <*> c |> Resulter.join
  }
}

private func parseColonValueOrNil (_ context: Context) -> YAMLResult<ContextValue> {
  if peekType(context) != .colon {
    return Resulter.lift((context, nil))
  }
  return parseColonValue(context)
}

private func parseColonValue (_ context: Context) -> YAMLResult<ContextValue> {
  return Resulter.lift(context)
      >>=- expect(Yaml.TokenType.colon, message: "expected colon")
      >>- ignoreSpace
      >>=- parse
}

private func parseStringKeyValue (_ acc: [Yaml: Yaml]) -> (Context) -> YAMLResult<ContextValue> {
  return { context in
    let ck = Resulter.lift(context)
        >>=- parseString
        >>=- checkKeyUniqueness(acc)
    let k = ck >>- getValue
    let cv = ck
        >>- getContext
        >>- ignoreSpace
        >>=- parseColonValue
    let v = cv >>- getValue
    let c = cv
        >>- getContext
        >>- ignoreSpace
    let a = putToMap(acc) <^> k <*> v
    return parseBlockMap <^> a <*> c |> Resulter.join
  }
}

private func parseString (_ context: Context) -> YAMLResult<ContextValue> {
  switch peekType(context) {

  case .string:
    let m = normalizeBreaks(peekMatch(context))
    let folded = m |> Yaml.Regex.replace(Yaml.Regex.regex("^[ \\t\\n]+|[ \\t\\n]+$"), template: "") |> foldFlow
    return Resulter.lift((advance(context), .string(folded)))

  case .stringDQ:
    let m = unwrapQuotedString(normalizeBreaks(peekMatch(context)))
    return Resulter.lift((advance(context), .string(unescapeDoubleQuotes(foldFlow(m)))))

  case .stringSQ:
    let m = unwrapQuotedString(normalizeBreaks(peekMatch(context)))
    return Resulter.lift((advance(context), .string(unescapeSingleQuotes(foldFlow(m)))))

  default:
    return Resulter.fail(error("expected string")(context))
  }
}


private func parseBlockMapOrString (_ context: Context) -> YAMLResult<ContextValue> {
  let match = peekMatch(context)
  // should spaces before colon be ignored?
  return context.tokens[1].type != .colon || Yaml.Regex.matches(match, regex: Yaml.Regex.regex("\n"))
      ? parseString(context)
      : parseBlockMap(context)
}

private func foldBlock (_ block: String) -> String {
  let (body, trail) = block |> Yaml.Regex.splitTrail(Yaml.Regex.regex("\\n*$"))
  return (body
      |> Yaml.Regex.replace(Yaml.Regex.regex("^([^ \\t\\n].*)\\n(?=[^ \\t\\n])", options: "m"), template: "$1 ")
      |> Yaml.Regex.replace(
            Yaml.Regex.regex("^([^ \\t\\n].*)\\n(\\n+)(?![ \\t])", options: "m"), template: "$1$2")
      ) + trail
}

private func foldFlow (_ flow: String) -> String {
  let (lead, rest) = flow |> Yaml.Regex.splitLead(Yaml.Regex.regex("^[ \\t]+"))
  let (body, trail) = rest |> Yaml.Regex.splitTrail(Yaml.Regex.regex("[ \\t]+$"))
  let folded = body
      |> Yaml.Regex.replace(Yaml.Regex.regex("^[ \\t]+|[ \\t]+$|\\\\\\n", options: "m"), template: "")
      |> Yaml.Regex.replace(Yaml.Regex.regex("(^|.)\\n(?=.|$)"), template: "$1 ")
      |> Yaml.Regex.replace(Yaml.Regex.regex("(.)\\n(\\n+)"), template: "$1$2")
  return lead + folded + trail
}

private func count(string: String) -> Int {
  return string.count
}

private func parseliteral (_ context: Context) -> YAMLResult<ContextValue> {
  let literal = peekMatch(context)
  let blockContext = advance(context)
  let chomps = ["-": -1, "+": 1]
  let chomp = chomps[literal |> Yaml.Regex.replace(Yaml.Regex.regex("[^-+]"), template: "")] ?? 0
  let indent = parseInt(literal |> Yaml.Regex.replace(Yaml.Regex.regex("[^1-9]"), template: ""), radix: 10)
  let headerPattern = Yaml.Regex.regex("^(\\||>)([1-9][-+]|[-+]?[1-9]?)( |$)")
  let error0 = "invalid chomp or indent header"
  let c = Resulter.`guard`(error(error0)(context),
        check: Yaml.Regex.matches(literal, regex: headerPattern!))
      >>| Resulter.lift(blockContext)
      >>=- expect(Yaml.TokenType.string, message: "expected scalar block")
  let block = peekMatch(blockContext)
      |> normalizeBreaks
  let (lead, _) = block
      |> Yaml.Regex.splitLead(Yaml.Regex.regex("^( *\\n)* {1,}(?! |\\n|$)"))
  let foundindent = lead
      |> Yaml.Regex.replace(Yaml.Regex.regex("^( *\\n)*"), template: "")
      |> count
  let effectiveindent = indent > 0 ? indent : foundindent
  let invalidPattern =
      Yaml.Regex.regex("^( {0,\(effectiveindent)}\\n)* {\(effectiveindent + 1),}\\n")
  let check1 = Yaml.Regex.matches(block, regex: invalidPattern!)
  let check2 = indent > 0 && foundindent < indent
  let trimmed = block
      |> Yaml.Regex.replace(Yaml.Regex.regex("^ {0,\(effectiveindent)}"), template: "")
      |> Yaml.Regex.replace(Yaml.Regex.regex("\\n {0,\(effectiveindent)}"), template: "\n")
      |> (chomp == -1
          ? Yaml.Regex.replace(Yaml.Regex.regex("(\\n *)*$"), template: "")
          : chomp == 0
          ? Yaml.Regex.replace(Yaml.Regex.regex("(?=[^ ])(\\n *)*$"), template: "\n")
          : { s in s }
      )
  let error1 = "leading all-space line must not have too many spaces"
  let error2 = "less indented block scalar than the indicated level"
  return c
      >>| Resulter.`guard`(error(error1)(blockContext), check: !check1)
      >>| Resulter.`guard`(error(error2)(blockContext), check: !check2)
      >>| c
      >>- { context in (context, .string(trimmed))}
}


private func parseInt (_ string: String, radix: Int) -> Int {
  let (sign, str) = Yaml.Regex.splitLead(Yaml.Regex.regex("^[-+]"))(string)
  let multiplier = (sign == "-" ? -1 : 1)
  let ints = radix == 60
      ? toSexints(str)
      : toints(str)
  return multiplier * ints.reduce(0, { acc, i in acc * radix + i })
}

private func toSexints (_ string: String) -> [Int] {
  return string.components(separatedBy: ":").map {
    c in Int(c) ?? 0
  }
}

private func toints (_ string: String) -> [Int] {
  return string.unicodeScalars.map {
    c in
    switch c {
    case "0"..."9": return Int(c.value) - Int(("0" as UnicodeScalar).value)
    case "a"..."z": return Int(c.value) - Int(("a" as UnicodeScalar).value) + 10
    case "A"..."Z": return Int(c.value) - Int(("A" as UnicodeScalar).value) + 10
    default: fatalError("invalid digit \(c)")
    }
  }
}

private func normalizeBreaks (_ s: String) -> String {
  return Yaml.Regex.replace(Yaml.Regex.regex("\\r\\n|\\r"), template: "\n")(s)
}

private func unwrapQuotedString (_ s: String) -> String {
  return String(s[s.index(after: s.startIndex)..<s.index(before: s.endIndex)])
}

private func unescapeSingleQuotes (_ s: String) -> String {
  return Yaml.Regex.replace(Yaml.Regex.regex("''"), template: "'")(s)
}

private func unescapeDoubleQuotes (_ input: String) -> String {
  return input
    |> Yaml.Regex.replace(Yaml.Regex.regex("\\\\([0abtnvfre \"\\/N_LP])"))
        { escapeCharacters[$0[1]] ?? "" }
    |> Yaml.Regex.replace(Yaml.Regex.regex("\\\\x([0-9A-Fa-f]{2})"))
        { String(describing: UnicodeScalar(parseInt($0[1], radix: 16))) }
    |> Yaml.Regex.replace(Yaml.Regex.regex("\\\\u([0-9A-Fa-f]{4})"))
        { String(describing: UnicodeScalar(parseInt($0[1], radix: 16))) }
    |> Yaml.Regex.replace(Yaml.Regex.regex("\\\\U([0-9A-Fa-f]{8})"))
        { String(describing: UnicodeScalar(parseInt($0[1], radix: 16))) }
}

private let escapeCharacters = [
  "0": "\0",
  "a": "\u{7}",
  "b": "\u{8}",
  "t": "\t",
  "n": "\n",
  "v": "\u{B}",
  "f": "\u{C}",
  "r": "\r",
  "e": "\u{1B}",
  " ": " ",
  "\"": "\"",
  "\\": "\\",
  "/": "/",
  "N": "\u{85}",
  "_": "\u{A0}",
  "L": "\u{2028}",
  "P": "\u{2029}"
]
