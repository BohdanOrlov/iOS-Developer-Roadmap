import Foundation


private let invalidOptionsPattern =
  try! NSRegularExpression(pattern: "[^ixsm]", options: [])

private let regexOptions: [Character: NSRegularExpression.Options] = [
  "i": .caseInsensitive,
  "x": .allowCommentsAndWhitespace,
  "s": .dotMatchesLineSeparators,
  "m": .anchorsMatchLines
]

extension Yaml {
  struct Regex {

static func matchRange (_ string: String, regex: NSRegularExpression) -> NSRange {
  let sr = NSMakeRange(0, string.utf16.count)
  return regex.rangeOfFirstMatch(in: string, options: [], range: sr)
}

static func matches (_ string: String, regex: NSRegularExpression) -> Bool {
  return matchRange(string, regex: regex).location != NSNotFound
}

static func regex (_ pattern: String, options: String = "") -> NSRegularExpression! {
  if matches(options, regex: invalidOptionsPattern) {
    return nil
  }

  let opts = options.reduce(NSRegularExpression.Options()) { (acc, opt) -> NSRegularExpression.Options in
    return NSRegularExpression.Options(rawValue:acc.rawValue | (regexOptions[opt] ?? NSRegularExpression.Options()).rawValue)
  }
  return try? NSRegularExpression(pattern: pattern, options: opts)
}





static func replace (_ regex: NSRegularExpression, template: String) -> (String)
    -> String {
      return { string in
        let s = NSMutableString(string: string)
        let range = NSMakeRange(0, string.utf16.count)
        _ = regex.replaceMatches(in: s, options: [], range: range,
                                 withTemplate: template)
#if os(Linux)
        return s._bridgeToSwift()
#else
        return s as String
#endif
      }
}

static func replace (_ regex: NSRegularExpression, block: @escaping ([String]) -> String)
    -> (String) -> String {
      return { string in
        let s = NSMutableString(string: string)
        let range = NSMakeRange(0, string.utf16.count)
        var offset = 0
        regex.enumerateMatches(in: string, options: [], range: range) {
          result, _, _ in
          if let result = result {
              var captures = [String](repeating: "", count: result.numberOfRanges)
              for i in 0..<result.numberOfRanges {
                let rangeAt = result.range(at: i)
                if let r = Range(rangeAt) {
                  captures[i] = NSString(string: string).substring(with: NSRange(r))
                }
              }
              let replacement = block(captures)
              let offR = NSMakeRange(result.range.location + offset, result.range.length)
              offset += replacement.count - result.range.length
              s.replaceCharacters(in: offR, with: replacement)
          }
        }
#if os(Linux)
        return s._bridgeToSwift()
#else
        return s as String
#endif
      }
}

static func splitLead (_ regex: NSRegularExpression) -> (String)
    -> (String, String) {
      return { string in
        let r = matchRange(string, regex: regex)
        if r.location == NSNotFound {
          return ("", string)
        } else {
          let s = NSString(string: string)
          let i = r.location + r.length
          return (s.substring(to: i), s.substring(from: i))
        }
      }
}

static func splitTrail (_ regex: NSRegularExpression) -> (String)
    -> (String, String) {
      return { string in
        let r = matchRange(string, regex: regex)
        if r.location == NSNotFound {
          return (string, "")
        } else {
          let s = NSString(string: string)
          let i = r.location
          return (s.substring(to: i), s.substring(from: i))
        }
      }
}

static func substring (_ range: NSRange, _ string : String ) -> String {
    return NSString(string: string).substring(with: range)
}

static func substring (_ index: Int, _ string: String ) -> String {
    return NSString(string: string).substring(from: index)
}
  }

}
