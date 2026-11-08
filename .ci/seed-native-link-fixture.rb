# Run with bin/rails runner against a disposable local Lobsters checkout.
abort "This fixture is only for local development" unless Rails.env.development?

user = User.find_by!(username: "test")
user.update!(about: "Claw native profile destination.")
tag = Tag.find_by!(tag: "test")
base = ENV.fetch("LOBSTERS_BASE_URL")
uri = URI.parse(base)
abort "Expected a loopback HTTP URL" unless uri.scheme == "http" && ["localhost", "127.0.0.1"].include?(uri.host)
base = base.delete_suffix("/") + "/"

def link_story(id, title, user, tag, **attributes)
  story = Story.find_or_initialize_by(short_id: id)
  url = attributes.delete(:url)
  # Lobsters rejects loopback story URLs. Save a valid text story first, then
  # assign the local-only navigation target without fetching an external page.
  attributes[:description] ||= "Local native link regression fixture."
  story[:url] = ""
  story.assign_attributes(user: user, title: title, tags: [tag], **attributes)
  story.save!
  story.update_columns(short_id: id, url: url || "")
end

link_story("lnktgt", "Claw native link target", user, tag,
  description: "[Open profile](/~test)")
link_story("lnksrc", "Claw native link source", user, tag,
  url: "#{base}s/lnktgt",
  description: "[Open story](/s/lnktgt)\n\n[Open profile](/~test)\n\n[Legacy profile](/u/test)")
link_story("lnkusr", "Claw profile link source", user, tag,
  url: "#{base}~test")
link_story("lnkctx", "Claw comment link menu fixture", user, tag,
  description: "Local comment menu regression fixture.")
story = Story.find_by!(short_id: "lnkctx")
comment = Comment.find_or_initialize_by(short_id: "lnkcom")
comment.assign_attributes(story: story, user: user,
  comment: "Claw link menu comment.\n\n[Open profile](/~test)")
comment.save!
comment.update_columns(short_id: "lnkcom")
reply = Comment.find_or_initialize_by(short_id: "lnkrpl")
reply.assign_attributes(story: story, user: user, parent_comment: comment,
  comment: "Claw link menu reply.")
reply.save!
reply.update_columns(short_id: "lnkrpl")
