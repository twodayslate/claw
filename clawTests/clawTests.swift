//
//  clawTests.swift
//  clawTests
//
//  Created by Zachary Gorak on 9/11/20.
//

import XCTest
@testable import claw

class clawTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let scheme = CommentColorScheme.custom(.blue, .link, .black, .black, .black.withAlphaComponent(0.7), .black, .red)
        let data = try JSONEncoder().encode(scheme)
        let converted = try JSONDecoder().decode(CommentColorScheme.self, from: data)
        XCTAssertEqual(scheme, converted)
    }

    func testStoryHTMLParserParsesNestedComments() throws {
        let html = """
        <html>
          <body>
            <ol class="stories">
              <li id="story_abc123" data-shortid="abc123" class="story">
                <div class="story_liner h-entry">
                  <div class="voters"><a class="upvoter" title="42">42</a></div>
                  <div class="details">
                    <span class="link"><a class="u-url" href="https://example.com/article">An article</a></span>
                    <ul class="tags"><li><a>swift</a></li><li><a>ios</a></li></ul>
                    <div class="byline">
                      <span>authored by</span>
                      <a href="/~alice">alice</a>
                      <time datetime="2026-07-29T12:00:00Z" data-at-unix="1785326400"></time>
                    </div>
                  </div>
                </div>
              </li>
            </ol>
            <div class="story_content"><div class="story_text"><p>Story body</p></div></div>
            <ol class="comments">
              <li class="comments_subtree">
                <div id="c_parent1" data-shortid="parent1" class="comment upvoted">
                  <div class="voters"><a class="upvoter" title="8">8</a></div>
                  <div class="details">
                    <div class="byline">
                      <a aria-hidden="true" href="/~bob"></a><a href="/~bob">bob</a>
                      <a href="/c/parent1"><time data-at-unix="1785326460"></time></a>
                    </div>
                    <div class="comment_text"><p>Parent <strong>comment</strong></p></div>
                  </div>
                </div>
                <ol class="comments">
                  <li class="comments_subtree">
                    <div id="c_child1" data-shortid="child1" class="comment flagged">
                      <div class="voters"><button class="upvoter" title="3">3</button></div>
                      <div class="details">
                        <div class="byline">
                          <a href="/~carol">carol</a>
                          <a href="/c/child1"><time data-at-unix="1785326520"></time></a>
                        </div>
                        <div class="comment_text"><p>Child comment</p></div>
                      </div>
                    </div>
                  </li>
                </ol>
              </li>
              <li class="comments_subtree">
                <div id="c_deleted1" data-shortid="deleted1" class="comment">
                  <div class="details">
                    <div class="byline"><a href="/~dave">dave</a><a href="/c/deleted1"><time data-at-unix="1785326580"></time></a></div>
                    <div class="comment_text"><span class="na">[deleted by moderator]</span></div>
                  </div>
                </div>
              </li>
            </ol>
          </body>
        </html>
        """

        let story = try StoryHTMLParser.parse(
            html,
            pageURL: URL(string: "https://lobste.rs/s/abc123/an_article?source=test#comments")!
        )

        XCTAssertEqual(story.short_id, "abc123")
        XCTAssertEqual(story.title, "An article")
        XCTAssertEqual(story.url, "https://example.com/article")
        XCTAssertEqual(story.score, 42)
        XCTAssertEqual(story.comment_count, 3)
        XCTAssertEqual(story.comments_url, "https://lobste.rs/s/abc123/an_article")
        XCTAssertEqual(story.submitter_user, "alice")
        XCTAssertTrue(story.user_is_author)
        XCTAssertEqual(story.tags, ["swift", "ios"])
        XCTAssertEqual(story.description, "<p>Story body</p>")

        let parent = try XCTUnwrap(story.comments.first { $0.short_id == "parent1" })
        XCTAssertNil(parent.parent_comment)
        XCTAssertEqual(parent.commenting_user, "bob")
        XCTAssertEqual(parent.score, 8)
        XCTAssertTrue(parent.comment.contains("<strong>comment</strong>"))

        let child = try XCTUnwrap(story.comments.first { $0.short_id == "child1" })
        XCTAssertEqual(child.parent_comment, "parent1")
        XCTAssertEqual(child.flags, 1)

        let deleted = try XCTUnwrap(story.comments.first { $0.short_id == "deleted1" })
        XCTAssertTrue(deleted.is_deleted)
        XCTAssertTrue(deleted.is_moderated)
    }

    func testStoryHTMLParserRecognizesSelfPost() throws {
        let html = """
        <ol class="stories">
          <li data-shortid="self01" class="story">
            <div class="voters"><a class="upvoter" title="1">1</a></div>
            <div class="details">
              <span class="link"><a class="u-url" href="/s/self01/a_self_post">A self post</a></span>
              <div class="byline"><span>via</span><a href="/~alice">alice</a><time data-at-unix="1785326400"></time></div>
            </div>
          </li>
        </ol>
        """

        let story = try StoryHTMLParser.parse(
            html,
            pageURL: URL(string: "https://lobste.rs/s/self01/a_self_post")!
        )

        XCTAssertEqual(story.url, "")
        XCTAssertFalse(story.user_is_author)
        XCTAssertEqual(story.comment_count, 0)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
