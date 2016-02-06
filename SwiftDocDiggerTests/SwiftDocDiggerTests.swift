//
//  SwiftDocDiggerTests.swift
//  SwiftDocDiggerTests
//

import XCTest
@testable import SwiftDocDigger

extension DocumentationNode : Equatable {
}

public func == (lhs: DocumentationNode, rhs: DocumentationNode) -> Bool {
    switch (lhs.element, rhs.element) {
    case (.Text(let x), .Text(let y)) where x == y:
        break
    case (.RawHTML(let x), .RawHTML(let y)) where x == y:
        break
    case (.Link(let x), .Link(let y)) where x == y:
        break
    case (.CodeBlock(let x), .CodeBlock(let y)) where x == y:
        break
    case (.Label(let x), .Label(let y)) where x == y:
        break
    case (.Other(let x), .Other(let y)) where x == y:
        break
    case (.Paragraph, .Paragraph), (.CodeVoice, .CodeVoice), (.Emphasis, .Emphasis), (.Strong, .Strong), (.Bold, .Bold), (.BulletedList, .BulletedList), (.NumberedList, .NumberedList), (.ListItem, .ListItem), (.NumberedCodeLine, .NumberedCodeLine):
        break
    default:
        return false
    }
    guard lhs.children.count == rhs.children.count else {
        return false
    }
    return zip(lhs.children, rhs.children).reduce(true) { $0 ? $1.0 == $1.1 : false }
}

class SwiftDocDiggerTests: XCTestCase {

    func testDocEmptyXML() {
        do {
            let result = try parseSwiftDocAsXML("")
            XCTAssertNil(result)
        } catch {
            XCTFail()
        }
    }

    func testDocXMLParseErrors() {
        do {
            try parseSwiftDocAsXML("<Class><Name>Int</Name><Abstract><Para></Abstract></Class>")
            XCTFail()
        } catch SwiftDocXMLError.ParseError(let error) {
            XCTAssertEqual(error.domain, NSXMLParserErrorDomain)
        } catch {
            XCTFail()
        }

        do {
            try parseSwiftDocAsXML("<Class><Name>Int</Name><Abstract><Link>Foo</Link>A</Abstract></Class>")
            XCTFail()
        } catch SwiftDocXMLError.MissingRequiredAttribute(element: "Link", attribute: "href") {
        } catch {
            XCTFail()
        }

        do {
            try parseSwiftDocAsXML("<Class><Name>Int</Name><Abstract>B</Abstract><Abstract>A</Abstract></Class>")
            XCTFail()
        } catch SwiftDocXMLError.MoreThanOneElement("Abstract") {
        } catch {
            XCTFail()
        }

        do {
            try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Name>Bound</Name><Name>Another one</Name><Discussion><Para>Test.</Para></Discussion></Parameter></Parameters></Class>")
            XCTFail()
        } catch SwiftDocXMLError.MoreThanOneElement("Parameter.Name") {
        } catch {
            XCTFail()
        }

        do {
            try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Discussion><Para>Test.</Para></Discussion></Parameter></Parameters></Class>")
            XCTFail()
        } catch SwiftDocXMLError.MissingRequiredChildElement("Parameter", "Name") {
        } catch {
            XCTFail()
        }

        do {
            try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Name></Name><Discussion><Para>Test.</Para></Discussion></Parameter></Parameters></Class>")
            XCTFail()
        } catch SwiftDocXMLError.MissingRequiredChildElement("Parameter", "Name") {
        } catch {
            XCTFail()
        }

        do {
            try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameter><Name>Test</Name><Discussion><Para>Test.</Para></Discussion></Parameter></Class>")
            XCTFail()
        } catch SwiftDocXMLError.ElementNotInsideExpectedParentElement("Parameter", "Parameters") {
        } catch {
            XCTFail()
        }
    }

    func testDocXMLParsing() {
        do {
            let source = "<Class><Name>Int</Name><USR>s:Si</USR><Declaration>struct Int : SignedIntegerType, Comparable, Equatable</Declaration><Abstract><Para>A 64-bit signed integer value type.</Para></Abstract></Class>"
            guard let result = try parseSwiftDocAsXML(source),
                declaration = result.declaration,
                abstract = result.abstract else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.discussion)
            XCTAssertNil(result.parameters)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .Text("struct Int : SignedIntegerType, Comparable, Equatable")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("A 64-bit signed integer value type.")) ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Class><Name>String</Name><USR>s:SS</USR><Declaration>struct String</Declaration><Abstract><Para>An arbitrary Unicode string value.</Para></Abstract><Discussion><rawHTML><![CDATA[<h1>]]></rawHTML>Unicode-Correct<rawHTML><![CDATA[</h1>]]></rawHTML><Para>Swift strings blah blah blah <codeVoice>==</codeVoice> operator checks for <Link href=\"http://www.unicode.org/glossary/#deterministic_comparison\">Unicode canonical equivalence</Link>, so etc etc.</Para><Para><emphasis>Test A</emphasis><strong>Test B</strong><bold>Another one</bold></Para><List-Bullet><Item>A</Item><Item>BB</Item><Item>CCC</Item></List-Bullet><CodeListing language=\"swift\"><zCodeLineNumbered><![CDATA[var a = \"foo\"]]></zCodeLineNumbered><zCodeLineNumbered><![CDATA[print(\"a=\\(a), b=???\")     // a=foo, b=foobar]]></zCodeLineNumbered><zCodeLineNumbered></zCodeLineNumbered></CodeListing><List-Number><Item>Foo</Item><Item>Bar</Item></List-Number></Discussion></Class>"
            guard let result = try parseSwiftDocAsXML(source),
                declaration = result.declaration,
                abstract = result.abstract,
                discussion = result.discussion else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.parameters)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .Text("struct String")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("An arbitrary Unicode string value.")) ]))
            XCTAssertEqual(discussion.count, 8)
            XCTAssertEqual(discussion[0], DocumentationNode(element: .RawHTML("<h1>")))
            XCTAssertEqual(discussion[1], DocumentationNode(element: .Text("Unicode-Correct")))
            XCTAssertEqual(discussion[2], DocumentationNode(element: .RawHTML("</h1>")))
            XCTAssertEqual(discussion[3], DocumentationNode(element: .Paragraph, children: [
                DocumentationNode(element: .Text("Swift strings blah blah blah ")),
                DocumentationNode(element: .CodeVoice, children: [ DocumentationNode(element: .Text("==")) ]),
                DocumentationNode(element: .Text(" operator checks for ")),
                DocumentationNode(element: .Link(href: "http://www.unicode.org/glossary/#deterministic_comparison"), children: [ DocumentationNode(element: .Text("Unicode canonical equivalence")) ]),
                DocumentationNode(element: .Text(", so etc etc."))
                ]))
            XCTAssertEqual(discussion[4], DocumentationNode(element: .Paragraph, children: [
                DocumentationNode(element: .Emphasis, children: [ DocumentationNode(element: .Text("Test A")) ]),
                DocumentationNode(element: .Strong, children: [ DocumentationNode(element: .Text("Test B")) ]),
                DocumentationNode(element: .Bold, children: [ DocumentationNode(element: .Text("Another one")) ])
                ]))
            XCTAssertEqual(discussion[5], DocumentationNode(element: .BulletedList, children: [
                DocumentationNode(element: .ListItem, children: [ DocumentationNode(element: .Text("A")) ]),
                DocumentationNode(element: .ListItem, children: [ DocumentationNode(element: .Text("BB")) ]),
                DocumentationNode(element: .ListItem, children: [ DocumentationNode(element: .Text("CCC")) ])
                ]))
            XCTAssertEqual(discussion[6], DocumentationNode(element: .CodeBlock(language: "swift"), children: [
                DocumentationNode(element: .NumberedCodeLine, children: [ DocumentationNode(element: .Text("var a = \"foo\"")) ]),
                DocumentationNode(element: .NumberedCodeLine, children: [ DocumentationNode(element: .Text("print(\"a=\\(a), b=???\")     // a=foo, b=foobar")) ]),
                DocumentationNode(element: .NumberedCodeLine)
                ]))
            XCTAssertEqual(discussion[7], DocumentationNode(element: .NumberedList, children: [
                DocumentationNode(element: .ListItem, children: [ DocumentationNode(element: .Text("Foo")) ]),
                DocumentationNode(element: .ListItem, children: [ DocumentationNode(element: .Text("Bar")) ])
                ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Function><Name>generate()</Name><USR>s:FVs26AnyBidirectionalCollection8generateFT_GVs12AnyGeneratorx_</USR><Declaration>func generate()</Declaration><Abstract><Para>Returns a generator over the elements of this collection.</Para></Abstract><Discussion><Complexity><Para>O(1).</Para></Complexity><Note>Something</Note><See>That</See></Discussion><Discussion><Para>Part 2</Para></Discussion><Discussion><MyLabel>AF</MyLabel></Discussion></Function>"
            guard let result = try parseSwiftDocAsXML(source),
                declaration = result.declaration,
                abstract = result.abstract,
                discussion = result.discussion else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.parameters)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .Text("func generate()")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("Returns a generator over the elements of this collection.")) ]))
            XCTAssertEqual(discussion.count, 5)
            XCTAssertEqual(discussion[0], DocumentationNode(element: .Label("Complexity"), children: [
                DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("O(1).")) ])
                ]))
            XCTAssertEqual(discussion[1], DocumentationNode(element: .Label("Note"), children: [
                DocumentationNode(element: .Text("Something"))
                ]))
            XCTAssertEqual(discussion[2], DocumentationNode(element: .Label("See also"), children: [
                DocumentationNode(element: .Text("That"))
                ]))
            XCTAssertEqual(discussion[3], DocumentationNode(element: .Paragraph, children: [
                DocumentationNode(element: .Text("Part 2"))
                ]))
            XCTAssertEqual(discussion[4], DocumentationNode(element: .Other("MyLabel"), children: [
                DocumentationNode(element: .Text("AF"))
                ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Function><Name>advancedBy(_:)</Name><USR>s:FPs16ForwardIndexType10advancedByFwx8Distancex</USR><Declaration>@warn_unused_result\nfunc advancedBy(n: Self.Distance)</Declaration><Abstract><Para>Return the result of advancing self by n positions.</Para></Abstract><ResultDiscussion><Para>Results are valid</Para></ResultDiscussion></Function>"
            guard let result = try parseSwiftDocAsXML(source),
                declaration = result.declaration,
                abstract = result.abstract,
                resultDiscussion = result.resultDiscussion else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.discussion)
            XCTAssertNil(result.parameters)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .Text("@warn_unused_result\nfunc advancedBy(n: Self.Distance)")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("Return the result of advancing self by n positions.")) ]))
            XCTAssertEqual(resultDiscussion.count, 1)
            XCTAssertEqual(resultDiscussion[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("Results are valid"))
                ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Name>Bound</Name><Direction isExplicit=\"0\">in</Direction><Discussion><Para>The type of the endpoints.</Para></Discussion></Parameter><Parameter><Name>Test</Name><Discussion><Para>Part 1</Para></Discussion><Discussion><Para>Fin.</Para></Discussion></Parameter></Parameters></Class>"
            guard let result = try parseSwiftDocAsXML(source),
                declaration = result.declaration,
                abstract = result.abstract,
                parameters = result.parameters else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.discussion)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .Text("struct ClosedInterval")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("A closed IntervalType.")) ]))
            XCTAssertEqual(parameters.count, 2)
            XCTAssertEqual(parameters[0].name, "Bound")
            do {
                guard let discussion = parameters[0].discussion else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(discussion.count, 1)
                XCTAssertEqual(discussion[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("The type of the endpoints."))
                    ]))
            }
            XCTAssertEqual(parameters[1].name, "Test")
            do {
                guard let discussion = parameters[1].discussion else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(discussion.count, 2)
                XCTAssertEqual(discussion[0], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("Part 1"))
                    ]))
                XCTAssertEqual(discussion[1], DocumentationNode(element: .Paragraph, children: [ DocumentationNode(element: .Text("Fin."))
                    ]))
            }
        } catch {
            XCTFail()
        }
    }

    func testHTMLOutput() {
        XCTAssertEqual(printSwiftDocToHTML([ DocumentationNode(element: .Text("test")) ]), "test")
        XCTAssertEqual(printSwiftDocToHTML([ DocumentationNode(element: .Text("test < 2")) ]), "test &lt; 2")
        XCTAssertEqual(printSwiftDocToHTML([
            DocumentationNode(element: .Paragraph, children: [
                DocumentationNode(element: .Text("a ")),
                DocumentationNode(element: .Text("bc")),
                DocumentationNode(element: .Strong, children: [
                    DocumentationNode(element: .Text(" >ef"))
                ])
            ]),
            DocumentationNode(element: .Paragraph, children: [
                DocumentationNode(element: .Text("This is")),
                DocumentationNode(element: .CodeVoice, children: [
                    DocumentationNode(element: .Text("func main()"))
                ])
            ]),
            DocumentationNode(element: .Paragraph, children: [
                DocumentationNode(element: .Text("Get swift at ")),
                DocumentationNode(element: .Link(href: "http://swift.org"), children: [
                    DocumentationNode(element: .Text("the website"))
                ])
            ])
        ]), "<p>a bc<strong> &gt;ef</strong></p><p>This is<code>func main()</code></p><p>Get swift at <a href=\"http://swift.org\">the website</a></p>")
    }
}
