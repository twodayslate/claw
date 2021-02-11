//
//  HTMLView.swift
//  claw
//
//  Created by Zachary Gorak on 9/12/20.
//

import SwiftUI
import SwiftSoup


// inspired by
// * https://github.com/lukasmoellerch/SwiftUIFormattedText
// * https://github.com/Lambdo-Labs/MDText

struct NodesView: View {
    @EnvironmentObject var settings: Settings
    
    var nodes: [Node]
    var bullet = "•"
    
    func combineNodes(_ nodes: [Node]) -> [AnyView] {
        var ans = [AnyView]()
        var combined = Text("")
        var hasAddedText = false
        
        func clearText() {
            if hasAddedText {
                ans.append(AnyView(combined.fixedSize(horizontal: false, vertical: true)))
            }
            combined = Text("")
            hasAddedText = false
        }
        
        func getText(from element: Element) -> Text {
            var text = Text("")
            for child in element.getChildNodes() {
                if let textNode = child as? TextNode {
                    if !textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        text = text + Text(textNode.text())
                    }
                } else if let childElement = child as? Element {
                    if childElement.tagName() == "strong" {
                        text = text + getText(from:childElement).bold()
                    } else if childElement.tagName() == "em" {
                        text = text + getText(from:childElement).italic()
                    } else if childElement.tagName() == "del" {
                        text = text + getText(from:childElement).strikethrough()
                    } else if ["del", "strike"].contains(childElement.tagName()) {
                        text = text + getText(from:childElement).strikethrough()
                    } else if childElement.tagName() == "a" {
                        text = text + getText(from:childElement).foregroundColor(.accentColor).underline()
                    } else if childElement.tagName() == "code" {
                        text = text + getText(from:childElement).font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)-1, design: .monospaced))
                    }
                }
            }
            return text
        }
        
        for n in nodes {
            if let textNode = n as? TextNode {
                if !textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    combined = combined + Text(textNode.text())
                    hasAddedText = true
                }
            } else if let element = n as? Element {
                if element.tagName() == "a" {
                    let link: Text = getText(from:element).foregroundColor(.accentColor).underline()
                    combined = combined + link
                    hasAddedText = true
                } else if element.tagName() == "strong" {
                    combined = combined + getText(from:element).bold()
                    hasAddedText = true
                } else if element.tagName() == "em" {
                    combined = combined + getText(from:element).italic()
                    hasAddedText = true
                } else if ["del", "strike"].contains(element.tagName()) {
                    combined = combined + getText(from:element).strikethrough()
                    hasAddedText = true
                } else if element.tagName() == "code" {
                    combined = combined + getText(from:element)
                        .font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)-1, design: .monospaced))
                    hasAddedText = true
                } else if element.tagName() == "pre" {
                    clearText()
                    let bq = HTMLView(html: try! element.html()).padding().frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading).background(Color.secondary.opacity(0.8)).font(Font(.body, sizeModifier: CGFloat(settings.textSizeModifier)-1, design: .monospaced))
                    ans.append(AnyView(bq))
                }
                else if element.tagName() == "blockquote" {
                    clearText()
                    let bq = HTMLView(html: try! element.html()).padding(EdgeInsets(top: 4.0, leading: 16.0, bottom: 4.0, trailing: 0)).overlay(Rectangle().frame(width: 5.0, height: nil, alignment: .leading).foregroundColor(Color.gray), alignment: .leading)
                    ans.append(AnyView(bq))
                } else if element.tagName() == "ul" {
                    clearText()
                    let stack = VStack(alignment: .leading, spacing: 4.0) {
                        AnyView(NodesView(nodes: element.getChildNodes()))
                    }
                    ans.append(AnyView(stack))
                } else if element.tagName() == "ol" {
                    clearText()
                    var nv = NodesView(nodes: element.getChildNodes())
                    nv.bullet = "#"
                    let stack = VStack(alignment: .leading, spacing: 4.0) {
                        AnyView(nv)
                    }
                    ans.append(AnyView(stack))
                } else if element.tagName() == "li" {
                    let stack = HStack(alignment: .firstTextBaseline) {
                        if bullet == "#" {
                            let index = ((element.parents().first()?.children().firstIndex(of: element)) ?? 0) + 1
                            Text("\(index).")
                        } else {
                            Text(self.bullet)
                        }
                        
                        
                        AnyView(NodesView(nodes: element.getChildNodes()))
                    }.padding(EdgeInsets(top: 0, leading: 8.0, bottom: 0, trailing: 0))
                    ans.append(AnyView(stack))
                }
                else {
                    clearText()
                    ans.append(AnyView(NodesView(nodes: element.getChildNodes())))

                    
                }
            }
        }
        clearText()
        return ans
    }
    
    var combinedNodes: [AnyView] {
        return combineNodes(nodes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8.0){
            ForEach(Array(combinedNodes.enumerated()), id: \.offset) { (ind, view) in
                view
            }
        }
        
    }
}

struct HTMLLink: Codable, Hashable {
    var text: String
    var url: String
}

struct HTMLView: View {
    var html: String
    
    func getLinks(_ from_nodes: [Node]) -> [HTMLLink] {
        var ans = [HTMLLink]()
        for node in from_nodes {
            if let element = node as? Element {
                if element.tagName() == "a" && element.hasAttr("href") {
                    let link = HTMLLink(text: (try? element.text()) ?? "", url: try! element.attr("href"))
                    ans.append(link)
                }
            }
            ans = ans + getLinks(node.getChildNodes())
        }
        return ans
    }
    
    var links: [HTMLLink] {
        return getLinks(nodes)
    }
    
    var views: Elements {
        do {
            let doc = try SwiftSoup.parseBodyFragment(html)
            if let _elements = doc.body()?.children() {
                return _elements
            }
        } catch {
            //
        }
        return Elements()
    }

    var nodes: [Node] {
        do {
            let doc = try SwiftSoup.parseBodyFragment(html)
            if let _nodes = doc.body()?.getChildNodes() {
                return _nodes
            }
        } catch {
            //
        }
        return [Node]()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6.0) {
            NodesView(nodes: nodes)
        }
    }
}

extension StringProtocol {
    func join(_ texts: [Text]) -> Text {
        var ans = Text("")
        for (i, text) in texts.enumerated() {
            if i > 0 {
                ans = ans + Text(self)
            }
            ans = ans + text
        }
        return ans
    }
}

struct HTMLView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            HTMLView(html: "<p>Hello World!</p>")
            ScrollView {
                HTMLView(html: """
<blockquote>\n<p>In general, I’m skeptical of arguments saying that “such and such language community is arrogant, therefore Y”. It’s easy for an essay-writer or internet commenter to remember a small number of particular interactions with a particular group of people who happened to be advocating for the merits of some programming language over another, and incorrectly attribute this to a property of that programming language.</p>\n</blockquote>\n<p>Plus, of course, the trolls: There’s plenty of people on Reddit, for example, who are “advocating for Rust” in a way that makes Rust advocates seem unhinged, which is the point. Maybe some of them hate the language, but most of them are downvote trolls (“Look at me! Downvote me! <a href="#">LOOK!</a> AT! ME!”) riding a fad.</p>\n
""")
            }
            ScrollView {
                HTMLView(html: """
<p>I can sympathise with jgm’s desire for a simpler spec; modern Markdown is “more congealed than designed”, to misquote Douglas Adams. However, I’m pretty sure one of Markdown’s original design goals was to make good-looking, readable plain-text documents, ever-so-slightly constraining existing conventions so that they could make good-looking, readable rich-text documents too.</p>\n<blockquote>\n<p>To dramatically reduce ambiguities, we can remove the doubled character delimiters for strong emphasis. Instead, use a single _ for regular emphasis, and a single * for strong emphasis.</p>\n</blockquote>\n<p>The trouble is that in plain-text documents, people traditionally used <code>*</code> and <code>_</code> for level-one emphasis (read as “bold” and “underlined” respectively), but typographic tradition is that level-one emphasis is italic text. So “single for level-one emphasis, double for level-two emphasis” is the most natural, semantic translation.</p>\n<blockquote>\n<p>Shortcut references like [foo] would have to be disallowed (unless we were willing to force writers to escape all literal bracket characters).</p>\n</blockquote>\n<p>I don’t know how I missed it, but until this year I missed that shortcut references were even possible. I started off with long-form <code>[text](url)</code> references, which looked ugly and broke up the text, and eventually twigged to <code>[text][tag]</code> references which still look weird to people who don’t know Markdown (or people who haven’t seen that syntax before). Just being able to write <code>[text]</code> in running prose marks that text as special without overly distracting the reader, and if the next paragraph (or something at the end of the document) says <code>[text]: http://example.com</code> the association should hopefully be plain.</p>\n<blockquote>\n<p>Since we have fenced code blocks, we don’t need indented code blocks.</p>\n</blockquote>\n<p>Fenced-code blocks are weird and ugly unless you’re already familiar with Markdown, while indenting is a clear visual delimiter.</p>\n<blockquote>\n<p>Instead of passing through raw HTML, we should introduce a special syntax that allows passing through raw content of any format.</p>\n</blockquote>\n<p>I can appreciate this from a technical standpoint (it’s a simple rule that solves a whole class of problems!) but even without raw HTML support, Markdown is pretty heavily tied to the HTML document model. Consider Asciidoc, which is basically Markdown but for the DocBook XML document model instead. There’s definitely similarities to Markdown, but the differences run much, much deeper than just what kind of raw content pass-through is allowed.</p>\n<blockquote>\n<p>We should require a blank line between paragraph text and a list. Always.</p>\n</blockquote>\n<p>This also is an excellent technical opinion, but click through to the OP and look at the examples of the new syntax and tell me whether either of them look pleasing.</p>\n<blockquote>\n<p>Introduce a syntax for an attribute specification.</p>\n</blockquote>\n<p>This definitely makes Markdown more flexible, but doesn’t make it any prettier to read. Also, if anything it ties Markdown even closer to the HTML document model.</p>\n<p>Overall, these changes would move Markdown further from being a plain-text prettifier, and closer towards being a Huffman-optimized encoding of HTML. That’s not a <em>bad</em> thing, and certainly it seems to be what most people who use Markdown actually want, but it’s quite different from Markdown’s original goals.</p>\n<p>When the CommonMark first began (as “Standard Markdown”), they tried to get John Gruber involved, but as I recall he refused to take part and told them not to use the name “Markdown”. I felt he was being a jerk, but having thought about it, I wonder if maybe he felt a bit like <a href=\"http://www.ultratechnology.com/moore4th.htm\" rel=\"nofollow\">Chuck Moore about ANSI Forth</a>, that the real value was the idea of a hastily-written script that took something human-friendly and made it computer-friendly, and making a set-in-stone Standard with Conformance Tests would be the exact opposite of Gruber’s idea of Markdown, no matter how compatible it was to his script. I imagine something like <a href=\"https://en.wikipedia.org/wiki/ABC_notation\" rel=\"nofollow\">ABC notation</a> is much closer, despite being entirely unrelated.</p>\n
""")
            }
            ScrollView {
                HTMLView(html: """
<p>Here’s an edge case that breaks this grammar:</p>\n<pre><code>**Bold and *Italic***\n</code></pre>\n<p>which renders as <strong>Bold and <em>Italic</em></strong> using Lobsters’ Markdown renderer</p>\n
""")
            }
            
            // https://lobste.rs/s/f5dt41/pip_has_dropped_support_for_python_2#c_ke2hvl
            ScrollView {
                HTMLView(html: """
            <p>Python 2 support has been dropped by <del>pip</del> the Python Packaging Authority (PyPA) at the Python Packaging Index (PyPI), which is the default configuration for every distribution of pip I’m aware of. If you have critical dependencies on Python 2 packages and are unwilling to migrate to Python 3, set up your own package index <del>or pull the libraries you depend on directly into the vcs for your legacy project</del> (which is definitely more work than migrating to Python 3, but <em>is</em> a choice you have).</p>\n<p>Another easier alternative would be to pull the libraries you depend on directly into the vcs for your legacy project.</p>\n
""")
            }
            
            ScrollView {
                HTMLView(html: """
<p>I’ve been down a parallel road to this - the Control key has enough of an established usage for me when using the shell (which features in ~80%  of my computer time) that I don’t see why I’d want to overload it as a gui shortcut key when Alt is sitting there largely unused).</p>\n<p>The article doesn’t mention Firefox (possibly because the author doesn’t use it). If it doesn’t use the Gtk settings - I haven’t checked, because I didn’t know about them (thanks!) - you can switch it from  Control to Alt by changing the “ui.key.accelKey” preference to 18.  I do this by dropping a <code>user.js</code> file in my profile directory containing the line</p>\n<pre><code>user_pref(\"ui.key.accelKey\", 18); # use Alt instead of Ctrl\n</code></pre>\n
""")
            }
            ScrollView {
                HTMLView(html: """
<p>I’ve seen a few around, but haven’t found the time to test any of them to see how well they work.</p>\n<ul>\n<li><a href=\"https://github.com/stsquad/emacs_chrome\" rel=\"nofollow\">https://github.com/stsquad/emacs_chrome</a></li>\n<li><a href=\"https://github.com/GhostText/GhostText\" rel=\"nofollow\">https://github.com/GhostText/GhostText</a></li>\n<li><a href=\"https://github.com/asamuzaK/withExEditor\" rel=\"nofollow\">https://github.com/asamuzaK/withExEditor</a></li>\n</ul>\n
""")
            }
            ScrollView {
                HTMLView(html: """
  <p>Here’s a <a href="https://github.com/cli/cli/blob/trunk/docs/gh-vs-hub.md" rel="ugc">comparison</a> of the new GitHub CLI (<code>gh</code>) against the existing unofficial CLI <a href="https://github.com/github/hub" rel="ugc"><code>hub</code></a>.</p>
""")
            }
            ScrollView {
                HTMLView(html: """
    <p>You might have heard of <a href="https://github.com/mawww/kakoune" rel="ugc">kakoune</a> and how it’s a bit like vim, except that verb and object are reversed. One interesting and rarely-mentioned consequence is that you can do manipulation that is very close to what is described in the <a href="http://doc.cat-v.org/bell_labs/structural_regexps/se.pdf" rel="ugc">structural regexp</a> document.</p>
                        <p>Consider this hypothetical structural regex <code>y/".*"/ y/’.*’/ x/[a-zA-Z0-9]+/ g/n/ v/../ c/num/</code> that they describe. Put simply, it is supposed to change each variable named <code>n</code> into <code>num</code> while being careful not to do so in strings (in <code>\n</code> for example).</p>
                        <p>This exact processing can be done interactively in kakoune with the following key sequence: <code>S".*"&lt;ret&gt;S'.*'&lt;ret&gt;s[a-z-A-Z0-9]+&lt;ret&gt;&lt;a-k&gt;n&lt;ret&gt;&lt;a-K&gt;..&lt;ret&gt;cnum&lt;esc&gt;</code></p>
                        <p>It looks cryptic, but it’s a sequence of the following operations:</p>
                        <ol>
                         <li> <code>S".*"&lt;ret&gt;</code> : split the current selection into multiple, such that the patterns <code>".*"</code> are not selected anymore</li>
                         <li> <code>S'.*'&lt;ret&gt;</code> : same, but with <code>'.*'</code> </li>
                         <li> <code>s[a-z-A-Z0-9]+&lt;ret&gt;</code> : select all alphanumeric words from the current selections</li>
                         <li> <code>&lt;a-k&gt;n&lt;ret&gt;</code> : keep only the selections that contain a <code>n</code> </li>
                         <li> <code>&lt;a-K&gt;..&lt;ret&gt;</code> : exclude all selections that contain 2 or more characters</li>
                         <li> <code>cnum&lt;esc&gt;</code> : replace each selection with <code>num</code> </li>
                        </ol>
                        <p>And the nice thing about being interactive is that you don’t have to think up the entire command at once. You can simply do it progressively and see that your selections are narrowing down to exactly what you want to change.</p>
    """)
            }
            " ".join([Text("Hello"), Text("link").foregroundColor(.blue), Text("world!")])
        }.previewLayout(.sizeThatFits).environmentObject(Settings(context: PersistenceController.preview.container.viewContext))
    }
}
