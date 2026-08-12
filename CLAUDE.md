# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`sublime_transfers` — a Flutter application (Dart package name `sublime_transfers`, org `com.example`, display name "Sublime Transfers"). Currently a fresh `flutter create` scaffold: `lib/main.dart` holds the default counter app and `test/widget_test.dart` the accompanying widget test. Targets all six platforms (android, ios, web, macos, linux, windows).

Flutter SDK: 3.41.9 (stable). Dart SDK constraint is in `pubspec.yaml`.

## Commands

- Install/refresh dependencies: `flutter pub get`
- Run the app: `flutter run` (append `-d chrome`, `-d macos`, etc. to pick a device; `flutter devices` lists them)
- Static analysis / lint: `flutter analyze`
- Format: `dart format .`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Run a single test by name: `flutter test --plain-name "<substring of test description>"` (or `-n`)
- Build a release: `flutter build apk` / `flutter build ios` / `flutter build web` (etc.)

## Architecture

The app is a standard Flutter project. Entry point is `lib/main.dart` → `runApp()`. New feature code goes under `lib/`. Lint rules come from `package:flutter_lints` via `analysis_options.yaml`; keep `flutter analyze` clean before considering work done.

As the codebase grows beyond the scaffold, document the state management approach, `lib/` module layout, and any backend/service integration here.
