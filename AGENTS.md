### A note from Xenrya

I like ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive. Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Try to honor the dev's intent in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## Project glossary

Use this language in code, documentation, and conversation:

- **you** means the agent reading this file and changing caelestia-shell-xenrya.
- **I** means Xenrya or another caelestia-shell-xenrya developer speaking to you.
- **user** means a person using caelestia-shell-xenrya.
- **agent** means a coding agent run through Codex, OpenCode, or Claude Code.
  Depending on context, this can include you.
- **client** means the caelestia-shell-xenrya.
- **environment** means the runtime hosting caelestia-shell-xenrya and the machine,
  filesystem, provider credentials, and state it owns.
- **project** means an environment-local workspace record rooted at a
  directory.

## Project sources

Use the smallest source that answers the question:

- Start runtime investigations at `shell.qml`, then follow the relevant loader
  into `modules/`, shared state in `services/`, and reusable UI in
  `components/`. The code on that path is the authority for current behavior.
- Read `plugin/src/Caelestia/Config/` for configuration keys, defaults,
  persistence, and global versus per-monitor scope. Treat the example config
  in `README.md` as a user-facing mirror of this schema.
- Read `README.md` for supported installation, usage, and configuration
  behavior. Keep it synchronized when a change alters that public contract.
- Read `CMakeLists.txt`, `plugin/**/CMakeLists.txt`, `flake.nix`, and `nix/` for
  build, registration, installation, and packaging behavior.
- Read `.github/CONTRIBUTING.md` for contribution expectations and
  `.github/workflows/` for the exact checks a change must pass.

Read only the sources that apply to the task.

## Ways to hurt yourself

- Preserve configuration scope. Screen-bound QML should read the attached
  `Config`, whose screen propagates through the `QQuickItem` tree. Use
  `GlobalConfig` only for options deliberately defined as global. Raw
  `QObject`s do not inherit a screen; pass or select the screen explicitly.
- Change source files, not `build/`, generated QML metadata, or installed
  copies. The root `CMakeLists.txt` deliberately rewrites
  `settings.watchFiles` in its generated `shell.qml`, and the Nix wrapper adds
  paths and environment variables that do not exist in a source checkout.
- Register every new C++ or QML plugin type in the owning `CMakeLists.txt` and
  link its dependencies there. A file present in the tree is not necessarily
  part of a QML module or package.
- Keep QML bindings live. An imperative assignment replaces an existing
  binding; use a `Binding`, state, or an explicit restoration when the value
  must continue tracking its inputs.
- Respect loader lifetime. Hiding an item does not stop its timers,
  connections, shortcuts, or service work. Follow the feature's existing
  `Loader.active` and `shouldBeActive` boundary when work should cease.

## Working defaults

- Validate incrementally. While changing code, run focused tests and
  affected-package checks. For production implementation, run repository-wide
  validation once after the final code change; rerun it only after a relevant
  fix. For documentation-only changes, use focused checks unless the user asks
  for wider validation.
- Use shell commands and repo-native tools by default. Use computer-use or
  browser automation only when the user explicitly asks for it.
- Apply `$unslop-response` to every user-facing response.

## Taste
