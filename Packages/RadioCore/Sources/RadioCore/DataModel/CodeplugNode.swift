import Foundation

/// A node in the codeplug tree structure, representing either a group of fields
/// (e.g., "Channel 1") or a repeating section (e.g., "Channels").
public struct CodeplugNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
    public let category: FieldCategory
    public let nodeType: NodeType
    public let fields: [FieldDefinition]
    public let children: [CodeplugNode]

    public init(
        id: String,
        name: String,
        displayName: String,
        category: FieldCategory,
        nodeType: NodeType = .group,
        fields: [FieldDefinition] = [],
        children: [CodeplugNode] = []
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.category = category
        self.nodeType = nodeType
        self.fields = fields
        self.children = children
    }

    /// The type of node in the tree.
    public enum NodeType: Sendable {
        /// A single group of fields (e.g., "General Settings").
        case group
        /// A repeating section (e.g., "Channels" with N channel entries).
        case repeating(count: Int, stride: Int)
    }

    /// All field definitions in this node and its descendants.
    public var allFields: [FieldDefinition] {
        var result = fields
        for child in children {
            result.append(contentsOf: child.allFields)
        }
        return result
    }
}
