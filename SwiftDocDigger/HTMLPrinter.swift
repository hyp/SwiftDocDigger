//
//  HTMLPrinter.swift
//  SwiftDocDigger
//

import Foundation

public protocol HTMLPrinter: class {
    func writeText(string: String)
    func writeHTML(html: String)
    func printNodes(nodes: [DocumentationNode])
}

public protocol HTMLPrinterDelegate: class {
    /// Returns true if this node should be printed using the default behaviour.
    func HTMLPrinterShouldPrintNode(printer: HTMLPrinter, node: DocumentationNode) -> Bool
}

public func printSwiftDocToHTML(documentation: [DocumentationNode], delegate: HTMLPrinterDelegate? = nil) -> String {
    let printer = HTMLPrinterImpl(delegate: delegate)
    printer.printNodes(documentation)
    return printer.output
}

private final class HTMLPrinterImpl: HTMLPrinter {
    weak var delegate: HTMLPrinterDelegate?
    var output: String = ""

    init(delegate: HTMLPrinterDelegate?) {
        self.delegate = delegate
    }

    func writeText(string: String) {
        let escaped = CFXMLCreateStringByEscapingEntities(nil, string, nil) as String
        escaped.writeTo(&output)
    }

    func writeHTML(html: String) {
        html.writeTo(&output)
    }

    func writeElement(tag: String, node: DocumentationNode) {
        writeHTML("<\(tag)>")
        printNodes(node.children)
        writeHTML("</\(tag)>")
    }

    func writeElement(tag: String, attributes: [String: String], node: DocumentationNode) {
        writeHTML("<\(tag)")
        for (name, value) in attributes {
            writeHTML(" \(name)=\"\(value)\"")
        }
        writeHTML(">")
        printNodes(node.children)
        writeHTML("</\(tag)>")
    }

    func printNode(node: DocumentationNode) {
        guard delegate?.HTMLPrinterShouldPrintNode(self, node: node) ?? true else {
            return
        }
        func writeElement(tag: String) {
            self.writeElement(tag, node: node)
        }

        switch node.element {
        case .Text(let string):
            assert(node.children.isEmpty)
            writeText(string)
        case .Paragraph:
            writeElement("p")
        case .CodeVoice:
            writeElement("code")
        case .Emphasis:
            writeElement("em")
        case .Bold:
            writeElement("b")
        case .Strong:
            writeElement("strong")
        case .RawHTML(let html):
            assert(node.children.isEmpty)
            writeHTML(html)
        case .Link(let href):
            self.writeElement("a", attributes: ["href": href], node: node)
        case .BulletedList:
            writeElement("ul")
        case .NumberedList:
            writeElement("ol")
        case .ListItem:
            writeElement("li")
        case .CodeBlock:
            writeElement("pre")
        case .NumberedCodeLine:
            // Ignore it (for now?).
            printNodes(node.children)
            writeHTML("\n")
        case .Label(let label):
            writeHTML("<dt>\(label): </dt><dd>")
            printNodes(node.children)
            writeHTML("</dd>")
        case .Other:
            printNodes(node.children)
        }
    }

    func printNodes(nodes: [DocumentationNode]) {
        for node in nodes {
            printNode(node)
        }
    }
}
