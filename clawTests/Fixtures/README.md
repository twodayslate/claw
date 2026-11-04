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
