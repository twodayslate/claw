# Run only in the disposable local Lobsters checkout, after bin/setup.
author = User.find_by!(username: "System")
tag = Tag.find_by!(tag: "test")
story = Story.find_or_initialize_by(title: "Claw Parser Compatibility Fixture")
story.user = author
story.url = ""
story.description = "A **stable story body** for parser compatibility."
story.tags = [tag]
story.save!
parent = Comment.find_or_create_by!(story: story, comment: "Parser parent **body**.") { |c| c.user = author }
Comment.find_or_create_by!(story: story, comment: "Parser child body.") do |c|
  c.user = author
  c.parent_comment = parent
end
# Multiple root comments catch accidental attachment to a sibling thread.
Comment.find_or_create_by!(story: story, comment: "Parser second root body.") { |c| c.user = author }
