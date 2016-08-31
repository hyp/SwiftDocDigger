//
//  DocXMLParser.swift
//  SwiftDocDigger
//

import Foundation

public enum SwiftDocXMLError : Error {
    case unknownParseError

    /// An xml parse error.
    case parseError(Error)

    /// A required attribute is missing, e.g. <Link> without href attribute.
    case missingRequiredAttribute(element: String, attribute: String)

    /// A required child element is missing e.g. <Parameter> without the <Name>.
    case missingRequiredChildElement(element: String, childElement: String)

    /// More than one element is specified where just one is needed.
    case moreThanOneElement(element: String)

    /// An element is outside of its supposed parent.
    case elementNotInsideExpectedParentElement(element: String, expectedParentElement: String)
}

/// Parses swift's XML documentation.
public func parseSwiftDocAsXML(_ source: String) throws -> Documentation? {
    guard !source.isEmpty else {
        return nil
    }
    guard let data = source.data(using: String.Encoding.utf8) else {
        assertionFailure()
        return nil
    }
    let delegate = SwiftXMLDocParser()
    do {
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            guard let error = parser.parserError else {
                throw SwiftDocXMLError.unknownParseError
            }
            throw SwiftDocXMLError.parseError(error)
        }
    }
    if let error = delegate.parseError {
        throw error
    }
    assert(delegate.stack.isEmpty)
    return Documentation(declaration: delegate.declaration, abstract: delegate.abstract, discussion: delegate.discussion, parameters: delegate.parameters, resultDiscussion: delegate.resultDiscussion)
}

private class SwiftXMLDocParser: NSObject, XMLParserDelegate {
    enum StateKind {
        case root
        case declaration
        case abstract
        case discussion
        case parameters
        case parameter(name: NSMutableString, discussion: [DocumentationNode]?)
        case parameterName(NSMutableString)
        case parameterDiscussion
        case resultDiscussion
        case node(DocumentationNode.Element)
        // Some other node we don't really care about.
        case other
    }
    struct State {
        var kind: StateKind
        let elementName: String
        var nodes: [DocumentationNode]
    }

    var stack: [State] = []
    var parameterDepth = 0
    var hasFoundRoot = false
    var parseError: SwiftDocXMLError?
    // The results
    var declaration: [DocumentationNode]?
    var abstract: [DocumentationNode]?
    var discussion: [DocumentationNode]?
    var resultDiscussion: [DocumentationNode]?
    var parameters: [Documentation.Parameter]?

    func add(_ element: DocumentationNode.Element, children: [DocumentationNode] = []) {
        guard !stack.isEmpty else {
            assertionFailure()
            return
        }
        stack[stack.count - 1].nodes.append(DocumentationNode(element: element, children: children))
    }

    func replaceTop(_ state: StateKind) {
        assert(!stack.isEmpty)
        stack[stack.count - 1].kind = state
    }

    func handleError(_ error: SwiftDocXMLError) {
        guard parseError == nil else {
            return
        }
        parseError = error
    }

    @objc func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        func push(_ state: StateKind) {
            stack.append(State(kind: state, elementName: elementName, nodes: []))
        }
        
        if stack.isEmpty {
            // Root node.
            assert(!hasFoundRoot)
            assert(elementName == "Class" || elementName == "Function" || elementName == "Other")
            push(.root)
            hasFoundRoot = true
            return
        }
        if case .parameter? = stack.last?.kind {
            // Parameter information.
            switch elementName {
            case "Name":
                assert(parameterDepth > 0)
                push(.parameterName(""))
            case "Discussion":
                assert(parameterDepth > 0)
                push(.parameterDiscussion)
            default:
                // Don't really care about the other nodes here (like Direction).
                push(.other)
            }
            return
        }
        switch elementName {
        case "Declaration":
            push(.declaration)
        case "Abstract":
            push(.abstract)
        case "Discussion":
            push(.discussion)
        case "Parameters":
            push(.parameters)
        case "Parameter":
            assert(parameterDepth == 0)
            parameterDepth += 1
            let last = stack.last
            push(.parameter(name: "", discussion: nil))
            guard case .parameters? = last?.kind else {
                handleError(.elementNotInsideExpectedParentElement(element: elementName, expectedParentElement: "Parameters"))
                return
            }
        case "ResultDiscussion":
            push(.resultDiscussion)
        case "Para":
            push(.node(.paragraph))
        case "rawHTML":
            push(.node(.rawHTML("")))
        case "codeVoice":
            push(.node(.codeVoice))
        case "Link":
            guard let href = attributeDict["href"] else {
                handleError(.missingRequiredAttribute(element: elementName, attribute: "href"))
                push(.other)
                return
            }
            push(.node(.link(href: href)))
        case "emphasis":
            push(.node(.emphasis))
        case "strong":
            push(.node(.strong))
        case "bold":
            push(.node(.bold))
        case "List-Bullet":
            push(.node(.bulletedList))
        case "List-Number":
            push(.node(.numberedList))
        case "Item":
            push(.node(.listItem))
        case "CodeListing":
            push(.node(.codeBlock(language: attributeDict["language"])))
        case "zCodeLineNumbered":
            push(.node(.numberedCodeLine))
        case "Complexity", "Note", "Requires", "Warning", "Postcondition", "Precondition":
            push(.node(.label(elementName)))
        case "See":
            push(.node(.label("See also")))
        case "Name", "USR":
            guard case .root? = stack.last?.kind else {
                assertionFailure("This node is expected to be immediately inside the root node.")
                return
            }
            // Don't really need these ones.
            push(.other)
        default:
            push(.node(.other(elementName)))
        }
    }

    @objc func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let top = stack.popLast() else {
            assertionFailure("Invalid XML")
            return
        }
        assert(top.elementName == elementName)
        switch top.kind {
        case .node(let element):
            add(element, children: top.nodes)
        case .abstract:
            guard abstract == nil else {
                handleError(.moreThanOneElement(element: elementName))
                return
            }
            abstract = top.nodes
        case .declaration:
            guard declaration == nil else {
                handleError(.moreThanOneElement(element: elementName))
                return
            }
            declaration = top.nodes
        case .discussion:
            // Docs can have multiple discussions.
            discussion = discussion.flatMap { $0 + top.nodes } ?? top.nodes
        case .parameter(let nameString, let discussion):
            assert(parameterDepth > 0)
            parameterDepth -= 1
            let name = nameString as String
            guard !name.isEmpty else {
                handleError(.missingRequiredChildElement(element: "Parameter", childElement: "Name"))
                return
            }
            let p = Documentation.Parameter(name: name, discussion: discussion)
            parameters = parameters.flatMap { $0 + [ p ] } ?? [ p ]
        case .parameterName(let nameString):
            assert(parameterDepth > 0)
            let name = nameString as String
            guard !name.isEmpty else {
                handleError(.missingRequiredChildElement(element: "Parameter", childElement: "Name"))
                return
            }
            assert(top.nodes.isEmpty, "Other nodes present in parameter name")
            switch stack.last?.kind {
            case .parameter(let currentName, _)?:
                guard (currentName as String).isEmpty else {
                    handleError(.moreThanOneElement(element: "Parameter.Name"))
                    return
                }
                currentName.setString(name)
            default:
                assertionFailure()
            }
        case .parameterDiscussion:
            assert(parameterDepth > 0)
            switch stack.last?.kind {
            case .parameter(let name, let discussion)?:
                // Parameters can have multiple discussions.
                replaceTop(.parameter(name: name, discussion: discussion.flatMap { $0 + top.nodes } ?? top.nodes))
            default:
                assertionFailure()
            }
        case .resultDiscussion:
            guard resultDiscussion == nil else {
                handleError(.moreThanOneElement(element: elementName))
                return
            }
            resultDiscussion = top.nodes
        default:
            break
        }
    }

    @objc func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard stack.count > 1 else {
            return
        }
        if case .parameterName(let name)? = stack.last?.kind {
            name.append(string)
            return
        }
        add(.text(string))
    }

    @objc func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let str = String(data: CDATABlock, encoding: String.Encoding.utf8) else {
            assertionFailure()
            return
        }
        switch stack.last?.kind {
        case .node(.rawHTML(let html))?:
            replaceTop(.node(.rawHTML(html + str)))
            break
        case .node(.numberedCodeLine)?:
            add(.text(str))
            break
        default:
            assertionFailure("Unsupported data block")
        }
    }
}
