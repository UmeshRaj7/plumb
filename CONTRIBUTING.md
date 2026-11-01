# Contributing to plumb

Thanks for helping! plumb is small on purpose. Please read
[doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) before changing code.

## Ground rules

- **v0.0.1 is read-only.** plumb must never write to the project it inspects.
- **Precision over recall.** If a check can't be sure, it reports ℹ, not ✗.
- **No new dependencies** without an issue/discussion first.
- **Docs move with code.** A change to behaviour updates ARCHITECTURE.md (and CLAUDE.md
  if it changes a decision) in the same commit.

## Before every commit

```sh
dart format .
dart analyze          # must report zero issues
dart test
```

If you changed anything in `recipes/`, regenerate the embedded copy first:

```sh
dart run tool/generate_bundled_recipes.dart
```

If an output change is intended, refresh goldens and review the diff:

```sh
UPDATE_GOLDENS=1 dart test test/doctor_golden_test.dart
```

Test fixtures (`test/fixtures/`) are tiny fake Flutter projects with handwritten
`pubspec.lock` files. Never run `pub get` inside them; the repo's `.vscode/settings.json`
stops the Dart extension from doing so, and `test/fixtures_integrity_test.dart` fails if it happens.

Commits follow [Conventional Commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `test:`, `docs:`, `chore:`, `refactor:`. One logical change per commit.

## Code style

- Readable over clever. Plain classes and top-level functions; `switch` on enums.
  No inheritance hierarchies or patterns unless they remove real duplication.
- One concept per file, files under ~300 lines, short functions named for intent.
- Immutable models: `final` fields, `const` constructors where possible, no `late`.
- Parsers and checks are pure (strings/models in, models out). File I/O only in
  `lib/src/project/snapshot_loader.dart`, `lib/src/project/flutter_project.dart` and `lib/src/cli/`.
- `///` doc comments on every public symbol. Inline comments explain *why*.
- User-facing errors: throw `PlumbException` with a message that tells the user what to do.
- Tests: one behaviour per test, named as a sentence (`'reports missing when key is absent'`).

## Writing a recipe

1. Read the plugin's **own** docs (pub.dev README, the README of its endorsed platform
   packages, or the official docs site it links to). Nothing else counts as a source.
2. Create `recipes/<package>.yaml` (format: ARCHITECTURE.md §7). Put the docs URL in
   `source:`; use a per-item `source:` when a fact is on a different page.
3. `required: true` only when the docs say the app must add it for the plugin to work
   (or for App Store/Play acceptance). Otherwise `required: when_used` with a hint that
   says *when*.
4. If the plugin's own AndroidManifest already declares a permission, the app doesn't
   need to — don't mark it `required: true` even if the README says to add it.
5. Things plumb can't check (Gradle, Podfile, AppDelegate) go under `manual:`.
6. `versions:` covers only versions whose docs you actually compared.
7. Regenerate bundled recipes, run tests, and say in the PR which docs and versions you read.
