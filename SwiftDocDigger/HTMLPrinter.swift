//
//  HTMLPrinter.swift
//  SwiftDocDigger
//

import Foundation

public protocol HTMLPrinter: class {
    func writeText(_ string: String)
    func writeHTML(_ html: String)
    func printNodes(_ nodes: [DocumentationNode])
}

public protocol HTMLPrinterDelegate: class {
    /// Returns true if this node should be printed using the default behaviour.
    func HTMLPrinterShouldPrintNode(_ printer: HTMLPrinter, node: DocumentationNode) -> Bool
}

public func printSwiftDocToHTML(_ documentation: [DocumentationNode], delegate: HTMLPrinterDelegate? = nil) -> String {
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

    func writeText(_ string: String) {
        let escaped = CFXMLCreateStringByEscapingEntities(nil, string as CFString!, nil) as String
        escaped.write(to: &output)
    }

    func writeHTML(_ html: String) {
        html.write(to: &output)
    }

    func writeElement(_ tag: String, node: DocumentationNode) {
        writeHTML("<\(tag)>")
        printNodes(node.children)
        writeHTML("</\(tag)>")
    }

    func writeElement(_ tag: String, attributes: [String: String], node: DocumentationNode) {
        writeHTML("<\(tag)")
        for (name, value) in attributes {
            writeHTML(" \(name)=\"\(value)\"")
        }
        writeHTML(">")
        printNodes(node.children)
        writeHTML("</\(tag)>")
    }

    func printNode(_ node: DocumentationNode) {
        guard delegate?.HTMLPrinterShouldPrintNode(self, node: node) ?? true else {
            return
        }
        func writeElement(_ tag: String) {
            self.writeElement(tag, node: node)
        }

        switch node.element {
        case .text(let string):
            assert(node.children.isEmpty)
            writeText(string)
        case .paragraph:
            writeElement("p")
        case .codeVoice:
            writeElement("code")
        case .emphasis:
            writeElement("em")
        case .bold:
            writeElement("b")
        case .strong:
            writeElement("strong")
        case .rawHTML(let html):
            assert(node.children.isEmpty)
            writeHTML(html)
        case .link(let href):
            self.writeElement("a", attributes: ["href": href], node: node)
        case .bulletedList:
            writeElement("ul")
        case .numberedList:
            writeElement("ol")
        case .listItem:
            writeElement("li")
        case .codeBlock:
            writeElement("pre")
        case .numberedCodeLine:
            // Ignore it (for now?).
            printNodes(node.children)
            writeHTML("\n")
        case .label(let label):
            writeHTML("<dt>\(label): </dt><dd>")
            printNodes(node.children)
            writeHTML("</dd>")
        case .other:
            printNodes(node.children)
        }
    }

    func printNodes(_ nodes: [DocumentationNode]) {
        for node in nodes {
            printNode(node)
        }
    }
}
