# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**小分队 (Squadly)** — A cross-platform mobile app for 2–9 person intimate group collaboration. Built with **Flutter** (single codebase for iOS and Android).

Core modules: Squad Fitness (健身), Finance & Light Investment (理财&轻投资), Squad Travel (旅行), Squad Food (美食). All modules share data and interlink (e.g., fitness constrains food calories, finance funds travel).

Key constraints: strict 2–9 member cap, invite-only squads, privacy-first (public vs private asset spaces in finance), role-based permissions (captain/member).

## Architecture

### Monorepo Structure

```
squadly/
├── lib/                    # Flutter app source
│   ├── app/                # App-level config, routing, DI
│   ├── core/               # Shared utilities, theme, constants, network
│   ├── features/           # Feature modules (fitness, finance, travel, food, squad)
│   │   └── <feature>/
│   │       ├── data/       # Repositories, data sources, DTOs
│   │       ├── domain/     # Entities, use cases, repository interfaces
│   │       └── presentation/ # Screens, widgets, state management
│   └── shared/             # Cross-feature shared widgets and models
├── test/                   # Unit and widget tests (mirrors lib/ structure)
├── integration_test/       # Integration/E2E tests
├── ios/                    # iOS-specific config (Xcode project)
├── android/                # Android-specific config (Gradle)
├── assets/                 # Images, fonts, animations
└── packages/               # Extracted local packages (if needed)
```

### Architecture Pattern: Clean Architecture + Feature-First

Each feature module follows **domain → data → presentation** layering:
- **Domain layer**: Pure Dart entities and use cases. No Flutter imports. Repository interfaces defined here.
- **Data layer**: Repository implementations, remote/local data sources, DTOs with mapping to domain entities.
- **Presentation layer**: Screens, widgets, state management (Riverpod or Bloc — choose one and stay consistent).

Cross-feature data flows (e.g., fitness ↔ food calorie sync, finance → travel budget) go through domain-layer use cases, never direct widget-to-widget coupling.

### Squad Model

The `Squad` entity is central — all features are scoped to a squad context. A user can belong to multiple squads. The squad has:
- Members (2–9, with roles: captain, member)
- Shared data per module (public fitness goals, public fund, shared food list, shared travel wishlist)
- Per-member private data (private assets in finance)

## Build & Run Commands

```bash
# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run in release mode
flutter run --release

# Build iOS
flutter build ios

# Build Android APK / App Bundle
flutter build apk
flutter build appbundle

# Run all tests
flutter test

# Run a single test file
flutter test test/features/fitness/domain/use_cases/create_workout_test.dart

# Run tests with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html  # view HTML report

# Code generation (if using freezed/json_serializable)
dart run build_runner build --delete-conflicting-outputs

# Lint
flutter analyze

# Format
dart format lib/ test/
```

## Key Design Decisions

- **Language**: Dart (Flutter). Single codebase serves both iOS and Android.
- **State management**: Pick one of Riverpod or Bloc at project start. Do not mix.
- **Navigation**: Use `go_router` for declarative routing with deep link support.
- **Networking**: `dio` for HTTP, with interceptors for auth tokens and error handling.
- **Local storage**: `drift` (SQLite) for structured data, `shared_preferences` for settings.
- **Immutability**: Use `freezed` for all data classes (domain entities + DTOs). Never mutate state directly.
- **DI**: Use `get_it` + `injectable`, or Riverpod's built-in DI. Stay consistent.

## Module Interaction Rules

- Finance module exposes fund balances via domain use cases → Travel module reads them for budget display.
- Fitness module exposes daily calorie burn → Food module reads it for calorie balance.
- Squad module owns member management, permissions, and squad lifecycle. Other modules depend on it.
- All cross-module communication goes through domain-layer interfaces, never direct imports between feature `presentation/` or `data/` layers.

## Privacy & Permissions

- Finance module has dual-space architecture: `PublicFund` (shared, visible to all members) and `PrivateAsset` (per-user, invisible to others).
- Captain role can: invite/remove members, set squad goals, manage shared funds.
- Member role can: participate in all activities, view shared data, manage own private data.
- Never expose private financial data in shared views or API responses.

## 中文开发说明

产品面向中文用户，UI 文案使用中文。代码（变量名、注释、commit message）使用英文。产品文档和用户可见内容使用中文。
