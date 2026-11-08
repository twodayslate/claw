# Testing

- Always test against the local Lobsters test server, never the real `lobste.rs` website.
- Start the local server using the repository's documented Docker setup and `make docker-serve`, then configure Debug builds to use its local URL (for example, `http://localhost:3000`).
- The local Lobsters instance is a disposable test environment. Agents are explicitly allowed to update its local code, configuration, and data as needed for testing.
- Agents may create and modify local test users, stories, comments, votes, and other test records through the local UI, local APIs, test helpers, or the local database. In particular, creating a story to verify story-list and story-detail behavior is allowed.
- If the existing local instance is unavailable, already in use, has unsuitable state, or needs to remain untouched, create an additional disposable Lobsters instance instead of treating that as a blocker. Agents are explicitly allowed to build additional local images and create additional containers, networks, and volumes for this purpose.
- Isolate each additional instance with a separate Lobsters checkout, a unique Compose project name, and an unused loopback port. For example, change that checkout's `docker-compose.yaml` app mapping from `3000:3000` to `127.0.0.1:3001:3000`, then run its documented setup and start commands with `COMPOSE_PROJECT_NAME=claw-lobsters-<unique-id>` (for example, `COMPOSE_PROJECT_NAME=claw-lobsters-story-view make docker-serve`). Use the same project-name prefix for `docker compose run` setup or fake-data commands, and configure the claw Debug build to use that instance's URL (for example, `http://localhost:3001`).
- Keep disposable instances isolated from any existing local Lobsters checkout and from one another; do not reuse host ports, Compose project names, or persistent data stores. Agents may stop and remove only the disposable containers, networks, images, and volumes they created when cleanup is useful.
- Do not send automated, manual, UI, integration, or exploratory test traffic to the production website.

# UI/UX pull requests

- Every PR that changes UI or UX must include screenshots and/or videos showing the change. Include labeled before/after evidence for every affected screen, covering relevant appearances and states (for example, light and dark mode). Use videos for interactions that still screenshots cannot adequately demonstrate.
- Capture evidence against the local Lobsters test server. Inspect the captures before uploading to ensure they show the intended state and that animations have settled.
- Keep PR evidence outside the repository (for example, in a task-specific directory under `/tmp`). Do not commit screenshots or videos captured for PR review.
- Upload evidence directly to the PR with GitHub CLI's `--attach` flag. Repeat the flag for multiple files. To append labeled screenshots to an existing PR description:

  ```sh
  gh pr edit <PR_NUMBER> --repo twodayslate/claw \
    --attach '/tmp/claw-ui-review/before.png#Before: Settings in dark mode' \
    --attach '/tmp/claw-ui-review/after.png#After: Settings in dark mode'
  ```

- For a before/after table or other custom layout, prepare the complete PR description in a Markdown file with local image references such as `![Before](./before.png)` and `![After](./after.png)`. Run from the directory containing those files:

  ```sh
  gh pr edit <PR_NUMBER> --repo twodayslate/claw \
    --body-file pr-body.md --attach ./before.png --attach ./after.png
  ```

  `gh` replaces the local references with uploaded attachment URLs. Preserve the existing PR description when using `--body-file`, since it replaces the body. Unreferenced attachments are appended. Videos can be attached with `--attach ./demo.mp4`; do not add an alt-text suffix to a video.
- Evidence may also be added to a PR review conversation with `gh pr comment <PR_NUMBER> --repo twodayslate/claw --body-file review.md --attach ./before.png --attach ./after.png`.
- Verify the resulting PR body or comment contains working uploaded attachments and retains all intended before/after pairs. Uploads can partially succeed even when `gh` exits nonzero; inspect the PR before retrying to avoid duplicates.
