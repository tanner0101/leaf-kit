public typealias ResolvedDocument = LeafAST

// Internal combination of rawAST = nil indicates no external references
// rawAST non-nil & flat = false : unresolved with external references, and public AST is not flat
// rawAST non-nil & flat = true : resolved with external references, and public AST is flat
public struct LeafAST: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(name) }
    public static func == (lhs: LeafAST, rhs: LeafAST) -> Bool { lhs.name == rhs.name }

    let name: String

    private var rawAST: [Syntax]?

    private(set) var ast: [Syntax]
    private(set) var externalRefs = Set<String>()
    private(set) var unresolvedRefs = Set<String>()
    private(set) var flat: Bool

    init(name: String, ast: [Syntax]) {
        self.name = name
        self.ast = ast
        self.rawAST = nil
        self.flat = false

        updateRefs([:])
    }

     init(from: LeafAST, referencing externals: [String: LeafAST]) {
        self.name = from.name
        self.ast = from.ast
        self.rawAST = from.rawAST
        self.externalRefs = from.externalRefs
        self.unresolvedRefs = from.unresolvedRefs
        self.flat = from.flat

        updateRefs(externals)
    }

    mutating private func updateRefs(_ externals: [String: LeafAST]) {
        var firstRun = false
        if rawAST == nil, flat == false { rawAST = ast; firstRun = true }
        unresolvedRefs.removeAll()
        var pos = ast.startIndex

        // inline provided externals
        while pos < ast.endIndex {
            // get desired externals for this Syntax - if none, continue
            let wantedExts = ast[pos].externals()
            if wantedExts.isEmpty {
                pos = ast.index(after: pos)
                continue
            }
            // see if we can provide any of them - if not, continue
            let providedExts = externals.filter { wantedExts.contains($0.key) }
            if providedExts.isEmpty {
                unresolvedRefs.formUnion(wantedExts)
                pos = ast.index(after: pos)
                continue
            }
            
            // replace the original Syntax with the results of inlining, potentially 1...n
            let replacementSyntax = ast[pos].inlineRefs(providedExts, [:])
            ast.replaceSubrange(pos...pos, with: replacementSyntax)
            // any returned new inlined syntaxes can't be further resolved at this point
            // but we need to add their unresolvable references to the global set
            var offset = replacementSyntax.startIndex
            while offset < replacementSyntax.endIndex {
                unresolvedRefs.formUnion(ast[pos].externals())
                offset = replacementSyntax.index(after: offset)
                pos = ast.index(after: pos)
            }
        }

        // compress raws
        pos = ast.startIndex
        while pos < ast.index(before: ast.endIndex) {
            if case .raw(var syntax) = ast[pos] {
                if case .raw(var add) = ast[ast.index(after: pos)] {
                    var buffer = ByteBufferAllocator().buffer(capacity: syntax.readableBytes + add.readableBytes)
                    buffer.writeBuffer(&syntax)
                    buffer.writeBuffer(&add)
                    ast[pos] = .raw(buffer)
                    ast.remove(at: ast.index(after: pos) )
                } else { pos = ast.index(after: pos) }
            } else { pos = ast.index(after: pos) }
        }

        flat = unresolvedRefs.isEmpty ? true : false
        if firstRun && flat { rawAST = nil }
    }
}
