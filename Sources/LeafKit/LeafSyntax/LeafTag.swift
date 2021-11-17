import Foundation

/// Create custom tags by conforming to this protocol and registering them.
public protocol LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData
}

/// Tags conforming to this protocol do not get their contents HTML-escaped.
public protocol UnsafeUnescapedLeafTag: LeafTag {}

public var defaultTags: [String: LeafTag] = [
    "unsafeHTML": UnsafeHTML(),
    "lowercased": Lowercased(),
    "uppercased": Uppercased(),
    "capitalized": Capitalized(),
    "contains": Contains(),
    "date": DateTag(),
    "count": Count(),
    "comment": Comment()
]

struct UnsafeHTML: UnsafeUnescapedLeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        guard let str = ctx.parameters.first?.string else {
            throw "unable to unsafe unexpected data"
        }
        return .init(.string(str))
    }
}

struct Lowercased: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        guard let str = ctx.parameters.first?.string else {
            throw "unable to lowercase unexpected data"
        }
        return .init(.string(str.lowercased()))
    }
}

struct Uppercased: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        guard let str = ctx.parameters.first?.string else {
            throw "unable to uppercase unexpected data"
        }
        return .init(.string(str.uppercased()))
    }
}

struct Capitalized: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        guard let str = ctx.parameters.first?.string else {
            throw "unable to capitalize unexpected data"
        }
        return .init(.string(str.capitalized))
    }
}

struct Contains: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        try ctx.requireParameterCount(2)
        guard let collection = ctx.parameters[0].array else {
            throw "unable to convert first parameter to array"
        }
        let result = collection.contains(ctx.parameters[1])
        return .init(.bool(result))
    }
}

struct DateTag: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        let formatter = DateFormatter()
        switch ctx.parameters.count {
        case 1: formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        case 2:
            guard let string = ctx.parameters[1].string else {
                throw "Unable to convert date format to string"
            }
            formatter.dateFormat = string
        default:
            throw "invalid parameters provided for date"
        }

        guard let dateAsDouble = ctx.parameters.first?.double else {
            throw "Unable to convert parameter to double for date"
        }
        let date = Date(timeIntervalSince1970: dateAsDouble)

        let dateAsString = formatter.string(from: date)
        return LeafData.string(dateAsString)
    }
}

struct Count: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        try ctx.requireParameterCount(1)
        if let array = ctx.parameters[0].array {
            return LeafData.int(array.count)
        } else if let dictionary = ctx.parameters[0].dictionary {
            return LeafData.int(dictionary.count)
        } else {
            throw "Unable to convert count parameter to LeafData collection"
        }
    }
}

struct Comment: LeafTag {
    func render(_ ctx: LeafContext) throws -> LeafData {
        LeafData.trueNil
    }
}
