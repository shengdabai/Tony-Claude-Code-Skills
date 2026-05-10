# Navigation and Routing Best Practices

## Overview

This guide covers navigation and routing patterns in Flutter, focusing on modern declarative routing with go_router and best practices for multi-platform apps.

## Navigation Approaches

### 1. Imperative Navigation (Basic)

Simple push/pop navigation for small apps:

```dart
// Push to a new screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => DetailScreen()),
);

// Pop back
Navigator.pop(context);

// Push and remove all previous routes
Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (context) => HomeScreen()),
  (route) => false,
);
```

### 2. Named Routes

Better for medium apps with defined routes:

```dart
// Define routes
MaterialApp(
  initialRoute: '/',
  routes: {
    '/': (context) => HomeScreen(),
    '/details': (context) => DetailsScreen(),
    '/profile': (context) => ProfileScreen(),
  },
);

// Navigate
Navigator.pushNamed(context, '/details');
Navigator.pushNamed(
  context,
  '/details',
  arguments: {'id': 123},
);

// Receive arguments
final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
```

### 3. Declarative Routing with go_router (Recommended)

Modern, type-safe routing for production apps:

```yaml
# pubspec.yaml
dependencies:
  go_router: ^13.0.0
```

## go_router Implementation

### Basic Setup

```dart
import 'package:go_router/go_router.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/details/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DetailsScreen(id: id);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => ProfileScreen(),
    ),
  ],
);

// In MaterialApp
MaterialApp.router(
  routerConfig: router,
);
```

### Navigation with go_router

```dart
// Navigate to a route
context.go('/details/123');

// Push (keep previous route in stack)
context.push('/profile');

// Go with query parameters
context.go('/search?q=flutter');

// Access query parameters
final query = state.uri.queryParameters['q'];

// Replace current route
context.replace('/login');

// Pop
context.pop();

// Pop with result
context.pop('result');
```

### Nested Routes and Shell Routes

```dart
final router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        // Shell UI with bottom navigation
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => HomeScreen(),
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => FavoritesScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => SettingsScreen(),
        ),
      ],
    ),
    // Routes outside shell
    GoRoute(
      path: '/details/:id',
      builder: (context, state) => DetailsScreen(id: state.pathParameters['id']!),
    ),
  ],
);

// ScaffoldWithNavBar maintains bottom nav across routes
class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/favorites')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/favorites');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }
}
```

### Route Guards and Redirects

```dart
final router = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = /* check auth state */;
    final isGoingToLogin = state.matchedLocation == '/login';

    // Redirect to login if not authenticated
    if (!isLoggedIn && !isGoingToLogin) {
      return '/login';
    }

    // Redirect to home if already logged in and trying to access login
    if (isLoggedIn && isGoingToLogin) {
      return '/home';
    }

    return null; // No redirect
  },
  routes: [...],
);

// Per-route redirect
GoRoute(
  path: '/admin',
  redirect: (context, state) {
    final isAdmin = /* check admin status */;
    return isAdmin ? null : '/';
  },
  builder: (context, state) => AdminScreen(),
)
```

### Integration with State Management

#### With Riverpod

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    refreshListenable: authState, // Rebuild router when auth changes
    redirect: (context, state) {
      final isAuthenticated = authState.value?.isAuthenticated ?? false;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }

      if (isAuthenticated && isGoingToLogin) {
        return '/home';
      }

      return null;
    },
    routes: [...],
  );
});

// In app
ConsumerWidget(
  builder: (context, ref, _) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(routerConfig: router);
  },
)
```

#### With Bloc

```dart
class AppRouter {
  final AuthBloc authBloc;
  late final GoRouter router;

  AppRouter(this.authBloc) {
    router = GoRouter(
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final isAuthenticated = authState is AuthAuthenticated;
        final isGoingToLogin = state.matchedLocation == '/login';

        if (!isAuthenticated && !isGoingToLogin) {
          return '/login';
        }

        if (isAuthenticated && isGoingToLogin) {
          return '/home';
        }

        return null;
      },
      routes: [...],
    );
  }
}

// Helper to convert Stream to Listenable
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
```

### Deep Linking

#### Android Setup

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<activity android:name=".MainActivity">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
      android:scheme="https"
      android:host="myapp.com"
      android:pathPrefix="/details" />
  </intent-filter>
</activity>
```

#### iOS Setup

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp</string>
    </array>
  </dict>
</array>
```

#### go_router Deep Link Handling

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/details/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DetailsScreen(id: id);
      },
    ),
  ],
);

// Will automatically handle: myapp://details/123 or https://myapp.com/details/123
```

### Web URL Strategy

```dart
// main.dart
import 'package:flutter_web_plugins/url_strategy.dart';

void main() {
  usePathUrlStrategy(); // Remove # from URLs
  runApp(MyApp());
}
```

## Advanced Navigation Patterns

### Modal Bottom Sheets

```dart
// Show modal
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: 0.6,
    minChildSize: 0.3,
    maxChildSize: 0.9,
    builder: (context, scrollController) {
      return FilterScreen(scrollController: scrollController);
    },
  ),
);

// Full-screen modal
Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (context) => CreatePostScreen(),
  ),
);
```

### Tabs Navigation

```dart
DefaultTabController(
  length: 3,
  child: Scaffold(
    appBar: AppBar(
      bottom: TabBar(
        tabs: [
          Tab(icon: Icon(Icons.home), text: 'Home'),
          Tab(icon: Icon(Icons.search), text: 'Search'),
          Tab(icon: Icon(Icons.person), text: 'Profile'),
        ],
      ),
    ),
    body: TabBarView(
      children: [
        HomeTab(),
        SearchTab(),
        ProfileTab(),
      ],
    ),
  ),
)
```

### Drawer Navigation

```dart
Scaffold(
  appBar: AppBar(title: Text('App')),
  drawer: Drawer(
    child: ListView(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(color: Colors.blue),
          child: Text('Menu'),
        ),
        ListTile(
          leading: Icon(Icons.home),
          title: Text('Home'),
          onTap: () {
            Navigator.pop(context); // Close drawer
            context.go('/home');
          },
        ),
        ListTile(
          leading: Icon(Icons.settings),
          title: Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            context.go('/settings');
          },
        ),
      ],
    ),
  ),
  body: child,
)
```

### Page Transitions

```dart
// Custom page transition
GoRoute(
  path: '/details/:id',
  pageBuilder: (context, state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: DetailsScreen(id: state.pathParameters['id']!),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  },
)

// Slide transition
transitionsBuilder: (context, animation, secondaryAnimation, child) {
  const begin = Offset(1.0, 0.0);
  const end = Offset.zero;
  const curve = Curves.easeInOut;

  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
  var offsetAnimation = animation.drive(tween);

  return SlideTransition(
    position: offsetAnimation,
    child: child,
  );
}
```

## Multi-Platform Considerations

### Adaptive Navigation

```dart
class AdaptiveScaffold extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    // Use NavigationRail for desktop/tablet, BottomNavigationBar for mobile
    if (MediaQuery.of(context).size.width >= 600) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: [
                NavigationRailDestination(
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.search),
                  label: Text('Search'),
                ),
              ],
            ),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: body,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onDestinationSelected,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          ],
        ),
      );
    }
  }
}
```

### Platform-Specific Navigation Patterns

```dart
// iOS-style navigation with CupertinoPageRoute
if (Platform.isIOS) {
  Navigator.push(
    context,
    CupertinoPageRoute(builder: (context) => DetailsScreen()),
  );
} else {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => DetailsScreen()),
  );
}

// Or use adaptive route
Page<void> buildPage(BuildContext context, GoRouterState state) {
  if (Platform.isIOS) {
    return CupertinoPage(child: DetailsScreen());
  } else {
    return MaterialPage(child: DetailsScreen());
  }
}
```

## Testing Navigation

### Unit Testing Routes

```dart
void main() {
  test('go_router redirects unauthenticated users to login', () async {
    final router = GoRouter(
      initialLocation: '/home',
      redirect: (context, state) {
        final isAuthenticated = false; // Simulate unauthenticated
        if (!isAuthenticated && state.matchedLocation != '/login') {
          return '/login';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/home', builder: (_, __) => Container()),
        GoRoute(path: '/login', builder: (_, __) => Container()),
      ],
    );

    expect(router.routeInformationProvider.value.uri.path, '/login');
  });
}
```

### Widget Testing Navigation

```dart
testWidgets('navigates to details screen', (tester) async {
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
    ),
  );

  // Tap button that navigates
  await tester.tap(find.text('Go to Details'));
  await tester.pumpAndSettle();

  // Verify navigation occurred
  expect(find.text('Details Screen'), findsOneWidget);
});
```

## Best Practices

1. **Use go_router for production apps** - Type-safe, declarative, and web-friendly
2. **Implement deep linking early** - Much harder to add later
3. **Handle navigation state persistence** - Save/restore navigation state on app restart
4. **Use shell routes for persistent UI** - Keep bottom nav/drawer visible across routes
5. **Test navigation flows** - Ensure critical paths work correctly
6. **Handle back button properly** - Especially on Android
7. **Use route guards** - Protect authenticated routes
8. **Consider platform differences** - iOS and Android have different navigation patterns
9. **Optimize for web** - Use path URLs, handle browser back button
10. **Avoid navigation in initState** - Use post-frame callback or didChangeDependencies

## Common Pitfalls

1. **Context errors** - Using context after Navigator.push without checking mounted
2. **Memory leaks** - Not disposing controllers when navigating away
3. **Deep navigation stacks** - Use pushAndRemoveUntil or replace when appropriate
4. **Ignoring pop results** - Not handling data returned from pushed routes
5. **Hardcoding routes** - Use constants or enums for route names
6. **Not handling navigation errors** - Add error page route

```dart
// Error page
GoRoute(
  path: '/error',
  builder: (context, state) => ErrorScreen(
    error: state.extra as Exception?,
  ),
),
// Error redirect in router
errorBuilder: (context, state) => ErrorScreen(error: state.error),
```
