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
    case (.text(let x), .text(let y)) where x == y:
        break
    case (.rawHTML(let x), .rawHTML(let y)) where x == y:
        break
    case (.link(let x), .link(let y)) where x == y:
        break
    case (.codeBlock(let x), .codeBlock(let y)) where x == y:
        break
    case (.label(let x), .label(let y)) where x == y:
        break
    case (.other(let x), .other(let y)) where x == y:
        break
    case (.paragraph, .paragraph), (.codeVoice, .codeVoice), (.emphasis, .emphasis), (.strong, .strong), (.bold, .bold), (.bulletedList, .bulletedList), (.numberedList, .numberedList), (.listItem, .listItem), (.numberedCodeLine, .numberedCodeLine):
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
            let _ = try parseSwiftDocAsXML("<Class><Name>Int</Name><Abstract><Para></Abstract></Class>")
            XCTFail()
        } catch SwiftDocXMLError.parseError(let error) {
            XCTAssertEqual(error.domain, XMLParser.errorDomain)
        } catch {
            XCTFail()
        }

        do {
            let _ = try parseSwiftDocAsXML("<Class><Name>Int</Name><Abstract><Link>Foo</Link>A</Abstract></Class>")
            XCTFail()
        } catch SwiftDocXMLError.missingRequiredAttribute(element: "Link", attribute: "href") {
        } catch {
            XCTFail()
        }

        do {
            let _ = try parseSwiftDocAsXML("<Class><Name>Int</Name><Abstract>B</Abstract><Abstract>A</Abstract></Class>")
            XCTFail()
        } catch SwiftDocXMLError.moreThanOneElement("Abstract") {
        } catch {
            XCTFail()
        }

        do {
            let _ = try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Name>Bound</Name><Name>Another one</Name><Discussion><Para>Test.</Para></Discussion></Parameter></Parameters></Class>")
            XCTFail()
        } catch SwiftDocXMLError.moreThanOneElement("Parameter.Name") {
        } catch {
            XCTFail()
        }

        do {
            let _ = try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Discussion><Para>Test.</Para></Discussion></Parameter></Parameters></Class>")
            XCTFail()
        } catch SwiftDocXMLError.missingRequiredChildElement("Parameter", "Name") {
        } catch {
            XCTFail()
        }

        do {
            let _ = try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Name></Name><Discussion><Para>Test.</Para></Discussion></Parameter></Parameters></Class>")
            XCTFail()
        } catch SwiftDocXMLError.missingRequiredChildElement("Parameter", "Name") {
        } catch {
            XCTFail()
        }

        do {
            let _ = try parseSwiftDocAsXML("<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameter><Name>Test</Name><Discussion><Para>Test.</Para></Discussion></Parameter></Class>")
            XCTFail()
        } catch SwiftDocXMLError.elementNotInsideExpectedParentElement("Parameter", "Parameters") {
        } catch {
            XCTFail()
        }
    }

    func testDocXMLParsing() {
        do {
            let source = "<Class><Name>Int</Name><USR>s:Si</USR><Declaration>struct Int : SignedIntegerType, Comparable, Equatable</Declaration><Abstract><Para>A 64-bit signed integer value type.</Para></Abstract></Class>"
            guard let result = try parseSwiftDocAsXML(source),
                let declaration = result.declaration,
                let abstract = result.abstract else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.discussion)
            XCTAssertNil(result.parameters)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .text("struct Int : SignedIntegerType, Comparable, Equatable")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("A 64-bit signed integer value type.")) ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Class><Name>String</Name><USR>s:SS</USR><Declaration>struct String</Declaration><Abstract><Para>An arbitrary Unicode string value.</Para></Abstract><Discussion><rawHTML><![CDATA[<h1>]]></rawHTML>Unicode-Correct<rawHTML><![CDATA[</h1>]]></rawHTML><Para>Swift strings blah blah blah <codeVoice>==</codeVoice> operator checks for <Link href=\"http://www.unicode.org/glossary/#deterministic_comparison\">Unicode canonical equivalence</Link>, so etc etc.</Para><Para><emphasis>Test A</emphasis><strong>Test B</strong><bold>Another one</bold></Para><List-Bullet><Item>A</Item><Item>BB</Item><Item>CCC</Item></List-Bullet><CodeListing language=\"swift\"><zCodeLineNumbered><![CDATA[var a = \"foo\"]]></zCodeLineNumbered><zCodeLineNumbered><![CDATA[print(\"a=\\(a), b=???\")     // a=foo, b=foobar]]></zCodeLineNumbered><zCodeLineNumbered></zCodeLineNumbered></CodeListing><List-Number><Item>Foo</Item><Item>Bar</Item></List-Number></Discussion></Class>"
            guard let result = try parseSwiftDocAsXML(source),
                let declaration = result.declaration,
                let abstract = result.abstract,
                let discussion = result.discussion else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.parameters)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .text("struct String")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("An arbitrary Unicode string value.")) ]))
            XCTAssertEqual(discussion.count, 8)
            XCTAssertEqual(discussion[0], DocumentationNode(element: .rawHTML("<h1>")))
            XCTAssertEqual(discussion[1], DocumentationNode(element: .text("Unicode-Correct")))
            XCTAssertEqual(discussion[2], DocumentationNode(element: .rawHTML("</h1>")))
            XCTAssertEqual(discussion[3], DocumentationNode(element: .paragraph, children: [
                DocumentationNode(element: .text("Swift strings blah blah blah ")),
                DocumentationNode(element: .codeVoice, children: [ DocumentationNode(element: .text("==")) ]),
                DocumentationNode(element: .text(" operator checks for ")),
                DocumentationNode(element: .link(href: "http://www.unicode.org/glossary/#deterministic_comparison"), children: [ DocumentationNode(element: .text("Unicode canonical equivalence")) ]),
                DocumentationNode(element: .text(", so etc etc."))
                ]))
            XCTAssertEqual(discussion[4], DocumentationNode(element: .paragraph, children: [
                DocumentationNode(element: .emphasis, children: [ DocumentationNode(element: .text("Test A")) ]),
                DocumentationNode(element: .strong, children: [ DocumentationNode(element: .text("Test B")) ]),
                DocumentationNode(element: .bold, children: [ DocumentationNode(element: .text("Another one")) ])
                ]))
            XCTAssertEqual(discussion[5], DocumentationNode(element: .bulletedList, children: [
                DocumentationNode(element: .listItem, children: [ DocumentationNode(element: .text("A")) ]),
                DocumentationNode(element: .listItem, children: [ DocumentationNode(element: .text("BB")) ]),
                DocumentationNode(element: .listItem, children: [ DocumentationNode(element: .text("CCC")) ])
                ]))
            XCTAssertEqual(discussion[6], DocumentationNode(element: .codeBlock(language: "swift"), children: [
                DocumentationNode(element: .numberedCodeLine, children: [ DocumentationNode(element: .text("var a = \"foo\"")) ]),
                DocumentationNode(element: .numberedCodeLine, children: [ DocumentationNode(element: .text("print(\"a=\\(a), b=???\")     // a=foo, b=foobar")) ]),
                DocumentationNode(element: .numberedCodeLine)
                ]))
            XCTAssertEqual(discussion[7], DocumentationNode(element: .numberedList, children: [
                DocumentationNode(element: .listItem, children: [ DocumentationNode(element: .text("Foo")) ]),
                DocumentationNode(element: .listItem, children: [ DocumentationNode(element: .text("Bar")) ])
                ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Function><Name>generate()</Name><USR>s:FVs26AnyBidirectionalCollection8generateFT_GVs12AnyGeneratorx_</USR><Declaration>func generate()</Declaration><Abstract><Para>Returns a generator over the elements of this collection.</Para></Abstract><Discussion><Complexity><Para>O(1).</Para></Complexity><Note>Something</Note><See>That</See></Discussion><Discussion><Para>Part 2</Para></Discussion><Discussion><MyLabel>AF</MyLabel></Discussion></Function>"
            guard let result = try parseSwiftDocAsXML(source),
                let declaration = result.declaration,
                let abstract = result.abstract,
                let discussion = result.discussion else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.parameters)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .text("func generate()")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("Returns a generator over the elements of this collection.")) ]))
            XCTAssertEqual(discussion.count, 5)
            XCTAssertEqual(discussion[0], DocumentationNode(element: .label("Complexity"), children: [
                DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("O(1).")) ])
                ]))
            XCTAssertEqual(discussion[1], DocumentationNode(element: .label("Note"), children: [
                DocumentationNode(element: .text("Something"))
                ]))
            XCTAssertEqual(discussion[2], DocumentationNode(element: .label("See also"), children: [
                DocumentationNode(element: .text("That"))
                ]))
            XCTAssertEqual(discussion[3], DocumentationNode(element: .paragraph, children: [
                DocumentationNode(element: .text("Part 2"))
                ]))
            XCTAssertEqual(discussion[4], DocumentationNode(element: .other("MyLabel"), children: [
                DocumentationNode(element: .text("AF"))
                ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Function><Name>advancedBy(_:)</Name><USR>s:FPs16ForwardIndexType10advancedByFwx8Distancex</USR><Declaration>@warn_unused_result\nfunc advancedBy(n: Self.Distance)</Declaration><Abstract><Para>Return the result of advancing self by n positions.</Para></Abstract><ResultDiscussion><Para>Results are valid</Para></ResultDiscussion></Function>"
            guard let result = try parseSwiftDocAsXML(source),
                let declaration = result.declaration,
                let abstract = result.abstract,
                let resultDiscussion = result.resultDiscussion else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.discussion)
            XCTAssertNil(result.parameters)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .text("@warn_unused_result\nfunc advancedBy(n: Self.Distance)")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("Return the result of advancing self by n positions.")) ]))
            XCTAssertEqual(resultDiscussion.count, 1)
            XCTAssertEqual(resultDiscussion[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("Results are valid"))
                ]))
        } catch {
            XCTFail()
        }

        do {
            let source = "<Class><Name>ClosedInterval</Name><USR>s:Vs14ClosedInterval</USR><Declaration>struct ClosedInterval</Declaration><Abstract><Para>A closed IntervalType.</Para></Abstract><Parameters><Parameter><Name>Bound</Name><Direction isExplicit=\"0\">in</Direction><Discussion><Para>The type of the endpoints.</Para></Discussion></Parameter><Parameter><Name>Test</Name><Discussion><Para>Part 1</Para></Discussion><Discussion><Para>Fin.</Para></Discussion></Parameter></Parameters></Class>"
            guard let result = try parseSwiftDocAsXML(source),
                let declaration = result.declaration,
                let abstract = result.abstract,
                let parameters = result.parameters else {
                    XCTFail()
                    return
            }
            XCTAssertNil(result.discussion)
            XCTAssertNil(result.resultDiscussion)
            XCTAssertEqual(declaration.count, 1)
            XCTAssertEqual(declaration[0], DocumentationNode(element: .text("struct ClosedInterval")))
            XCTAssertEqual(abstract.count, 1)
            XCTAssertEqual(abstract[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("A closed IntervalType.")) ]))
            XCTAssertEqual(parameters.count, 2)
            XCTAssertEqual(parameters[0].name, "Bound")
            do {
                guard let discussion = parameters[0].discussion else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(discussion.count, 1)
                XCTAssertEqual(discussion[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("The type of the endpoints."))
                    ]))
            }
            XCTAssertEqual(parameters[1].name, "Test")
            do {
                guard let discussion = parameters[1].discussion else {
                    XCTFail()
                    return
                }
                XCTAssertEqual(discussion.count, 2)
                XCTAssertEqual(discussion[0], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("Part 1"))
                    ]))
                XCTAssertEqual(discussion[1], DocumentationNode(element: .paragraph, children: [ DocumentationNode(element: .text("Fin."))
                    ]))
            }
        } catch {
            XCTFail()
        }
    }

    func testHTMLOutput() {
        XCTAssertEqual(printSwiftDocToHTML([ DocumentationNode(element: .text("test")) ]), "test")
        XCTAssertEqual(printSwiftDocToHTML([ DocumentationNode(element: .text("test < 2")) ]), "test &lt; 2")
        XCTAssertEqual(printSwiftDocToHTML([
            DocumentationNode(element: .paragraph, children: [
                DocumentationNode(element: .text("a ")),
                DocumentationNode(element: .text("bc")),
                DocumentationNode(element: .strong, children: [
                    DocumentationNode(element: .text(" >ef"))
                ])
            ]),
            DocumentationNode(element: .paragraph, children: [
                DocumentationNode(element: .text("This is")),
                DocumentationNode(element: .codeVoice, children: [
                    DocumentationNode(element: .text("func main()"))
                ])
            ]),
            DocumentationNode(element: .paragraph, children: [
                DocumentationNode(element: .text("Get swift at ")),
                DocumentationNode(element: .link(href: "http://swift.org"), children: [
                    DocumentationNode(element: .text("the website"))
                ])
            ])
        ]), "<p>a bc<strong> &gt;ef</strong></p><p>This is<code>func main()</code></p><p>Get swift at <a href=\"http://swift.org\">the website</a></p>")
        XCTAssertEqual(printSwiftDocToHTML([
            DocumentationNode(element: .codeBlock(language: "swift"), children: [
                DocumentationNode(element: .numberedCodeLine, children: [
                    DocumentationNode(element: .text("let a = 22"))
                ]),
                DocumentationNode(element: .numberedCodeLine, children: [
                    DocumentationNode(element: .text("let b = a"))
                ])
            ])
        ]), "<pre>let a = 22\nlet b = a\n</pre>")
    }
}
