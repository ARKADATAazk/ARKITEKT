# Git workflow with Claude (ARKITEKT)

Goal: keep `main` clean and human-readable, while letting Claude make lots of small
auto-commits on feature branches / worktrees.

This doc is for both humans and AI assistants working on ARKITEKT.

---

## 1. Branch / worktree model

- Never work directly on `main`.
- For each feature/refactor:

  ```bash
  # Simple branch
  git switch -c feat/<short-name>

  # OR: worktree (recommended)
  git worktree add ../ARKITEKT-Toolkit-<short-name> feat/<short-name>
