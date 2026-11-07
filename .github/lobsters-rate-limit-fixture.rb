# Installed only in the disposable Lobsters checkout used by integration tests.
# Use upstream's responder so changes to its headers are covered by the suite.
class ClawRateLimitFixture
  def initialize(app)
    @app = app
  end

  def call(env)
    # Local-only story routes exercise the actual app's error, report, and refresh UI.
    case env["PATH_INFO"]
    when "/_claw_test/story_refresh"
      return [405, {}, []] unless env["REQUEST_METHOD"] == "POST"
      updated = Rack::Request.new(env).params["updated"] == "true"
      Rails.application.executor.wrap do
        story = Story.find_by(short_id: "rfrsh1")
        unless story
          story = Story.create!(
            title: "Initial refresh fixture", description: "A story for testing pull to refresh.",
            user: User.find_by!(username: "System"), tags: [Tag.find_by!(tag: "test")]
          )
          story.update!(short_id: "rfrsh1")
        end
        story.update!(title: updated ? "Updated refresh fixture" : "Initial refresh fixture")
      end
      return [204, {"cache-control" => "no-store"}, []]
    when "/s/errhtm"
      return [200, {"content-type" => "text/html"}, ["<html><body>Unexpected story markup</body></html>"]]
    when "/s/errcmt"
      return [200, {"content-type" => "text/html"}, [<<~HTML]]
        <ol class="stories"><li class="story" data-shortid="errcmt">
          <h2 class="link"><a class="u-url" href="/s/errcmt">Readable error fixture</a></h2>
        </li></ol><ol class="comments"><li>Unexpected comment markup</li></ol>
      HTML
    end
    return @app.call(env) unless ["/_claw_test/rate_limit", "/s/err429"].include?(env["PATH_INFO"])

    env["rack.attack.match_data"] = {
      # Keep at least a minute available for assertions, even near a boundary.
      epoch_time: Time.now.to_i + 60,
      period: 60,
      limit: 4
    }
    Rack::Attack.throttled_responder.call(Rack::Request.new(env))
  end
end

Rails.application.config.middleware.insert_before Rack::Attack, ClawRateLimitFixture
