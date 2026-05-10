# Dart/Flutter Documentation Standards

## Overview

Dart uses documentation comments starting with `///` (triple slash). Flutter adds widget-specific conventions and emphasizes visual documentation.

## File/Library Documentation

Place at the top of Dart files:

```dart
/// ADHD-optimized productivity timer application.
///
/// Provides visual time awareness through smooth animations and
/// color-coded feedback designed for users with time blindness.
/// Integrates with MQTT-based multi-device ecosystem.
library productivity_timer;
```

## Class Documentation

Include purpose, usage examples, and important notes:

```dart
/// Manages visual timer display with ADHD-optimized feedback.
///
/// Provides smooth color transitions and non-disruptive notifications
/// suitable for professional environments. Implements accessibility
/// features including colorblind mode and reduced motion options.
///
/// Example:
/// ```dart
/// final display = TimerDisplay(
///   duration: Duration(minutes: 25),
///   onComplete: () => showBreakNotification(),
/// );
/// ```
///
/// See also:
/// * [TimerController] for timer state management
/// * [NotificationService] for alert handling
class TimerDisplay extends StatefulWidget {
```

## Method/Function Documentation

Include description, parameters, return values, and examples:

```dart
/// Calculates focus quality score from session metrics.
///
/// Analyzes productivity patterns to determine focus quality on a
/// 0.0 to 1.0 scale, with higher values indicating better focus.
///
/// The [sessionData] must contain 'durationSeconds', 'interruptions',
/// and 'completionRate' keys.
///
/// Returns a [double] between 0.0 and 1.0 representing focus quality.
///
/// Throws [ArgumentError] if [sessionData] is missing required keys.
/// Throws [FormatException] if duration is not numeric.
///
/// Example:
/// ```dart
/// final score = calculateFocusQuality({
///   'durationSeconds': 1500,
///   'interruptions': 2,
///   'completionRate': 0.85,
/// });
/// print('Focus score: $score');  // Focus score: 0.78
/// ```
double calculateFocusQuality(
  Map<String, dynamic> sessionData, {
  double threshold = 0.6,
}) {
```

## Widget Documentation

Document build behavior, parameters, and usage:

```dart
/// Displays circular progress timer with color-coded urgency.
///
/// This widget rebuilds every second to update the remaining time
/// display. Color transitions are smooth to prevent jarring changes
/// that could break hyperfocus.
///
/// The [remainingSeconds] and [totalSeconds] determine the progress
/// indicator fill level and urgency color.
///
/// When [colorblindMode] is true, uses pattern-based indicators
/// instead of color-only feedback.
///
/// {@tool snippet}
/// Example timer display:
///
/// ```dart
/// TimerWidget(
///   remainingSeconds: 900,
///   totalSeconds: 1500,
///   colorblindMode: false,
///   onTap: () => pauseTimer(),
/// )
/// ```
/// {@end-tool}
///
/// See also:
/// * [CircularProgressIndicator] for the underlying progress widget
/// * [AnimatedContainer] for smooth color transitions
class TimerWidget extends StatelessWidget {
  /// Creates a timer widget.
  ///
  /// The [remainingSeconds] and [totalSeconds] must not be null.
  const TimerWidget({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.colorblindMode = false,
    this.onTap,
  });

  /// Time remaining in current timer session.
  final int remainingSeconds;

  /// Total duration of timer session.
  final int totalSeconds;

  /// Enable pattern-based indicators for colorblind users.
  final bool colorblindMode;

  /// Callback invoked when timer is tapped.
  final VoidCallback? onTap;
```

## Enum Documentation

Document purpose and each value:

```dart
/// Visual notification priority levels for ADHD-optimized alerts.
///
/// Each level provides distinct visual characteristics designed to
/// grab attention appropriately without causing unnecessary disruption.
enum NotificationPriority {
  /// Slow ambient color shift, barely noticeable.
  ///
  /// Used for low-priority background information that doesn't
  /// require immediate attention.
  ambient,

  /// Soft pulse at 0.5 Hz, gentle attention grab.
  ///
  /// Suitable for helpful reminders that can be addressed when
  /// convenient.
  gentle,

  /// Border flash every 2 seconds, clear but not disruptive.
  ///
  /// Standard notification level for timer completions and
  /// scheduled events.
  standard,

  /// Full screen pulse at 1 Hz, requires attention.
  ///
  /// Used for important events that need acknowledgment soon.
  urgent,

  /// Rapid alternating colors at 2 Hz, immediate action needed.
  ///
  /// Reserved for critical alerts requiring immediate response.
  critical,
}
```

## Extension Documentation

Document what type is being extended and why:

```dart
/// Provides formatting utilities for [Duration] objects.
///
/// Adds ADHD-friendly time formatting methods that emphasize
/// readability and reduce cognitive load.
extension DurationFormatting on Duration {
  /// Formats duration as "Xm Ys" for easy scanning.
  ///
  /// Example: `Duration(seconds: 90).toReadableString()` returns "1m 30s"
  String toReadableString() {
    final minutes = inMinutes;
    final seconds = inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  /// Returns `true` if duration suggests break is needed.
  ///
  /// ADHD-optimized heuristic: sessions over 45 minutes often
  /// show diminishing returns in focus quality.
  bool suggestsBreak() => inMinutes > 45;
}
```

## State Management Documentation

Document state changes and side effects:

```dart
/// Manages timer state with MQTT synchronization.
///
/// Provides timer control methods (start, pause, reset) and maintains
/// synchronization with other devices via MQTT. State changes are
/// broadcast to all connected devices.
///
/// This class uses [ChangeNotifier] to notify listeners of state changes.
/// Widgets should use [Consumer<TimerController>] or [Provider.of] to
/// rebuild when state changes.
///
/// Example:
/// ```dart
/// final controller = Provider.of<TimerController>(context);
/// controller.startTimer(Duration(minutes: 25));
/// ```
class TimerController extends ChangeNotifier {
  /// Current timer state.
  ///
  /// Listeners are notified when this changes via [notifyListeners].
  TimerState _state = TimerState.idle;

  /// Starts timer with specified duration.
  ///
  /// Publishes start command to MQTT topic and begins local countdown.
  /// Other devices will synchronize automatically.
  ///
  /// Throws [StateError] if timer is already running.
  void startTimer(Duration duration) {
    if (_state == TimerState.running) {
      throw StateError('Timer is already running');
    }
    // ... implementation
    notifyListeners();  // Notify UI to rebuild
  }
}
```

## Async Method Documentation

Highlight async behavior and error handling:

```dart
/// Connects to MQTT broker and subscribes to timer topics.
///
/// Attempts connection with exponential backoff retry strategy.
/// Connection status updates are broadcast via [connectionStream].
///
/// Returns [Future] that completes when initial connection succeeds
/// or maximum retry count is reached.
///
/// Throws [MqttConnectionException] if broker is unreachable after
/// all retry attempts.
///
/// Example:
/// ```dart
/// try {
///   await mqttService.connect('mqtt://192.168.1.100:1883');
///   print('Connected to broker');
/// } on MqttConnectionException catch (e) {
///   print('Connection failed: $e');
/// }
/// ```
Future<void> connect(String brokerUrl) async {
```

## Test Documentation

Document what is being tested:

```dart
/// Tests for [TimerController] state management.
///
/// Verifies:
/// - Timer start/pause/reset functionality
/// - MQTT message publishing on state changes
/// - Listener notification on state updates
/// - Error handling for invalid state transitions
void main() {
  group('TimerController', () {
    late TimerController controller;
    late MockMqttClient mockMqtt;

    setUp(() {
      mockMqtt = MockMqttClient();
      controller = TimerController(mqttClient: mockMqtt);
    });

    /// Verifies timer starts from idle state and publishes MQTT message.
    test('starts timer from idle state', () {
      controller.startTimer(Duration(minutes: 25));
      expect(controller.state, TimerState.running);
      verify(mockMqtt.publish('timer/start', any)).called(1);
    });
```

## Constants Documentation

Document purpose and constraints:

```dart
/// MQTT topic structure for productivity system.
///
/// All topics follow hierarchical structure:
/// `productivity/{domain}/{action}/{identifier}`
class MqttTopics {
  /// Start timer command topic.
  static const timerStart = 'productivity/timer/control/start';

  /// Timer state synchronization topic.
  static const timerSync = 'productivity/timer/state/sync';

  /// Visual alert broadcast topic.
  static const alertVisual = 'productivity/alert/visual';
}

/// Default timer durations in seconds.
///
/// Based on ADHD-optimized Pomodoro technique with flexible
/// work periods and micro-breaks.
class TimerDefaults {
  /// Standard work period (25 minutes).
  static const workDuration = 1500;

  /// Short break period (5 minutes).
  static const shortBreak = 300;

  /// Micro-break for maintaining focus (30 seconds).
  ///
  /// Inserted automatically every 5 minutes during work periods.
  static const microBreak = 30;
}
```

## Inline Comments

Explain complex widgets or non-obvious Flutter patterns:

```dart
// Use RepaintBoundary to isolate timer widget repaints
// Prevents full screen rebuilds on every second tick
RepaintBoundary(
  child: CustomPaint(
    painter: CircularTimerPainter(
      progress: remainingSeconds / totalSeconds,
      urgencyColor: _calculateUrgencyColor(),
    ),
  ),
)
```

## What NOT to Document

Avoid self-explanatory code:

```dart
// BAD: Obvious comment
final total = a + b;  // Add a and b

// GOOD: Explains why
final total = workDuration + breakDuration;  // Full cycle duration
```

## Flutter-Specific Guidelines

### Widget Samples

Use `{@tool snippet}` for testable examples:

```dart
/// {@tool snippet}
/// This example shows a timer with custom colors:
///
/// ```dart
/// TimerWidget(
///   remainingSeconds: 900,
///   totalSeconds: 1500,
///   primaryColor: Colors.blue,
///   warningColor: Colors.orange,
/// )
/// ```
/// {@end-tool}
```

### Platform-Specific Notes

Document platform differences:

```dart
/// Sends system notification on timer completion.
///
/// On iOS, requires notification permissions to be granted.
/// On Android, creates notification channel on first use.
/// On Web, uses browser notifications API.
///
/// Returns [true] if notification was shown successfully.
Future<bool> showNotification(String message) async {
```

## Standards Summary

- Use `///` for documentation comments
- Document public APIs (classes, methods, widgets)
- Include examples with ```dart code blocks
- Use `{@tool snippet}` for testable widget samples
- Document parameters with [paramName] inline references
- Note platform-specific behavior
- Highlight async operations
- Document state changes in [ChangeNotifier]s
- Focus inline comments on "why"
- Use `See also:` for related classes
