# Testing

- Always test against the local Lobsters test server, never the real `lobste.rs` website.
- Start the local server using the repository's documented Docker setup and `make docker-serve`, then configure Debug builds to use its local URL (for example, `http://localhost:3000`).
- Do not send automated, manual, UI, integration, or exploratory test traffic to the production website.
