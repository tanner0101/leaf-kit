// MARK: Subject to change prior to 1.0.0 release
// MARK: -

// MARK: `LeafError` Summary

public typealias LeafErrorCause = LeafError.Reason
public typealias LexErrorCause = LexerError.Reason
public typealias ParseErrorCause = ParserError.Reason

/// `LeafError` reports errors during the template rendering process, wrapping more specific
/// errors if necessary during Lexing and Parsing stages.
///
/// #TODO
/// - Implement a ParserError subtype
public struct LeafError: Error, CustomStringConvertible {
    /// Possible cases of a LeafError.Reason, with applicable stored values where useful for the type
    public enum Reason {
        // MARK: Errors related to loading raw templates
        /// Attempted to access a template blocked for security reasons
        case illegalAccess(String)
                
        // MARK: Errors related to LeafCache access
        /// Attempt to modify cache entries when caching is globally disabled
        case cachingDisabled
        /// Attempt to insert a cache entry when one exists and replacing is not set to true
        /// - Provide the template name update was attempted on
        case keyExists(String)
        /// Attempt to modify cache for a non-existant key
        /// - Provide template name
        /// - NOTE: NOT thrown when "reading" from cache - nil Optional returned then
        case noValueForKey(String)

        // MARK: Errors related to rendering a template
        /// Attempt to render a non-flat AST
        /// - Provide template name & array of unresolved references
        case unresolvedAST(String, [String])
        /// Attempt to render a non-flat AST
        /// - Provide raw file name needed
        case missingRaw(String)
        /// Attempt to render a non-existant template
        /// Provide template name
        case noTemplateExists(String)
        /// Attempt to render an AST with cyclical external references
        /// - Provide template name & ordered array of template names that causes the cycle path
        case cyclicalReference(String, [String])

        // MARK: Wrapped Errors related to Lexing or Parsing
        /// Errors due to malformed template syntax or grammar
        case lexerError(LexerError)
        /// Errors due to malformed template syntax or grammar
        case parserError(ParserError)
        
        case invalidIdentifier(String)

        /// Error due to timeout (may or may not be permanent)
        case timeout(Double)
        
        // MARK: Errors lacking specificity
        /// General errors occuring prior to running LeafKit
        case configurationError(String)
        /// Errors from protocol adherents that do not support newer features
        case unsupportedFeature(String)
        /// Errors only when no existing error reason is adequately clear
        case unknownError(String)
    }

    /// Source file name causing error
    public let file: String
    /// Source function causing error
    public let function: String
    /// Source file line causing error
    public let line: UInt
    /// Source file column causing error
    public let column: UInt
    /// The specific reason for the error
    public let reason: Reason

    /// Provide  a custom description of the `LeafError` based on type.
    ///
    /// - Where errors are caused by toolchain faults, will report the Swift source code location of the call
    /// - Where errors are from Lex or Parse errors, will report the template source location of the error
    var localizedDescription: String {
        var m = "\(file.split(separator: "/").last ?? "?").\(function):\(line)\n"
        switch reason {
            case .illegalAccess(let r)        : m += r
            case .unknownError(let r)         : m += r
            case .unsupportedFeature(let f)   : m += "\(f) not implemented"
            case .cachingDisabled             : m += "Caching is globally disabled"
            case .keyExists(let k)            : m += "Existing entry \(k)"
            case .noValueForKey(let k)        : m += "No cache entry exists for \(k)"
            case .noTemplateExists(let k)     : m += "No template found for \(k)"
            case .unresolvedAST(let k, let d) : m += "\(k) has unresolved dependencies: \(d)"
            case .timeout(let d)              : m += "Exceeded timeout at \(d.formatSeconds())"
            case .configurationError(let d)   : m += "Configuration error: \(d)"
            case .missingRaw(let f)           : m += "Missing raw inline file \"\(f)\""
            case .invalidIdentifier(let i)    : m += "\(i) is not a valid Leaf identifier"
            case .cyclicalReference(let k, let c)
                : m += "\(k) cyclically referenced in [\((c + ["!\(k)"]).joined(separator: " -> "))]"
                
            case .lexerError(let e)           : m = "Lexing error - \(e.description)"
            case .parserError(let e)          : m = "Parse error - \(e.description)"
        }
        return m
    }

    public var description: String { localizedDescription }

    /// Create a `LeafError` - only `reason` typically used as source locations are auto-grabbed
    public init(_ reason: Reason,
                _ file: String = #file,
                _ function: String = #function,
                _ line: UInt = #line,
                _ column: UInt = #column) {
        self.file = file
        self.function = function
        self.line = line
        self.column = column
        self.reason = reason
    }
}

// MARK: - `LexerError` Summary (Wrapped by LeafError)

/// `LexerError` reports errors during the stage.
public struct LexerError: Error, CustomStringConvertible {
    // MARK: - Public

    public enum Reason {
        // MARK: Errors occuring during Lexing
        /// A character not usable in parameters is present when Lexer is not expecting it
        case invalidParameterToken(Character)
        /// An invalid operator was used
        case invalidOperator(LeafOperator)
        /// A string was opened but never terminated by end of line
        case unterminatedStringLiteral
        /// Use in place of fatalError to indicate extreme issue
        case unknownError(String)
    }

    /// Stated reason for error
    public let reason: Reason
    /// Template source file line where error occured
    public let line: Int
    /// Template source column where error occured
    public let column: Int
    /// Name of template error occured in
    public let name: String

    // MARK: - Internal Only

    /// State of tokens already processed by Lexer prior to error
    internal let lexed: [LKToken]
    /// Flag to true if lexing error is something that may be recoverable during parsing;
    /// EG, `"#anhtmlanchor"` may lex as a tag name but fail to tokenize to tag because it isn't
    /// followed by a left paren. Parser may be able to recover by decaying it to `.raw`.
    internal let recoverable: Bool

    /// Create a `LexerError`
    /// - Parameters:
    ///   - reason: The specific reason for the error
    ///   - src: File being lexed
    ///   - lexed: `LKTokens` already lexed prior to error
    ///   - recoverable: Flag to say whether the error can potentially be recovered during Parse
    internal init(_ reason: Reason,
                  _ src: LKRawTemplate,
                  _ lexed: [LKToken] = [],
                  recoverable: Bool = false) {
        self.reason = reason
        self.lexed = lexed
        self.line = src.line
        self.column = src.column
        self.name = src.name
        self.recoverable = recoverable
    }

    /// Convenience description of source file name, error reason, and location in file of error source
    var localizedDescription: String { "\"\(name)\": \(reason) - \(line):\(column)" }
    public var description: String { localizedDescription }
}

// MARK: - `ParserError` Summary (Wrapped by LeafError)
/// `ParserError` reports errors during the stage.
public struct ParserError: Error, CustomStringConvertible {
    public enum Reason: CustomStringConvertible {
        case noEntity(String, String)
        case sameName(String, String, [String])
        
        public var description: String {
            var message = ""
            switch self {
                case .noEntity(let t, let name): message += "No \(t) named `\(name)` exists"
                case .sameName(let t, let name, let matches):
                    message += "No exact match for \(t) \(name); \(matches.count) possible matches:"
                    message += matches.map { "\(name)\($0)" }.joined(separator: "\n")
            }
            return message
        }
    }
    
    public let reason: Reason
    public internal(set) var line: Int = 0
    public internal(set) var column: Int = 0
    public internal(set) var name: String = ""
    
    internal init(_ reason: Reason) { self.reason = reason }
    
    /// Convenience description of source file name, error reason, and location in file of error source
    var localizedDescription: String { "\"\(name)\": \(reason.description) - \(line):\(column)" }
    public var description: String { localizedDescription }
}


// MARK: - Internal Conveniences

@inline(__always)
func err(_ cause: LeafErrorCause,
         _ file: String = #file,
         _ function: String = #function,
         _ line: UInt = #line,
         _ column: UInt = #column) -> LeafError { .init(cause, String(file.split(separator: "/").last ?? ""), function, line, column) }

@inline(__always)
func err(_ reason: String,
         _ file: String = #file,
         _ function: String = #function,
         _ line: UInt = #line,
         _ column: UInt = #column) -> LeafError { err(.unknownError(reason), file, function, line, column) }

@inline(__always)
func parseErr(_ cause: ParseErrorCause) -> LeafError { .init(.parserError(.init(cause))) }

@inline(__always)
func succeed<T>(_ value: T, on eL: EventLoop) -> ELF<T> { eL.makeSucceededFuture(value) }

@inline(__always)
func fail<T>(_ error: LeafError, on eL: EventLoop) -> ELF<T> { eL.makeFailedFuture(error) }

@inline(__always)
func fail<T>(_ error: LeafErrorCause, on eL: EventLoop,
             _ file: String = #file, _ function: String = #function,
             _ line: UInt = #line, _ column: UInt = #column) -> ELF<T> {
    fail(LeafError(error, file, function, line, column), on: eL) }

func __MajorBug(_ message: String = "Unspecified",
                _ file: String = #file,
                _ function: String = #function,
                _ line: UInt = #line) -> Never {
    fatalError("""
    LeafKit Major Bug: "\(message)"
    Please File Issue Immediately at https://github.com/vapor/leaf-kit/issues
      - Reference "fatalError in `\(file.split(separator: "/").last ?? "").\(function) line \(line)`"
    """)
}

func __Unreachable(_ file: String = #file,
                   _ function: String = #function,
                   _ line: UInt = #line) -> Never {
    __MajorBug("Unreachable Switch Case", file, function, line) }
