# Widget Composition Patterns

## Overview

This guide covers best practices for composing widgets in Flutter, including reusability, maintainability, and proper widget hierarchy design.

## Core Principles

### 1. Single Responsibility

Each widget should have one clear purpose:

```dart
// Bad: Widget does too much
class UserCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          CircleAvatar(...), // Avatar logic
          Text(...), // Name display
          Row(...), // Action buttons
          Divider(),
          Text(...), // Bio text
          // More complexity...
        ],
      ),
    );
  }
}

// Good: Break into focused widgets
class UserCard extends StatelessWidget {
  final User user;

  const UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            UserAvatar(user: user),
            SizedBox(height: 8),
            UserName(user: user),
            SizedBox(height: 8),
            UserActions(user: user),
            Divider(),
            UserBio(user: user),
          ],
        ),
      ),
    );
  }
}
```

### 2. Composition Over Inheritance

Prefer composing widgets over extending them:

```dart
// Bad: Inheritance
class CustomButton extends ElevatedButton {
  CustomButton({required VoidCallback onPressed})
      : super(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: Text('Custom'),
        );
}

// Good: Composition
class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const CustomButton({
    required this.onPressed,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
      ),
      child: Text(text),
    );
  }
}
```

### 3. Use Builder Pattern for Complex Widgets

```dart
class DialogBuilder {
  String? title;
  String? message;
  List<Widget> actions = [];

  DialogBuilder setTitle(String title) {
    this.title = title;
    return this;
  }

  DialogBuilder setMessage(String message) {
    this.message = message;
    return this;
  }

  DialogBuilder addAction(Widget action) {
    actions.add(action);
    return this;
  }

  AlertDialog build() {
    return AlertDialog(
      title: title != null ? Text(title!) : null,
      content: message != null ? Text(message!) : null,
      actions: actions,
    );
  }
}

// Usage
final dialog = DialogBuilder()
    .setTitle('Confirm')
    .setMessage('Are you sure?')
    .addAction(TextButton(onPressed: () {}, child: Text('Cancel')))
    .addAction(TextButton(onPressed: () {}, child: Text('OK')))
    .build();
```

## Reusable Widget Patterns

### 1. Configurable Widgets

```dart
class CustomCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final double? elevation;
  final VoidCallback? onTap;

  const CustomCard({
    required this.child,
    this.backgroundColor,
    this.padding,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      elevation: elevation ?? 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
```

### 2. Builder Widgets

```dart
class ConditionalBuilder extends StatelessWidget {
  final bool condition;
  final WidgetBuilder trueBuilder;
  final WidgetBuilder falseBuilder;

  const ConditionalBuilder({
    required this.condition,
    required this.trueBuilder,
    required this.falseBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return condition ? trueBuilder(context) : falseBuilder(context);
  }
}

// Usage
ConditionalBuilder(
  condition: isLoggedIn,
  trueBuilder: (context) => HomeScreen(),
  falseBuilder: (context) => LoginScreen(),
)
```

### 3. Wrapper Widgets

```dart
class LoadingWrapper extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? loadingWidget;

  const LoadingWrapper({
    required this.isLoading,
    required this.child,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: loadingWidget ?? CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
```

## Layout Patterns

### 1. Responsive Layout

```dart
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWidget({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200 && desktop != null) {
      return desktop!;
    } else if (width >= 600 && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}
```

### 2. Spacing Utilities

```dart
class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class Gap extends StatelessWidget {
  final double size;
  final Axis direction;

  const Gap(this.size, {this.direction = Axis.vertical});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: direction == Axis.horizontal ? size : null,
      height: direction == Axis.vertical ? size : null,
    );
  }
}

// Usage
Column(
  children: [
    Text('Item 1'),
    Gap(Spacing.md),
    Text('Item 2'),
  ],
)
```

### 3. Flexible Grid

```dart
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double childAspectRatio;

  const ResponsiveGrid({
    required this.children,
    this.childAspectRatio = 1,
  });

  int _getCrossAxisCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 800) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return GridView.count(
      crossAxisCount: _getCrossAxisCount(width),
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }
}
```

## State Management Patterns

### 1. InheritedWidget Pattern

```dart
class ThemeProvider extends InheritedWidget {
  final ThemeData theme;

  const ThemeProvider({
    required this.theme,
    required Widget child,
  }) : super(child: child);

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) {
    return theme != oldWidget.theme;
  }
}

// Usage
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = ThemeProvider.of(context)!.theme;
    return Container(color: theme.primaryColor);
  }
}
```

### 2. Provider Pattern (Simplified)

```dart
class CounterProvider extends ChangeNotifier {
  int _count = 0;

  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}

// In widget
class CounterWidget extends StatelessWidget {
  final CounterProvider provider;

  const CounterWidget({required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        return Text('Count: ${provider.count}');
      },
    );
  }
}
```

## Error Handling Patterns

### 1. Error Boundary Widget

```dart
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;

  const ErrorBoundary({
    required this.child,
    this.errorBuilder,
  });

  @override
  _ErrorBoundaryState createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace) ??
          Center(child: Text('An error occurred'));
    }

    return ErrorWidget.builder = (details) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
      });
      return SizedBox.shrink();
    };

    return widget.child;
  }
}
```

### 2. Async Result Widget

```dart
class AsyncWidget<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget Function(Object error)? errorBuilder;

  const AsyncWidget({
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return builder(snapshot.data as T);
        } else if (snapshot.hasError) {
          return errorBuilder?.call(snapshot.error!) ??
              Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return loadingWidget ?? Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}

// Usage
AsyncWidget<User>(
  future: fetchUser(),
  builder: (user) => UserProfile(user: user),
  loadingWidget: LoadingIndicator(),
  errorBuilder: (error) => ErrorDisplay(error: error),
)
```

## Data Flow Patterns

### 1. Callback Pattern

```dart
class CustomInput extends StatelessWidget {
  final String label;
  final ValueChanged<String> onChanged;

  const CustomInput({
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}

// Usage
CustomInput(
  label: 'Username',
  onChanged: (value) {
    print('Username changed: $value');
  },
)
```

### 2. Controller Pattern

```dart
class CustomFormController {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String get name => nameController.text;
  String get email => emailController.text;

  void dispose() {
    nameController.dispose();
    emailController.dispose();
  }
}

class CustomForm extends StatefulWidget {
  @override
  _CustomFormState createState() => _CustomFormState();
}

class _CustomFormState extends State<CustomForm> {
  late CustomFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CustomFormController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _controller.nameController),
        TextField(controller: _controller.emailController),
      ],
    );
  }
}
```

## Advanced Composition Patterns

### 1. Render Object Pattern

```dart
class CustomPaint extends SingleChildRenderObjectWidget {
  final CustomPainter painter;

  const CustomPaint({
    required this.painter,
    Widget? child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCustomPaint(painter: painter);
  }

  @override
  void updateRenderObject(BuildContext context, RenderCustomPaint renderObject) {
    renderObject.painter = painter;
  }
}
```

### 2. Sliver Pattern

```dart
class SliverAppBarBuilder extends StatelessWidget {
  final String title;
  final List<Widget> slivers;

  const SliverAppBarBuilder({
    required this.title,
    required this.slivers,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(title),
          floating: true,
          expandedHeight: 200,
        ),
        ...slivers,
      ],
    );
  }
}
```

### 3. Notification Pattern

```dart
class CustomNotification extends Notification {
  final String message;

  const CustomNotification(this.message);
}

class NotificationSender extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        CustomNotification('Button pressed').dispatch(context);
      },
      child: Text('Send Notification'),
    );
  }
}

class NotificationReceiver extends StatelessWidget {
  final Widget child;

  const NotificationReceiver({required this.child});

  @override
  Widget build(BuildContext context) {
    return NotificationListener<CustomNotification>(
      onNotification: (notification) {
        print('Received: ${notification.message}');
        return true; // Stop propagation
      },
      child: child,
    );
  }
}
```

## Testing Patterns

### 1. Testable Widget Design

```dart
// Good: Easy to test
class UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onTap;

  const UserCard({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(user.name),
        onTap: onTap,
      ),
    );
  }
}

// Test
testWidgets('UserCard displays user name', (tester) async {
  final user = User(name: 'John Doe');
  var tapped = false;

  await tester.pumpWidget(
    MaterialApp(
      home: UserCard(
        user: user,
        onTap: () => tapped = true,
      ),
    ),
  );

  expect(find.text('John Doe'), findsOneWidget);

  await tester.tap(find.byType(UserCard));
  expect(tapped, true);
});
```

### 2. Mock-Friendly Design

```dart
abstract class DataSource {
  Future<List<Item>> fetchItems();
}

class ItemList extends StatelessWidget {
  final DataSource dataSource;

  const ItemList({required this.dataSource});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Item>>(
      future: dataSource.fetchItems(),
      builder: (context, snapshot) {
        // Build UI
      },
    );
  }
}

// In test, pass mock DataSource
class MockDataSource implements DataSource {
  @override
  Future<List<Item>> fetchItems() async {
    return [Item(name: 'Test')];
  }
}
```

## Best Practices

1. **Keep widgets small and focused** - Single responsibility
2. **Use const constructors** - Better performance
3. **Extract reusable components** - DRY principle
4. **Prefer composition over inheritance** - More flexible
5. **Pass data down, callbacks up** - Clear data flow
6. **Use builders for conditional rendering** - Cleaner code
7. **Separate business logic from UI** - Testability
8. **Use keys when necessary** - Proper widget identity
9. **Leverage existing widgets** - Don't reinvent the wheel
10. **Document complex widgets** - Maintainability

## Anti-Patterns to Avoid

1. **God widgets** - Widgets that do too much
2. **Tight coupling** - Hard dependencies between widgets
3. **Business logic in build()** - Violates separation of concerns
4. **Excessive nesting** - Hard to read and maintain
5. **Not using const** - Missed optimization
6. **Ignoring keys** - State issues with lists
7. **Creating widgets in methods** - Use widget classes
8. **Mutable state in StatelessWidget** - Use StatefulWidget
9. **Not disposing resources** - Memory leaks
10. **Hardcoded values** - Use theme and constants

## Example: Well-Composed Widget

```dart
// Good widget composition example
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavorite;

  const ProductCard({
    required this.product,
    this.onAddToCart,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProductImage(imageUrl: product.imageUrl),
          Gap(Spacing.sm),
          _ProductInfo(product: product),
          Gap(Spacing.md),
          _ProductActions(
            onAddToCart: onAddToCart,
            onFavorite: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _ProductInfo extends StatelessWidget {
  final Product product;

  const _ProductInfo({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Gap(Spacing.xs),
        Text(
          '\$${product.price.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _ProductActions extends StatelessWidget {
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavorite;

  const _ProductActions({
    this.onAddToCart,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onAddToCart,
            icon: const Icon(Icons.shopping_cart),
            label: const Text('Add to Cart'),
          ),
        ),
        Gap(Spacing.sm, direction: Axis.horizontal),
        IconButton(
          onPressed: onFavorite,
          icon: const Icon(Icons.favorite_border),
        ),
      ],
    );
  }
}
```

This example demonstrates:
- Small, focused widgets
- Clear widget hierarchy
- Reusable components
- Proper const usage
- Clean data flow
- Testability
- Maintainability
