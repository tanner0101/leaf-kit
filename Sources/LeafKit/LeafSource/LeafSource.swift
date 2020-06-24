// MARK: Subject to change prior to 1.0.0 release
// MARK: -

/// Public protocol to adhere to in order to provide template source originators to `LeafRenderer`
public protocol LeafSource {
    /// Given a path name, return an EventLoopFuture holding a ByteBuffer
    /// - Parameters:
    ///   - template: Relative template name (eg: `"path/to/template"`)
    ///   - escape: If the adherent represents a filesystem or something scoped that enforces
    ///             a concept of directories and sandboxing, whether to allow escaping the view directory
    ///   - eventLoop: `EventLoop` on which to perform file access
    /// - Returns: A succeeded `EventLoopFuture` holding a `ByteBuffer` with the raw
    ///            template, or an appropriate failed state ELFuture (not found, illegal access, etc)
    func file(template: String,
              escape: Bool,
              on eventLoop: EventLoop) throws -> EventLoopFuture<ByteBuffer>
    
    /// DO NOT IMPLEMENT. Deprecated as of Leaf-Kit 1.0.0rc1.11
    @available(*, deprecated, message: "Update to adhere to `file(template, escape, eventLoop)`")
    func file(path: String, on eventLoop: EventLoop) throws -> EventLoopFuture<ByteBuffer>
}
