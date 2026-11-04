# Installed only in the disposable Lobsters checkout used by integration tests.
# Use upstream's responder so changes to its headers are covered by the suite.
class ClawRateLimitFixture
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"] == "/_claw_test/rate_limit"

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
