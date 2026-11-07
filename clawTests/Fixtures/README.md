# Historical parser fixtures

`story-before-heading.html` preserves the synthetic story-detail fixture used
before PR #68 changed title containers from `span.link` to `h2.link`. It includes
nested replies, an independent deleted root, authenticated controls, scores,
timestamps, and a story body. It contains no captured user data and is never
fetched from the production site.

Keep this input unchanged when upstream HTML changes. Add historical examples
or deliberate mutations instead. Assertions should verify titles, IDs, body
content, authors, and comment relationships, including explicit degraded states.
The live compatibility test renders separate seeded records on local Lobsters.

`story-lobsters-2026-11-06.html` captures the locally seeded parser story from
Lobsters commit `09c7a915b00f432aa240c097e26268846a193966` for issue #73.
It contains the rendered story list, story body, and comment tree, extracted and
serialized with SwiftSoup; navigation, forms, scripts, and unrelated page chrome
were omitted. All users and records are disposable test data. This revision
removed legacy comment `a[name]` anchors, so assertions cover comment bodies,
authors, timestamps, permalinks, and reply relationships without those anchors.
