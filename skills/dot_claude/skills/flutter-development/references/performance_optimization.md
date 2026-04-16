# Performance Optimization Techniques

## Overview

This guide covers performance optimization strategies for Flutter applications, including profiling, rendering optimization, memory management, and build optimization.

## Profiling and Debugging

### Flutter DevTools

```bash
# Launch DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Or run with flutter run
flutter run --profile
# Then press 'o' to open DevTools
```

### Performance Overlay

```dart
MaterialApp(
  showPerformanceOverlay: true, // Shows FPS and GPU rasterization
  home: HomeScreen(),
)
```

### Rendering Performance

```bash
# Enable debug painting
flutter run --debug

# In running app, toggle debug paint
// Press 'p' in terminal

# Or programmatically
import 'package:flutter/rendering.dart';

debugPaintSizeEnabled = true;
debugPaintBaselinesEnabled = true;
debugPaintLayerBordersEnabled = true;
debugRepaintRainbowEnabled = true;
```

## Widget Optimization

### Use const Constructors

```dart
// Bad: Creates new widget instance every rebuild
Widget build(BuildContext context) {
  return Text('Hello');
}

// Good: Reuses same widget instance
Widget build(BuildContext context) {
  return const Text('Hello');
}

// More examples
const SizedBox(height: 16)
const Padding(padding: EdgeInsets.all(8))
const Icon(Icons.home)
```

### Extract Static Widgets

```dart
// Bad: Rebuilds entire subtree unnecessarily
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Counter: $counter'),
        // This complex widget rebuilds every time counter changes
        ExpensiveWidget(),
        ElevatedButton(
          onPressed: () => setState(() => counter++),
          child: Text('Increment'),
        ),
      ],
    );
  }
}

// Good: Extract static widget
class _MyWidgetState extends State<MyWidget> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Counter: $counter'),
        const _StaticExpensiveWidget(), // Won't rebuild
        ElevatedButton(
          onPressed: () => setState(() => counter++),
          child: Text('Increment'),
        ),
      ],
    );
  }
}

class _StaticExpensiveWidget extends StatelessWidget {
  const _StaticExpensiveWidget();

  @override
  Widget build(BuildContext context) {
    return ExpensiveWidget();
  }
}
```

### Use RepaintBoundary

Isolates repainting to specific subtrees:

```dart
RepaintBoundary(
  child: AnimatedWidget(), // Only this subtree repaints
)

// Useful for:
// - Animated widgets
// - Complex custom painters
// - Lists with animated items
```

### Optimize ListView Performance

```dart
// Bad: Creates all items upfront
ListView(
  children: List.generate(1000, (i) => ListTile(title: Text('Item $i'))),
)

// Good: Lazy loading with builder
ListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)

// Better: Add item extent for better performance
ListView.builder(
  itemCount: 1000,
  itemExtent: 56, // Fixed height
  itemBuilder: (context, index) {
    return ListTile(title: Text('Item $index'));
  },
)

// Best: Use ListView.separated for dividers
ListView.separated(
  itemCount: 1000,
  itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
  separatorBuilder: (context, index) => const Divider(),
)
```

### Cache Complex Calculations

```dart
class ExpensiveWidget extends StatelessWidget {
  final List<Data> items;

  const ExpensiveWidget({required this.items});

  @override
  Widget build(BuildContext context) {
    // Bad: Recalculates on every build
    final processedItems = items.map((item) => expensiveProcessing(item)).toList();

    return ListView.builder(...);
  }
}

// Good: Cache the result
class ExpensiveWidget extends StatefulWidget {
  final List<Data> items;

  const ExpensiveWidget({required this.items});

  @override
  _ExpensiveWidgetState createState() => _ExpensiveWidgetState();
}

class _ExpensiveWidgetState extends State<ExpensiveWidget> {
  late List<ProcessedData> _cachedItems;

  @override
  void initState() {
    super.initState();
    _cachedItems = widget.items.map((item) => expensiveProcessing(item)).toList();
  }

  @override
  void didUpdateWidget(ExpensiveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _cachedItems = widget.items.map((item) => expensiveProcessing(item)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _cachedItems.length,
      itemBuilder: (context, index) => ItemWidget(item: _cachedItems[index]),
    );
  }
}
```

## Image Optimization

### Use Appropriate Image Formats

```dart
// For photos: Use JPEG
// For illustrations/icons: Use PNG or WebP
// For simple graphics: Use SVG

// Optimize image sizes
Image.asset(
  'assets/image.jpg',
  cacheWidth: 300, // Decode to specific width
  cacheHeight: 300,
)
```

### Cached Network Images

```yaml
dependencies:
  cached_network_image: ^3.3.0
```

```dart
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheWidth: 300,
  maxWidthDiskCache: 600,
)
```

### Optimize Large Lists with Images

```dart
ListView.builder(
  itemCount: items.length,
  cacheExtent: 100, // Preload items slightly off-screen
  itemBuilder: (context, index) {
    return Image.network(
      items[index].imageUrl,
      cacheWidth: 200,
      fit: BoxFit.cover,
    );
  },
)
```

## Build Method Optimization

### Avoid Heavy Computations in build()

```dart
// Bad
@override
Widget build(BuildContext context) {
  final data = expensiveComputation(); // Runs every rebuild
  return Text(data);
}

// Good
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late String data;

  @override
  void initState() {
    super.initState();
    data = expensiveComputation(); // Runs once
  }

  @override
  Widget build(BuildContext context) {
    return Text(data);
  }
}
```

### Minimize Widget Rebuilds

```dart
// Bad: Entire subtree rebuilds
class ParentWidget extends StatefulWidget {
  @override
  _ParentWidgetState createState() => _ParentWidgetState();
}

class _ParentWidgetState extends State<ParentWidget> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Counter: $counter'),
        ExpensiveChildWidget(), // Rebuilds unnecessarily
        ElevatedButton(
          onPressed: () => setState(() => counter++),
          child: Text('Increment'),
        ),
      ],
    );
  }
}

// Good: Use ValueNotifier or state management
class _ParentWidgetState extends State<ParentWidget> {
  final counterNotifier = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: counterNotifier,
          builder: (context, value, _) => Text('Counter: $value'),
        ),
        ExpensiveChildWidget(), // Doesn't rebuild
        ElevatedButton(
          onPressed: () => counterNotifier.value++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

## Memory Management

### Dispose Resources

```dart
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late AnimationController _controller;
  late StreamSubscription _subscription;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1));
    _subscription = stream.listen((data) {});
  }

  @override
  void dispose() {
    // Always dispose resources
    _controller.dispose();
    _subscription.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

### Avoid Memory Leaks

```dart
// Bad: Listener not removed
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    someNotifier.addListener(_handleChange);
  }

  void _handleChange() {
    setState(() {});
  }
}

// Good: Remove listener
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    someNotifier.addListener(_handleChange);
  }

  void _handleChange() {
    setState(() {});
  }

  @override
  void dispose() {
    someNotifier.removeListener(_handleChange);
    super.dispose();
  }
}
```

## Asynchronous Operations

### Use compute() for Heavy Operations

```dart
import 'package:flutter/foundation.dart';

// Heavy computation in isolate
Future<List<Result>> processData(List<Data> data) async {
  return compute(_processDataInIsolate, data);
}

// Top-level or static function
List<Result> _processDataInIsolate(List<Data> data) {
  // Expensive processing
  return data.map((item) => process(item)).toList();
}
```

### Debounce Expensive Operations

```dart
import 'dart:async';

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Timer? _debounce;

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounce?.cancel();

    // Create new timer
    _debounce = Timer(Duration(milliseconds: 500), () {
      // Perform expensive search
      performSearch(query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: _onSearchChanged,
    );
  }
}
```

## Animation Performance

### Use AnimatedBuilder

```dart
// Bad: Rebuilds entire widget tree
class AnimatedWidget extends StatefulWidget {
  @override
  _AnimatedWidgetState createState() => _AnimatedWidgetState();
}

class _AnimatedWidgetState extends State<AnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Entire column rebuilds on every frame
        StaticExpensiveWidget(),
        Transform.rotate(
          angle: _controller.value * 2 * pi,
          child: Icon(Icons.refresh),
        ),
      ],
    );
  }
}

// Good: Isolate animated part
class _AnimatedWidgetState extends State<AnimatedWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StaticExpensiveWidget(), // Doesn't rebuild
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * pi,
              child: child,
            );
          },
          child: Icon(Icons.refresh), // Built once, passed to builder
        ),
      ],
    );
  }
}
```

### Use TweenAnimationBuilder for Simple Animations

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: 1),
  duration: Duration(seconds: 1),
  builder: (context, value, child) {
    return Opacity(
      opacity: value,
      child: child,
    );
  },
  child: const Text('Fade in'), // Built once
)
```

## JSON Parsing

### Parse JSON in Isolate

```dart
// Bad: Blocks UI thread
Future<List<User>> fetchUsers() async {
  final response = await http.get(Uri.parse(url));
  final List<dynamic> jsonList = json.decode(response.body);
  return jsonList.map((json) => User.fromJson(json)).toList();
}

// Good: Parse in isolate
Future<List<User>> fetchUsers() async {
  final response = await http.get(Uri.parse(url));
  return compute(_parseUsers, response.body);
}

List<User> _parseUsers(String responseBody) {
  final List<dynamic> jsonList = json.decode(responseBody);
  return jsonList.map((json) => User.fromJson(json)).toList();
}
```

## Build Size Optimization

### Code Splitting

```dart
// Deferred loading
import 'package:my_app/heavy_feature.dart' deferred as heavy;

void loadHeavyFeature() async {
  await heavy.loadLibrary();
  heavy.showFeature();
}
```

### Remove Unused Resources

```bash
# Analyze unused resources
flutter pub run flutter_unused_files:find

# Check app size
flutter build apk --analyze-size
flutter build appbundle --analyze-size
```

### Optimize Images

```bash
# Use cwebp for WebP conversion
cwebp input.png -o output.webp

# Optimize PNGs
pngquant input.png --output output.png
```

## Network Optimization

### Implement Caching

```dart
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

final dio = Dio()
  ..interceptors.add(
    DioCacheInterceptor(
      options: CacheOptions(
        store: MemCacheStore(),
        maxStale: Duration(days: 7),
      ),
    ),
  );
```

### Batch API Requests

```dart
// Bad: Multiple sequential requests
final user = await api.getUser(id);
final posts = await api.getUserPosts(id);
final followers = await api.getUserFollowers(id);

// Good: Parallel requests
final results = await Future.wait([
  api.getUser(id),
  api.getUserPosts(id),
  api.getUserFollowers(id),
]);

final user = results[0];
final posts = results[1];
final followers = results[2];
```

## Testing Performance

### Benchmarking

```dart
void main() {
  test('performance test', () {
    final stopwatch = Stopwatch()..start();

    // Code to benchmark
    expensiveOperation();

    stopwatch.stop();
    print('Elapsed time: ${stopwatch.elapsedMilliseconds}ms');

    expect(stopwatch.elapsedMilliseconds, lessThan(100));
  });
}
```

### Integration Test Performance

```dart
import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Performance test', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('scroll performance', () async {
      final timeline = await driver.traceAction(() async {
        await driver.scrollUntilVisible(
          find.byType('ListView'),
          find.text('Item 100'),
          dyScroll: -300,
        );
      });

      final summary = TimelineSummary.summarize(timeline);
      await summary.writeSummaryToFile('scroll_summary', pretty: true);
      await summary.writeTimelineToFile('scroll_timeline', pretty: true);
    });
  });
}
```

## Best Practices Summary

1. **Use const constructors** - Reduces widget rebuilds
2. **Extract static widgets** - Prevent unnecessary rebuilds
3. **Lazy load lists** - Use ListView.builder, not ListView with children
4. **Cache images** - Use cached_network_image
5. **Dispose resources** - Always clean up controllers, streams, listeners
6. **Profile regularly** - Use DevTools to identify bottlenecks
7. **Optimize images** - Use appropriate formats and sizes
8. **Use isolates for heavy work** - Don't block the UI thread
9. **Debounce expensive operations** - Search, API calls, etc.
10. **Minimize build method logic** - Move computations to initState or didUpdateWidget

## Common Performance Pitfalls

1. **Creating widgets in build method** - Extract to const or methods
2. **Not using const constructors** - Misses optimization opportunities
3. **Excessive setState calls** - Use targeted state management
4. **Large build methods** - Break into smaller widgets
5. **Synchronous I/O in UI thread** - Always use async
6. **Not disposing resources** - Memory leaks
7. **Loading too many images** - Use lazy loading and caching
8. **Complex layout calculations** - Cache results when possible
9. **Unnecessary rebuilds** - Use keys, const, and state management properly
10. **Ignoring DevTools warnings** - Profile and address issues early

## Measuring Success

Use Flutter DevTools to monitor:
- **Frame rendering time**: Should be < 16ms (60fps) or < 8ms (120fps)
- **Memory usage**: Should remain stable, no leaks
- **App size**: Minimize APK/IPA size
- **Network usage**: Minimize requests and data transfer
- **Battery usage**: Profile on physical devices
