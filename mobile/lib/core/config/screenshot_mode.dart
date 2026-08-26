/// Compile-time store-prep screenshot mode (`--dart-define=SCREENSHOT_*`).
bool get isScreenshotMode {
  const scene = String.fromEnvironment('SCREENSHOT_SCENE');
  const email = String.fromEnvironment('SCREENSHOT_EMAIL');
  return scene.isNotEmpty || email.isNotEmpty;
}
