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

#### Comment depth and link regression tests

Comment indentation adapts to the available pane width and Dynamic Type size.
When further indentation would leave too little reading space, **Continue thread**
opens the next part of the discussion. Thread colors retain the original discussion
depth when opening a continuation or a linked comment. Native comment links (`/c/<id>` and story
URLs with `#c_<id>`) open the target comment and its replies at the top, with
**View all comments** to return to the full discussion. This also works through
the **Open in claw** share extension.

Use a disposable local Lobsters instance and set `TEST_RUNNER_CLAW_UI_TEST_BASE_URL`
to its loopback URL when running these tests. Set the same port in
Lobsters' `config/environments/development.rb` so generated URLs stay local to
that instance. After running the
Lobsters Docker setup (which creates the `test` user and tag), copy
`scripts/seed_comment_depth.rb` into that checkout and run:

```sh
docker compose run --rm app bin/rails runner seed_comment_depth.rb
```

Use the instance's `COMPOSE_PROJECT_NAME` for this command if it is isolated.
The fixture creates a ten-level thread, a sibling reply, an independent root,
an internal comment link, and a four-level branch ending at the portrait phone
depth limit. To run its UI tests on an iPhone 16e simulator:

```sh
TEST_RUNNER_CLAW_UI_TEST_BASE_URL=http://localhost:3006 \
TEST_RUNNER_RUN_COMMENT_DEPTH_UI_TEST=1 xcodebuild test \
  -project claw.xcodeproj -scheme claw -configuration Debug \
  -destination 'platform=iOS Simulator,name=<your simulator>' \
  -only-testing:clawUITests/clawUITests/testCommentDepthContinuation \
  -only-testing:clawUITests/clawUITests/testCommentDepthAdaptsToWidth \
  -only-testing:clawUITests/clawUITests/testCommentContinuationSurvivesWidthChange \
  -only-testing:clawUITests/clawUITests/testCommentLinksOpenHiddenReplies \
  -only-testing:clawUITests/clawUITests/testCommentLinkRefocusesAfterViewAll
```

These tests are skipped unless explicitly enabled and must only use the local server.
The comment tests default to port 3006; set `TEST_RUNNER_CLAW_UI_TEST_BASE_URL`
if using another loopback port. The adaptation and
link tests also run on iPad; the continuation tests assert the narrower phone layout.
The refocus test repeats the linked-comment → full-discussion transition three times
and scrolls the result to catch layout hangs on iPad.

Comments are projected into one lazy list of visible rows. Collapse state is keyed
by comment ID, while local indentation and original discussion depth are separate.
Each row draws its own ancestor guides; it does not contain or measure descendant
views. This keeps subtree changes and width changes out of nested lazy layout.

#### Native story and profile links

Links to stories (`/s/<id>` with or without a title), profiles (`/~<username>`
or `/u/<username>`), and comments open inside Claw. This includes story title,
domain, and chevron taps when the submitted URL points to a supported Lobsters
page. Long-press a link block and choose **Open in Browser** to use the selected
browser for that link instead.

The integration workflow seeds and tests native story/profile navigation and
the browser override. To run these checks locally, seed a disposable server
with its actual loopback URL and Compose project name:

```sh
LOBSTERS_BASE_URL=http://localhost:3007 COMPOSE_PROJECT_NAME=claw-lobsters-<unique-id> \
  docker compose run --rm -T -e LOBSTERS_BASE_URL app bin/rails runner - \
  < /path/to/claw/.ci/seed-native-link-fixture.rb
```

Run `testStoryAndUserLinksOpenNatively` and `testNativeLinkCanOpenInBrowser` in
`clawUITests` with `CLAW_UI_TEST_BASE_URL` set to the same URL in `xcodebuild`.
