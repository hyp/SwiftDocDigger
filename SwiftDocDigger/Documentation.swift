//
//  Documentation.swift
//  SwiftDocDigger
//

/// A documentation node.
public struct DocumentationNode {
    public enum Element {
        case Text(String)
        case Paragraph
        case CodeVoice
        case Emphasis
        case Strong
        case Bold
        case RawHTML(String)
        case Link(href: String)
        case BulletedList
        case NumberedList
        case ListItem
        case CodeBlock(language: String?)
        case NumberedCodeLine
        /// A label, usually written as `- Label: ...` in the comment.
        /// Used to store labels like 'note', 'requirements', etc.
        case Label(String)
        /// Unknown documentation element, possibly a custom label like `- MyLabel: ...`.
        case Other(String)
    }
    public let element: Element
    public let children: [DocumentationNode]

    public init(element: Element, children: [DocumentationNode] = []) {
        self.element = element
        self.children = children
    }
}

/// Documentation for a Swift's declaration.
public struct Documentation {
    public struct Parameter {
        public let name: String
        public let discussion: [DocumentationNode]?
    }

    public let declaration: [DocumentationNode]?
    public let abstract: [DocumentationNode]?
    public let discussion: [DocumentationNode]?
    public let parameters: [Parameter]?
    public let resultDiscussion: [DocumentationNode]?
}
