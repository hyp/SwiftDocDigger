//
//  Documentation.swift
//  SwiftDocDigger
//

/// A documentation node.
public struct DocumentationNode {
    public enum Element {
        case text(String)
        case paragraph
        case codeVoice
        case emphasis
        case strong
        case bold
        case rawHTML(String)
        case link(href: String)
        case bulletedList
        case numberedList
        case listItem
        case codeBlock(language: String?)
        case numberedCodeLine
        /// A label, usually written as `- Label: ...` in the comment.
        /// Used to store labels like 'note', 'requirements', etc.
        case label(String)
        /// Unknown documentation element, possibly a custom label like `- MyLabel: ...`.
        case other(String)
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

    public init(declaration: [DocumentationNode]?, abstract: [DocumentationNode]?, discussion: [DocumentationNode]?, parameters: [Parameter]?, resultDiscussion: [DocumentationNode]?) {
        self.declaration = declaration
        self.abstract = abstract
        self.discussion = discussion
        self.parameters = parameters
        self.resultDiscussion = resultDiscussion
    }
}
