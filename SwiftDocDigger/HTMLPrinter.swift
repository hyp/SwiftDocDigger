//
//  HTMLPrinter.swift
//  SwiftDocDigger
//

import Foundation

public func printSwiftDocToHTML(documentation: [DocumentationNode]) -> String {
    let printer = HTMLPrinter()
    printer.printNodes(documentation)
    return printer.output
}

private class HTMLPrinter {
    var output: String = ""

    func writeText(string: String) {
        let escaped = CFXMLCreateStringByEscapingEntities(nil, string, nil) as String
        escaped.writeTo(&output)
    }

    func writeHtml(html: String) {
        html.writeTo(&output)
    }

    func writeElement(tag: String, node: DocumentationNode) {
        writeHtml("<\(tag)>")
        printNodes(node.children)
        writeHtml("</\(tag)>")
    }

    func writeElement(tag: String, attributes: [String: String], node: DocumentationNode) {
        writeHtml("<\(tag)")
        for (name, value) in attributes {
            writeHtml(" \(name)=\"\(value)\"")
        }
        writeHtml(">")
        printNodes(node.children)
        writeHtml("</\(tag)>")
    }

    func printNode(node: DocumentationNode) {
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
            writeHtml(html)
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
        case .Label(let label):
            writeHtml("<dt>\(label): </dt><dd>")
            printNodes(node.children)
            writeHtml("</dd>")
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
