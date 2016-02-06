//
//  DocXMLParser.swift
//  SwiftDocDigger
//

import Foundation

public enum SwiftDocXMLError : ErrorType {
    case UnknownParseError

    /// An xml parse error.
    case ParseError(NSError)

    /// A required attribute is missing, e.g. <Link> without href attribute.
    case MissingRequiredAttribute(element: String, attribute: String)

    /// A required child element is missing e.g. <Parameter> without the <Name>.
    case MissingRequiredChildElement(element: String, childElement: String)

    /// More than one element is specified where just one is needed.
    case MoreThanOneElement(element: String)

    /// An element is outside of its supposed parent.
    case ElementNotInsideExpectedParentElement(element: String, expectedParentElement: String)
}

/// Parses swift's XML documentation.
public func parseSwiftDocAsXML(source: String) throws -> Documentation? {
    guard !source.isEmpty else {
        return nil
    }
    guard let data = source.dataUsingEncoding(NSUTF8StringEncoding) else {
        assertionFailure()
        return nil
    }
    let delegate = SwiftXMLDocParser()
    do {
        let parser = NSXMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            guard let error = parser.parserError else {
                throw SwiftDocXMLError.UnknownParseError
            }
            throw SwiftDocXMLError.ParseError(error)
        }
    }
    if let error = delegate.parseError {
        throw error
    }
    assert(delegate.stack.isEmpty)
    return Documentation(declaration: delegate.declaration, abstract: delegate.abstract, discussion: delegate.discussion, parameters: delegate.parameters, resultDiscussion: delegate.resultDiscussion)
}

private class SwiftXMLDocParser: NSObject, NSXMLParserDelegate {
    enum StateKind {
        case Root
        case Declaration
        case Abstract
        case Discussion
        case Parameters
        case Parameter(name: NSMutableString, discussion: [DocumentationNode]?)
        case ParameterName(NSMutableString)
        case ParameterDiscussion
        case ResultDiscussion
        case Node(DocumentationNode.Element)
        // Some other node we don't really care about.
        case Other
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

    func add(element: DocumentationNode.Element, children: [DocumentationNode] = []) {
        guard !stack.isEmpty else {
            assertionFailure()
            return
        }
        stack[stack.count - 1].nodes.append(DocumentationNode(element: element, children: children))
    }

    func replaceTop(state: StateKind) {
        assert(!stack.isEmpty)
        stack[stack.count - 1].kind = state
    }

    func handleError(error: SwiftDocXMLError) {
        guard parseError == nil else {
            return
        }
        parseError = error
    }

    @objc func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        func push(state: StateKind) {
            stack.append(State(kind: state, elementName: elementName, nodes: []))
        }
        
        if stack.isEmpty {
            // Root node.
            assert(!hasFoundRoot)
            assert(elementName == "Class" || elementName == "Function" || elementName == "Other")
            push(.Root)
            hasFoundRoot = true
            return
        }
        if case .Parameter? = stack.last?.kind {
            // Parameter information.
            switch elementName {
            case "Name":
                assert(parameterDepth > 0)
                push(.ParameterName(""))
            case "Discussion":
                assert(parameterDepth > 0)
                push(.ParameterDiscussion)
            default:
                // Don't really care about the other nodes here (like Direction).
                push(.Other)
            }
            return
        }
        switch elementName {
        case "Declaration":
            push(.Declaration)
        case "Abstract":
            push(.Abstract)
        case "Discussion":
            push(.Discussion)
        case "Parameters":
            push(.Parameters)
        case "Parameter":
            assert(parameterDepth == 0)
            parameterDepth += 1
            let last = stack.last
            push(.Parameter(name: "", discussion: nil))
            guard case .Parameters? = last?.kind else {
                handleError(.ElementNotInsideExpectedParentElement(element: elementName, expectedParentElement: "Parameters"))
                return
            }
        case "ResultDiscussion":
            push(.ResultDiscussion)
        case "Para":
            push(.Node(.Paragraph))
        case "rawHTML":
            push(.Node(.RawHTML("")))
        case "codeVoice":
            push(.Node(.CodeVoice))
        case "Link":
            guard let href = attributeDict["href"] else {
                handleError(.MissingRequiredAttribute(element: elementName, attribute: "href"))
                push(.Other)
                return
            }
            push(.Node(.Link(href: href)))
        case "emphasis":
            push(.Node(.Emphasis))
        case "strong":
            push(.Node(.Strong))
        case "bold":
            push(.Node(.Bold))
        case "List-Bullet":
            push(.Node(.BulletedList))
        case "List-Number":
            push(.Node(.NumberedList))
        case "Item":
            push(.Node(.ListItem))
        case "CodeListing":
            push(.Node(.CodeBlock(language: attributeDict["language"])))
        case "zCodeLineNumbered":
            push(.Node(.NumberedCodeLine))
        case "Complexity", "Note", "Requires", "Warning", "Postcondition", "Precondition":
            push(.Node(.Label(elementName)))
        case "See":
            push(.Node(.Label("See also")))
        case "Name", "USR":
            guard case .Root? = stack.last?.kind else {
                assertionFailure("This node is expected to be immediately inside the root node.")
                return
            }
            // Don't really need these ones.
            push(.Other)
        default:
            push(.Node(.Other(elementName)))
        }
    }

    @objc func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let top = stack.popLast() else {
            assertionFailure("Invalid XML")
            return
        }
        assert(top.elementName == elementName)
        switch top.kind {
        case .Node(let element):
            add(element, children: top.nodes)
        case .Abstract:
            guard abstract == nil else {
                handleError(.MoreThanOneElement(element: elementName))
                return
            }
            abstract = top.nodes
        case .Declaration:
            guard declaration == nil else {
                handleError(.MoreThanOneElement(element: elementName))
                return
            }
            declaration = top.nodes
        case .Discussion:
            // Docs can have multiple discussions.
            discussion = discussion.flatMap { $0 + top.nodes } ?? top.nodes
        case .Parameter(let nameString, let discussion):
            assert(parameterDepth > 0)
            parameterDepth -= 1
            let name = nameString as String
            guard !name.isEmpty else {
                handleError(.MissingRequiredChildElement(element: "Parameter", childElement: "Name"))
                return
            }
            let p = Documentation.Parameter(name: name, discussion: discussion)
            parameters = parameters.flatMap { $0 + [ p ] } ?? [ p ]
        case .ParameterName(let nameString):
            assert(parameterDepth > 0)
            let name = nameString as String
            guard !name.isEmpty else {
                handleError(.MissingRequiredChildElement(element: "Parameter", childElement: "Name"))
                return
            }
            assert(top.nodes.isEmpty, "Other nodes present in parameter name")
            switch stack.last?.kind {
            case .Parameter(let currentName, _)?:
                guard (currentName as String).isEmpty else {
                    handleError(.MoreThanOneElement(element: "Parameter.Name"))
                    return
                }
                currentName.setString(name)
            default:
                assertionFailure()
            }
        case .ParameterDiscussion:
            assert(parameterDepth > 0)
            switch stack.last?.kind {
            case .Parameter(let name, let discussion)?:
                // Parameters can have multiple discussions.
                replaceTop(.Parameter(name: name, discussion: discussion.flatMap { $0 + top.nodes } ?? top.nodes))
            default:
                assertionFailure()
            }
        case .ResultDiscussion:
            guard resultDiscussion == nil else {
                handleError(.MoreThanOneElement(element: elementName))
                return
            }
            resultDiscussion = top.nodes
        default:
            break
        }
    }

    @objc func parser(parser: NSXMLParser, foundCharacters string: String) {
        guard stack.count > 1 else {
            return
        }
        if case .ParameterName(let name)? = stack.last?.kind {
            name.appendString(string)
            return
        }
        add(.Text(string))
    }

    @objc func parser(parser: NSXMLParser, foundCDATA CDATABlock: NSData) {
        guard let str = String(data: CDATABlock, encoding: NSUTF8StringEncoding) else {
            assertionFailure()
            return
        }
        switch stack.last?.kind {
        case .Node(.RawHTML(let html))?:
            replaceTop(.Node(.RawHTML(html + str)))
            break
        case .Node(.NumberedCodeLine)?:
            add(.Text(str))
            break
        default:
            assertionFailure("Unsupported data block")
        }
    }
}
