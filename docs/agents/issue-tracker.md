# Issue tracker: Plane

Issues, specs, and tickets for this repo live in the Plane project
`caelestia-shell-xenrya` (identifier `CAELESTIAS`), in the workspace
`xenrya-personal-projects`. Use Plane's REST API with `curl`.

- Base: `https://api.plane.so/api/v1/workspaces/xenrya-personal-projects/projects/21baaf0c-6837-46c6-8076-c15f16a011d2/`,
  written `$W` below.
- Auth: send `X-API-Key: $PLANE_API_KEY`. The key is exported in `~/.bashrc`
  after its interactive-shell guard, so an agent's shell starts without it.
  Start each command that calls the API with
  `eval "$(grep '^export PLANE_API_KEY=' ~/.bashrc)"`. When `~/.bashrc` has no
  such line, stop and ask.
- Bodies are JSON (`Content-Type: application/json`). Descriptions and
  comments are HTML, sent with no newlines between tags: Plane renders each
  newline between tags as an empty paragraph or list item.
- Labels, states, and users are referenced by UUID. Look them up with
  `GET $W/labels/`, `GET $W/states/`, and `GET /api/v1/users/me/`.
- The limit is 60 requests per minute.

## Operations

- **Read**: `GET /api/v1/workspaces/xenrya-personal-projects/work-items/CAELESTIAS-<n>/`
  for `CAELESTIAS-<n>`, or `GET $W/work-items/<uuid>/`. Read comments with
  `GET $W/work-items/<uuid>/comments/`.
- **List**: `GET $W/work-items/?expand=labels,state,assignees`. It paginates
  with `cursor`, up to 100 per page; filter the results by label.
- **Create**: `POST $W/work-items/` with `name`, `description_html`, and
  optionally `labels`, `state`, `parent`.
- **Sub-issue**: set `parent` to the parent's UUID on create, or PATCH it.
- **Blocked by**: `POST $W/work-items/<uuid>/relations/` with
  `{"relation_type": "blocked_by", "issues": ["<blocker uuid>"]}`. A ticket is
  unblocked when every blocker is in a `completed` or `cancelled` state, or
  has its PR merged into the branch this ticket's PR targets.
- **Claim**: `PATCH $W/work-items/<uuid>/` with `assignees` set to your user
  UUID, keeping any existing assignees. An issue with an assignee is claimed.
- **Comment**: `POST $W/work-items/<uuid>/comments/` with `comment_html`.
- **Label**: `PATCH $W/work-items/<uuid>/` with the full `labels` UUID list,
  using the names in `triage-labels.md`.
- **Close**: `PATCH $W/work-items/<uuid>/` with `state` set to `Done`
  (group `completed`), or `Cancelled` (group `cancelled`) when it will not be
  done. Comment the reason first.
- **Settle**: a decision ticket settles when the user confirms its answers; a
  build ticket settles when its code is merged to `dev`. Then do what its Done
  when asks, comment the outcome (the answers, or the merged PR), and Close it
  as `Done`.

## Skill actions

- **Publish a spec** (`specs`): comment the spec on its source issue.
- **Publish tickets** (`to-tickets`): create one work item per ticket with
  `parent` set to the source issue, then add each Blocked by relation.
- **Claim a ticket** (`swarm-tickets`): assign it, as in Claim.
