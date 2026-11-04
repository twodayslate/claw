# claw
A [Lobsters](https://lobste.rs) Reader

Read trending tech, science, programming, and startup news from Lobsters (lobste.rs) with the only Lobsters Reader written in SwiftUI. Lobsters is a computing-focused community centered around link aggregation and discussion.


## Development

### Local Development

#### Docker

Lobsters has docker instructions: https://github.com/lobsters/lobsters/blob/master/docs/setup_with_docker.md

Follow the instructions there and then just run `make docker-serve`

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

### Parser resilience coverage

Story feeds return readable rows plus a skipped-row count. Claw keeps a visible
warning until a complete refresh succeeds. Unknown nonempty feeds and login or
error pages fail explicitly; they are not reported as empty feeds. Missing
metadata is omitted or displayed as unknown. If a comment tree cannot be read
reliably, the story remains readable and its comments show a retry message.

The suite retains historical HTML in `clawTests/Fixtures` and applies layout,
missing-field, malformed-row, and comment-tree mutations. Fetcher tests cover
partial pagination, failed refreshes, warning retention, and recovery. The local
compatibility test also checks exact seeded story content and comment parents
against current upstream HTML; it does not depend on JSON endpoints.

After the normal Docker setup, seed the parser fixture in your disposable
Lobsters checkout (using that checkout's unique Compose project name):

```sh
docker compose run --rm -T app bin/rails runner - < /path/to/claw/.ci/seed-parser-fixture.rb
```

Run the `claw` scheme in Debug with `CLAW_UI_TEST_BASE_URL` set to that instance's
loopback URL. The existing UI tests also need the vote/profile fixtures created
by the integration workflow.

Scheduled and manual workflow runs test both development and the recent release
baseline pinned in `.github/released-claw-ref`. The initial baseline is PR #68,
version 27.1.0 build 37. Update that full commit SHA when shipping a release;
GitHub's old release tags do not track current App Store builds. Each matrix leg
uses its own disposable server and retains separate failure diagnostics. Both
legs must pass before a scheduled revision combination is cached as successful.
Push/PR checks run development only and cannot satisfy the combined nightly cache.
CI uses one Puma process and request thread because Lobsters development mode
rewrites generated inline templates on disk; concurrent writers can truncate them.
