# Contributing & Git Workflow

This repository follows a feature-branch workflow with a protected `main`. The
process below is the same one used to build the project, so the commit history
and pull requests demonstrate it in practice.

## Branching

`main` is always deployable and is **protected** — it cannot be pushed to
directly, force-pushed, or deleted. Every change lands through a pull request.

Work happens on short-lived branches named by type:

| Prefix | For |
|---|---|
| `feature/` | new functionality, e.g. `feature/github-actions-pipeline` |
| `fix/` | bug fixes, e.g. `fix/health-check-timeout` |
| `docs/` | documentation only, e.g. `docs/git-workflow` |
| `chore/` | tooling, config, housekeeping |

```bash
git switch main
git pull
git switch -c feature/my-change
# ...work...
git push -u origin feature/my-change
```

## Commits

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<scope>): <summary in the imperative mood>

<body: what changed and, more importantly, why>
```

Types used here: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`.
The summary says what; the body explains the reasoning a reviewer would ask for.

## Pull requests

1. Push your branch and open a PR against `main`.
2. The CI workflow validates the change (HTML lint, `terraform fmt`, `validate`,
   `terraform plan`) and posts the plan as a comment.
3. Merge once checks pass. Delete the branch after merging.

Because `main` requires a pull request, even a solo change is merged this way —
which keeps the history reviewable and the branch protection honest.

## Releases

Milestones are tagged with [semantic versioning](https://semver.org):

```bash
git tag -a v1.0.0 -m "First complete release"
git push origin v1.0.0
```

`v1.0.0` marks the first fully working deployment — site, infrastructure,
pipeline, load tests and documentation all in place.
