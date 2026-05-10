# Platform-Specific Code Handling

## Overview

This guide covers techniques for handling platform-specific code in Flutter apps targeting iOS, Android, Web, Desktop (Windows, macOS, Linux), and embedded platforms.

## Platform Detection

### Runtime Platform Checks

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// Check if running on web
if (kIsWeb) {
  // Web-specific code
}

// Check specific platforms (not available on web)
if (!kIsWeb) {
  if (Platform.isAndroid) {
    // Android-specific code
  } else if (Platform.isIOS) {
    // iOS-specific code
  } else if (Platform.isMacOS) {
    // macOS-specific code
  } else if (Platform.isWindows) {
    // Windows-specific code
  } else if (Platform.isLinux) {
    // Linux-specific code
  } else if (Platform.isFuchsia) {
    // Fuchsia-specific code
  }
}

// Group mobile vs desktop
bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
```

### Theme-Based Platform Detection

```dart
import 'package:flutter/material.dart';

final platform = Theme.of(context).platform;

switch (platform) {
  case TargetPlatform.android:
    // Android-specific UI
    break;
  case TargetPlatform.iOS:
    // iOS-specific UI
    break;
  case TargetPlatform.macOS:
    // macOS-specific UI
    break;
  case TargetPlatform.windows:
    // Windows-specific UI
    break;
  case TargetPlatform.linux:
    // Linux-specific UI
    break;
  case TargetPlatform.fuchsia:
    // Fuchsia-specific UI
    break;
}
```

## Conditional Imports

Use conditional imports to include platform-specific libraries:

```dart
// platform_helper.dart
export 'platform_helper_stub.dart'
    if (dart.library.io) 'platform_helper_io.dart'
    if (dart.library.html) 'platform_helper_web.dart';

// platform_helper_stub.dart (fallback)
String getPlatformName() => 'Unknown';

// platform_helper_io.dart (mobile/desktop)
import 'dart:io';

String getPlatformName() {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS';
  return 'Desktop';
}

// platform_helper_web.dart
String getPlatformName() => 'Web';

// Usage
import 'platform_helper.dart';

void main() {
  print(getPlatformName());
}
```

## Adaptive Widgets

### Material vs Cupertino

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AdaptiveButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AdaptiveButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    if (platform == TargetPlatform.iOS) {
      return CupertinoButton(
        onPressed: onPressed,
        color: CupertinoColors.activeBlue,
        child: Text(text),
      );
    } else {
      return ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
      );
    }
  }
}

// Or use Platform.isIOS directly
Widget buildButton(BuildContext context) {
  if (Platform.isIOS) {
    return CupertinoButton(
      onPressed: () {},
      child: Text('Button'),
    );
  }
  return ElevatedButton(
    onPressed: () {},
    child: Text('Button'),
  );
}
```

### Adaptive App Structure

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoApp(
        title: 'My App',
        theme: CupertinoThemeData(
          primaryColor: CupertinoColors.activeBlue,
        ),
        home: HomeScreen(),
      );
    }

    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}
```

### Adaptive Dialogs

```dart
Future<void> showAdaptiveDialog(BuildContext context) async {
  if (Platform.isIOS) {
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Alert'),
        content: Text('This is an alert'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alert'),
        content: Text('This is an alert'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
```

## Platform Channels

Platform channels enable communication between Flutter and native platform code.

### Method Channel (Bidirectional Communication)

```dart
// Flutter side
import 'package:flutter/services.dart';

class BatteryLevel {
  static const platform = MethodChannel('com.example.app/battery');

  Future<int> getBatteryLevel() async {
    try {
      final int result = await platform.invokeMethod('getBatteryLevel');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get battery level: '${e.message}'");
      return -1;
    }
  }

  Future<void> startCharging() async {
    try {
      await platform.invokeMethod('startCharging');
    } on PlatformException catch (e) {
      print("Failed: '${e.message}'");
    }
  }
}
```

#### Android Implementation

```kotlin
// android/app/src/main/kotlin/com/example/app/MainActivity.kt
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.app/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "getBatteryLevel" -> {
                    val batteryLevel = getBatteryLevel()
                    if (batteryLevel != -1) {
                        result.success(batteryLevel)
                    } else {
                        result.error("UNAVAILABLE", "Battery level not available.", null)
                    }
                }
                "startCharging" -> {
                    // Implementation
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getBatteryLevel(): Int {
        val batteryLevel: Int
        if (VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } else {
            val intent = ContextWrapper(applicationContext).registerReceiver(
                null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            )
            batteryLevel = intent!!.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) * 100 /
                    intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        }
        return batteryLevel
    }
}
```

#### iOS Implementation

```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let batteryChannel = FlutterMethodChannel(
        name: "com.example.app/battery",
        binaryMessenger: controller.binaryMessenger
    )

    batteryChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "getBatteryLevel" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.receiveBatteryLevel(result: result)
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func receiveBatteryLevel(result: FlutterResult) {
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true
    if device.batteryState == UIDevice.BatteryState.unknown {
      result(FlutterError(code: "UNAVAILABLE",
                         message: "Battery level not available.",
                         details: nil))
    } else {
      result(Int(device.batteryLevel * 100))
    }
  }
}
```

### Event Channel (Streaming Data)

```dart
// Flutter side
import 'package:flutter/services.dart';

class BatteryStream {
  static const stream = EventChannel('com.example.app/battery_stream');

  Stream<int> get batteryStream {
    return stream.receiveBroadcastStream().map((dynamic level) => level as int);
  }
}

// Usage
StreamBuilder<int>(
  stream: BatteryStream().batteryStream,
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return Text('Battery: ${snapshot.data}%');
    }
    return CircularProgressIndicator();
  },
)
```

#### Android Implementation

```kotlin
import io.flutter.plugin.common.EventChannel
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager

class BatteryStreamHandler : EventChannel.StreamHandler {
    private var receiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                val batteryPct = level * 100 / scale
                events?.success(batteryPct)
            }
        }
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        context.registerReceiver(receiver, filter)
    }

    override fun onCancel(arguments: Any?) {
        context.unregisterReceiver(receiver)
        receiver = null
    }
}

// In MainActivity
EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.app/battery_stream")
    .setStreamHandler(BatteryStreamHandler())
```

## Platform-Specific File Organization

```
lib/
├── main.dart
├── models/
├── screens/
├── widgets/
└── platform/
    ├── platform_service.dart          # Interface
    ├── platform_service_mobile.dart   # Mobile implementation
    ├── platform_service_web.dart      # Web implementation
    └── platform_service_desktop.dart  # Desktop implementation
```

## Responsive Design for Different Platforms

### Breakpoint-Based Layout

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  @override
  Widget build(BuildContext context) {
    if (isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

// Usage
ResponsiveLayout(
  mobile: MobileLayout(),
  tablet: TabletLayout(),
  desktop: DesktopLayout(),
)
```

### Adaptive Grid

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
    crossAxisSpacing: 8,
    mainAxisSpacing: 8,
  ),
  itemBuilder: (context, index) => ItemCard(),
)
```

## Platform-Specific Permissions

```yaml
# pubspec.yaml
dependencies:
  permission_handler: ^11.0.1
```

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.request();
  return status.isGranted;
}

Future<void> handlePermissions() async {
  // Check permission status
  final status = await Permission.camera.status;

  if (status.isDenied) {
    // Request permission
    final result = await Permission.camera.request();
    if (result.isGranted) {
      // Permission granted
    }
  } else if (status.isPermanentlyDenied) {
    // Open app settings
    await openAppSettings();
  }
}
```

### Android Permissions

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
</manifest>
```

### iOS Permissions

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to take photos</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to show nearby places</string>
```

## Platform-Specific Assets

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/
    - assets/images/android/
    - assets/images/ios/
```

```dart
String getAssetPath(String asset) {
  if (Platform.isAndroid) {
    return 'assets/images/android/$asset';
  } else if (Platform.isIOS) {
    return 'assets/images/ios/$asset';
  }
  return 'assets/images/$asset';
}
```

## Desktop-Specific Features

### Window Management

```yaml
dependencies:
  window_manager: ^0.3.7
```

```dart
import 'package:window_manager/window_manager.dart';

Future<void> initializeWindow() async {
  await windowManager.ensureInitialized();

  await windowManager.setTitle('My App');
  await windowManager.setMinimumSize(Size(800, 600));
  await windowManager.setSize(Size(1200, 800));
  await windowManager.center();
  await windowManager.show();
}
```

### System Tray

```yaml
dependencies:
  system_tray: ^2.0.3
```

```dart
import 'package:system_tray/system_tray.dart';

final SystemTray systemTray = SystemTray();

Future<void> initSystemTray() async {
  await systemTray.initSystemTray(
    title: 'My App',
    iconPath: Platform.isWindows ? 'assets/icon.ico' : 'assets/icon.png',
  );

  final Menu menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(label: 'Show', onClicked: (menuItem) => windowManager.show()),
    MenuItemLabel(label: 'Hide', onClicked: (menuItem) => windowManager.hide()),
    MenuSeparator(),
    MenuItemLabel(label: 'Exit', onClicked: (menuItem) => exit(0)),
  ]);

  await systemTray.setContextMenu(menu);
}
```

## Web-Specific Features

### URL Strategy

```dart
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void main() {
  usePathUrlStrategy(); // Remove # from URLs
  runApp(MyApp());
}
```

### JavaScript Interop

```dart
import 'dart:html' as html;

void downloadFile(String data, String filename) {
  final bytes = utf8.encode(data);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
```

## Best Practices

1. **Use conditional imports for platform-specific code**
2. **Abstract platform differences behind interfaces**
3. **Test on all target platforms regularly**
4. **Use adaptive widgets for better UX**
5. **Handle permissions properly on each platform**
6. **Consider platform-specific design guidelines** (Material for Android, Cupertino for iOS)
7. **Optimize assets for each platform**
8. **Use platform channels sparingly** - Prefer Flutter plugins when available
9. **Document platform-specific requirements**
10. **Handle platform-specific edge cases** (e.g., iOS safe area, Android system buttons)

## Common Pitfalls

1. **Using dart:io on web** - Use kIsWeb checks
2. **Hardcoding platform assumptions** - Test on all platforms
3. **Ignoring platform design guidelines** - Users expect platform-consistent UX
4. **Not handling permission denials** - Always check permission status
5. **Platform channel memory leaks** - Properly dispose listeners
6. **Inconsistent error handling** - Platform-specific errors need platform-specific handling
