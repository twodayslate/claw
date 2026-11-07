# Run with Rails runner inside a disposable local Lobsters checkout.
abort "This fixture is only for local development" unless Rails.env.development?

title = "Claw comment depth regression fixture"
abort "Fixture already exists" if Story.exists?(title: title)

user = User.find_by!(username: "test")
story = Story.create!(user: user, title: title, description: "Local comment navigation test.",
  tags: [Tag.find_by!(tag: "test")])

parent = nil
comments = 10.times.map do |depth|
  parent = Comment.create!(story: story, user: user, parent_comment: parent,
    comment: "Depth #{depth} comment")
  parent.update_columns(short_id: "depth#{depth}")
  parent
end

Comment.create!(story: story, user: user, parent_comment: comments[3],
  comment: "Sibling reply at depth 4")
Comment.create!(story: story, user: user, comment: "Independent root comment")
Comment.create!(story: story, user: user,
  comment: "[Jump to deep reply](/c/depth4)")

# A leaf exactly at the boundary must not offer an empty continuation page.
parent = nil
4.times do |depth|
  parent = Comment.create!(story: story, user: user, parent_comment: parent,
    comment: "Short branch depth #{depth}")
  parent.update_columns(short_id: "leaf#{depth}")
end

puts "Created #{story.short_id}: #{title}"
