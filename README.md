# claw
A [Lobsters](https://lobste.rs) Reader

Read trending tech, science, programming, and startup news from Lobsters (lobste.rs) with the only Lobsters Reader written in SwiftUI. Lobsters is a computing-focused community centered around link aggregation and discussion.


## Development

### Local Development

#### Docker

Lobsters has docker instructions: https://github.com/lobsters/lobsters/blob/master/docs/setup_with_docker.md

Follow the instructions there and then just run `make docker-serve`

Before running Claw's integration tests, copy
`.github/lobsters-rate-limit-fixture.rb` into the disposable Lobsters checkout's
`config/initializers/` directory and restart its server. This adds a local-only
test endpoint using Lobsters' own throttle responder; the suite verifies that
HTTP 429 preserves login and pauses subsequent requests. CI installs it automatically.

### Nightly compatibility tests

The Build and Integration Test workflow checks `lobsters/lobsters` nightly at
07:17 UTC (02:17 EST / 03:17 EDT). It runs the full unit, integration, and UI
suite against the resolved upstream commit in an isolated local Docker server.
No test requests go to the production website.

Scheduled runs skip Claw/Lobsters revision pairs that have already passed.
Failures are retried on the following night. A missing or expired success cache
causes a fresh test run. Pushes, pull requests, and manual runs still run the
suite by default; manual runs can enable `only_if_upstream_changed` to use the
nightly skip behavior. Run summaries record the upstream revision, and failed
runs retain test diagnostics as artifacts.

GitHub runs schedules from the default branch and can disable them after 60
days without repository activity. Check the workflow's enabled status if the
repository has been idle; see [GitHub's scheduling documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).
