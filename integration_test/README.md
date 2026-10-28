# Squadly device integration tests

This Flutter package is a native test host for the app in the repository root.
Keeping `integration_test` here prevents the test-only native plugin from being
added to the production app's generated plugin registrants.

Install the host dependencies and run the device tests from this directory:

```bash
flutter pub get
flutter test integration_test -d <device-id> --dart-define=USE_DEMO_BACKEND=true
```

The test sources live in `integration_test/`. `app_smoke_test.dart` exercises
demo navigation and the CloudBase login entry point without real credentials.
`cloudbase_connectivity_test.dart` is an opt-in network probe; it remains
skipped unless `RUN_CLOUDBASE_NETWORK_PROBE=true` is provided.

Android Health Connect availability checks are opt-in. Use
`VERIFY_HEALTH_CONNECT_UNAVAILABLE=true` on an unsupported device or one without
an available provider; this also exercises the actual native read rejection.
Use `VERIFY_HEALTH_CONNECT=true` only when a provider is available. Neither flag
requests health consent or proves workout data can be read or saved remotely.
See [device commands and recorded coverage](../docs/testing.md#health-connect-兼容路径).

The iOS photo UI smoke test uses the actual native unavailable-camera path on
an iOS **simulator**, then a synthetic image source and fake media transport.
Run it with screenshots using:

```bash
flutter drive -d <ios-simulator-id> \
  --driver=test_driver/photo_ui_driver.dart \
  --target=integration_test/photo_ui_test.dart \
  --dart-define=VERIFY_PHOTO_UI_SIMULATOR=true
```

Screenshots are written to `/tmp/squadly-photo-ui-device/`. This verifies native
Flutter rendering, explicit send confirmation, same-nonce retry and withdrawal
UI. It does not exercise PHPicker interaction, physical camera capture, live
CloudBase media permissions, widgets or push delivery. Do not run this scenario
on a physical camera device: the first action deliberately expects simulator
camera unavailability.

The native photo outbox persistence test has two separate app-process phases.
It uses the real application outbox composition (native SQLite and iOS Keychain),
with synthetic actors, JPEG and media/timeline transport. Application HTTP is
blocked. It does not verify CloudBase user media authorization.

```bash
flutter test integration_test/photo_outbox_cold_start_test.dart \
  -d <ios-device-id> --no-uninstall \
  --dart-define=RUN_PHOTO_OUTBOX_NATIVE=true \
  --dart-define=PHOTO_OUTBOX_PHASE=seed
flutter test integration_test/photo_outbox_cold_start_test.dart \
  -d <ios-device-id> --no-uninstall \
  --dart-define=RUN_PHOTO_OUTBOX_NATIVE=true \
  --dart-define=PHOTO_OUTBOX_PHASE=read
```

Run seed before read. Both commands preserve the standalone host; the default
Flutter test uninstall removes SQLite/preferences and invalidates this test.
The read phase asserts different process IDs, original account/Squad/parent/nonce,
no replay from another account, and no removal of another account's queued photo.
