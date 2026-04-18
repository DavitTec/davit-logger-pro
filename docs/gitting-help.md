# Git Development Cycle Cheat Sheet

This document provides a comprehensive guide to managing Git workflows in VSCode with GitHub integration. It focuses on a stable development cycle using branches, commits, changelogs, tags, merges, and issue resolution. The guide assumes a branching strategy where:

- `main` is the stable production branch.
- Development branches are named `dev/[main-task]` (e.g., `dev/new-feature` for integration work).
- Feature or bug branches branch off from `dev/[main-task]` or directly from `main`/`develop` if using a full Git Flow, but we'll simplify to feature branches like `feat/[feature-name]` or `bug/[issue-id]`.
- Releases start at `v0.1.0` for early, incomplete packages.
- Conventional commits are used for semantic versioning (SemVer 2.0) to enable automated changelogs via your `clog` alias.
- All operations are doable in VSCode's built-in Git tools, reducing reliance on GitHub's web interface.

This workflow supports parallel development on multiple feature/bug branches without repo deletion risks. Always pull/rebase to keep branches in sync.

## Prerequisites

- Git installed and configured (e.g., `git config --global user.name "Your Name"` and `git config --global user.email "your@email.com"`).
- VSCode with Git extension enabled (built-in; no install needed).
- GitHub repo created (private or public).
- Your `clog` alias set up for generating `CHANGELOG.md` based on SemVer (e.g., via conventional commits like `feat:add new thing`).
- Use British English for commit messages and docs.

## 1. Setting Up a New Repository

1. Create a repo on GitHub (empty, no README yet).
2. In VSCode, open a folder for your project.
3. Initialise Git: Open Terminal in VSCode (Ctrl+ `or Cmd+` on Mac) and run:

    ```bash
    git init
    git remote add origin https://github.com/yourusername/yourrepo.git
    ```

4. Create initial files (e.g., `README.md`, `.gitignore`).

5. Commit and push initial setup:

    ```bash
    git add .
    git commit -m "chore: initial project setup"
    git branch -M main  # Rename default branch to 'main' if needed
    git push -u origin main
    ```

6. Tag the first version:

    ```bash
    git tag v0.1.0
    git push origin v0.1.0
    ```

7. In VSCode: Use the Source Control view (Git icon on sidebar) to stage, commit, and push/pull.

## 2. Branching Strategy

- **main**: Stable releases only. Never commit directly here.
- **develop**: Optional integration branch (e.g., `develop`) for merging features before `main`. If not using, merge features directly to `main` after testing.
- **dev/[main-task]**: For major development phases (e.g., `dev/ui-overhaul`).
- **feat/[feature-name]**: For new features (branch from `develop` or `main`).
- **bug/[issue-id]**: For fixes (branch from `develop` or `main`).
- **hotfix/[issue-id]**: Quick fixes branched from `main`.

To create a branch in VSCode:

- Click the branch name in the status bar (bottom-left).
- Select "Create Branch..." and name it (e.g., `feat/login-system`).
- Or via Terminal: `git checkout -b feat/login-system`.

Always branch from the latest upstream:

  ```bash
    git checkout main
    git pull origin main
    git checkout -b feat/new-feature
  ```

## 3. Development Cycle

Follow this sequence for each feature or bug:

### Step 1: Create or Link to an Issue

- On GitHub: Create an issue (e.g., "Add user authentication #5").
- Reference in branch name (e.g., `feat/issue-5-auth`).
- In commits, reference issues: `git commit -m "feat: implement auth closes #5"`.

### Step 2: Work on Your Branch

- Checkout the branch: In VSCode status bar or `git checkout feat/issue-5-auth`.
- Make changes, test in VSCode (use integrated terminal/debugger).
- Commit frequently with conventional messages:
  - `feat: new feature`
  - `fix: bug fix`
  - `docs: documentation`
  - `chore: misc`
  - `refactor: code cleanup`
  - Example: `git add .` then `git commit -m "feat: add login endpoint closes #5"`.
- In VSCode: Use Source Control view to stage files (click +), write message, commit (tick icon).

### Step 3: Keep Branch in Sync (Avoid Out-of-Sync Issues)

- Regularly pull from upstream to prevent conflicts:

  ```bash
  git checkout feat/issue-5-auth
  git pull origin main --rebase  # Or from develop if using
  ```

- If conflicts: VSCode will highlight; resolve in editor, then `git add .` and `git rebase --continue`.
- For parallel branches: Rebase each onto the latest `main`/`develop` before merging.
- Push your branch: `git push origin feat/issue-5-auth` or via VSCode (cloud icon in Source Control).

### Step 4: Update Changelog

- Before merging, run your `clog` alias to generate/update `CHANGELOG.md`:

  ```bash
  clog  # Assuming it compiles based on commits since last tag
  git add CHANGELOG.md
  git commit -m "chore: update changelog"
  git push
  ```

### Step 5: Merge Branch

- Ensure branch is up-to-date: `git pull origin main --rebase`.
- In VSCode (preferred over GitHub for local control):
  - Checkout target branch: `git checkout main`.
  - Pull latest: `git pull`.
  - Merge: Click branch in status bar > "Merge Branch..." > select your feature branch.
  - Or Terminal: `git merge feat/issue-5-auth --no-ff` (creates merge commit).
- Resolve conflicts in VSCode editor if any.
- Push merge: `git push origin main`.
- Delete branch: In VSCode, right-click branch in Git view > "Delete Branch..." or `git branch -d feat/issue-5-auth` and `git push origin --delete feat/issue-5-auth`.

Avoid GitHub merges if possible to practice local ops, but if using: Create PR on GitHub, merge, delete branch.

### Step 6: Tag Release

- After merge to `main`, tag if ready for release:

  ```bash
  git checkout main
  git pull
  git tag v0.2.0  # Bump based on SemVer (major.minor.patch)
  git push origin v0.2.0
  ```

- Use SemVer rules: Patch for fixes (0.1.1), minor for features (0.2.0), major for breaking (1.0.0).
- Run `clog` before tagging to include in release notes.

### Step 7: Resolve Issues

- Commits with "closes #issue-id" auto-close issues on push to `main`.
- Manually close on GitHub if needed.

## 4. Working with Multiple Branches in Parallel

- Create multiple: e.g., `feat/issue-3-ui`, `bug/issue-4-bugfix`.
- Switch between: VSCode status bar or `git checkout branch-name`.
- Sync each: Regularly rebase onto `main`/`develop`.
- Merge one by one: Test integration in a `develop` branch first if complex.
- If out-of-sync: Don't delete repo! Instead:

  ```bash
  git fetch origin
  git checkout problematic-branch
  git rebase origin/main  # Or merge if preferred
  git push --force-with-lease  # Safe force-push if no collaborators
  ```

- Stash changes if switching branches mid-work: `git stash` then `git stash pop`.

## 5. Common Git Commands Cheat Sheet

| Action               | Command                                        | VSCode Equivalent                               |
| -------------------- | ---------------------------------------------- | ----------------------------------------------- |
| Clone repo           | `git clone https://github.com/user/repo.git`   | File > Open Folder (after cloning via terminal) |
| Create branch        | `git checkout -b new-branch`                   | Status bar > Create Branch...                   |
| Switch branch        | `git checkout branch-name`                     | Status bar > Select branch                      |
| Stage changes        | `git add file` or `git add .`                  | Source Control > + on files                     |
| Commit               | `git commit -m "message"`                      | Source Control > Enter message > Tick           |
| Push                 | `git push origin branch`                       | Source Control > ... > Push                     |
| Pull                 | `git pull origin branch`                       | Source Control > ... > Pull                     |
| Rebase               | `git rebase origin/main`                       | Terminal only (or extensions)                   |
| Merge                | `git merge source-branch`                      | Status bar > Merge Branch...                    |
| Delete local branch  | `git branch -d branch`                         | Git view > Right-click > Delete                 |
| Delete remote branch | `git push origin --delete branch`              | After local delete, push                        |
| View status          | `git status`                                   | Source Control view                             |
| View log             | `git log --oneline --graph`                    | Git view > Show Git Output                      |
| Tag                  | `git tag v1.0.0` & `git push origin v1.0.0`    | Terminal only                                   |
| Stash                | `git stash` & `git stash pop`                  | Source Control > ... > Stash Changes            |
| Resolve conflicts    | Edit files, `git add .`, continue merge/rebase | VSCode highlights conflicts; resolve in editor  |
| Update changelog     | `clog` then commit                             | Terminal                                        |

## 6. Troubleshooting

- **Branch out-of-sync**: Fetch/pull/rebase as above. Avoid force-pushes if collaborating.
- **Merge conflicts**: Always resolve locally in VSCode for practice.
- **Forgotten commands**: Refer to this doc or `git --help`.
- **VSCode tips**: Enable settings like "Git: Autofetch" for auto-pulls. Install "GitLens" extension for advanced visuals (optional).
- **Parallel dev issues**: Use `develop` as integration branch to merge features there first, then to `main`.

Save this as `./docs/gitting-help.md` in your projects. Update as needed!
