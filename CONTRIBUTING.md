# Contributing to Grove

Thanks for your interest in contributing! Grove is free, open-source software built for everybody & any help is welcome, whether that's code, bug reports, or ideas.

---

## Reporting Bugs & Requesting Features

Found something broken? Have an idea? You can reach out however works best for you:

- **GitHub Issues** — preferred for bugs and feature requests so they're tracked
- **GitHub Discussions** — great for open-ended ideas or questions
- **Wherever** — if you find another way to reach me, that's fine too

When reporting a bug, try to include:
- Your Android version and device
- Steps to reproduce the issue
- What you expected vs. what actually happened
- Logs or screenshots if you have them

---

## Contributing Code

1. **Open an issue first** for anything significant, it avoids duplicate work and lets us align before you invest time writing code
2. Fork the repo and create a branch from `main`
3. Make your changes, keep commits focused and readable
4. Test on a real device if possible, not just an emulator
5. Open a pull request with a clear description of what you changed and why

### Guidelines

- Follow the existing code style — when in doubt, match what's already there
- Keep pull requests scoped to one thing; big mixed PRs are hard to review
- Update the `CHANGELOG.md` under `[Unreleased]` with any user-facing changes
- Bump `pubspec.yaml` only if we've agreed on a version bump

### What's welcome

- Bug fixes
- Performance improvements
- Accessibility improvements
- New features that fit Grove's theme (habit/sobriety tracking, the fractal tree system, etc)
- New language translations
- Improvements to existing translations

### What to check first

- There's no open issue or PR already covering your change
- The change aligns with Grove's philosophy: offline-first, no tracking, no ads

---

## Project Philosophy

Grove is FOSS software built for people, not profit. Contributions should respect that:

- No telemetry, analytics, or data collection of any kind
- No external dependencies that phone home
- Privacy is non-negotiable

---

## Adding or Updating Translations

Grove welcomes translation contributions. If you'd like to add support for a new language or improve an existing translation, follow these steps:

### Adding a New Language

1. Locate the localization files in `lib/l10n/`

2. Copy `app_en.arb` and rename it using the appropriate language code, for example:

   * `app_es.arb` for Spanish
   * `app_fr.arb` for French
   * `app_de.arb` for German

3. Translate all string values while keeping:

   * Placeholder names unchanged (`{count}`, `{name}`, etc.)
   * Metadata entries (`@key`) intact
   * Formatting and punctuation consistent where appropriate

4. Add the locale to the supported locales list if required by the current implementation.

5. Generate localization files:

```bash
flutter gen-l10n
```

6. Run the app and verify:

   * The language appears correctly when selected
   * Text fits within the UI
   * No untranslated strings remain

### Updating Existing Translations

* Keep translations natural and contextually accurate rather than translating word-for-word.
* Maintain consistency with existing terminology throughout the app.
* Test any modified translations before submitting a pull request.

### Translation Guidelines

* Use clear, natural language.
* Avoid machine-generated translations without review.
* Preserve placeholders and variables exactly as written.
* Keep accessibility and readability in mind.

If you're unsure about a translation, feel free to open a discussion before submitting a pull request.

## Development Setup

1. Make sure you have [Flutter](https://flutter.dev/docs/get-started/install) installed
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/Grove.git`
3. Install dependencies: `flutter pub get`
4. Run on a connected device or emulator: `flutter run`

---

## License

By contributing, you agree that your contributions will be licensed under the same [GPL-3.0 License](LICENSE) that covers this project.
