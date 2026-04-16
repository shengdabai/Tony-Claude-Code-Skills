# Material Design 3 Implementation

## Overview

Material Design 3 (Material You) is Google's latest design system, featuring dynamic color, updated components, and improved accessibility. This guide covers implementing MD3 in Flutter.

## Enabling Material 3

```dart
MaterialApp(
  theme: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  ),
  home: HomeScreen(),
)
```

## Color System

### Dynamic Color Schemes

Material 3 uses a sophisticated color system with tonal palettes.

```dart
// From seed color
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.purple,
    brightness: Brightness.light,
  ),
)

// Dark theme
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.purple,
    brightness: Brightness.dark,
  ),
)
```

### Custom Color Scheme

```dart
ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF6750A4),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFEADDFF),
  onPrimaryContainer: Color(0xFF21005D),
  secondary: Color(0xFF625B71),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFE8DEF8),
  onSecondaryContainer: Color(0xFF1D192B),
  tertiary: Color(0xFF7D5260),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFFD8E4),
  onTertiaryContainer: Color(0xFF31111D),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  background: Color(0xFFFFFBFE),
  onBackground: Color(0xFF1C1B1F),
  surface: Color(0xFFFFFBFE),
  onSurface: Color(0xFF1C1B1F),
  surfaceVariant: Color(0xFFE7E0EC),
  onSurfaceVariant: Color(0xFF49454F),
  outline: Color(0xFF79747E),
  outlineVariant: Color(0xFFCAC4D0),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF313033),
  onInverseSurface: Color(0xFFF4EFF4),
  inversePrimary: Color(0xFFD0BCFF),
)
```

### Using Theme Colors

```dart
// Access colors from theme
Container(
  color: Theme.of(context).colorScheme.primary,
  child: Text(
    'Hello',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onPrimary,
    ),
  ),
)

// Surface colors
Card(
  color: Theme.of(context).colorScheme.surface,
  child: Text(
    'Card content',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  ),
)
```

## Typography

### Material 3 Type Scale

```dart
ThemeData(
  useMaterial3: true,
  textTheme: TextTheme(
    displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
    displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
    displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
    headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w400),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w400),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  ),
)

// Using text styles
Text(
  'Headline',
  style: Theme.of(context).textTheme.headlineLarge,
)

Text(
  'Body text',
  style: Theme.of(context).textTheme.bodyMedium,
)
```

## Components

### Buttons

#### Elevated Button (High Emphasis)

```dart
ElevatedButton(
  onPressed: () {},
  child: Text('Elevated'),
)

ElevatedButton.icon(
  onPressed: () {},
  icon: Icon(Icons.add),
  label: Text('Add Item'),
)
```

#### Filled Button (Highest Emphasis)

```dart
FilledButton(
  onPressed: () {},
  child: Text('Filled'),
)

FilledButton.tonal(
  onPressed: () {},
  child: Text('Filled Tonal'),
)
```

#### Outlined Button (Medium Emphasis)

```dart
OutlinedButton(
  onPressed: () {},
  child: Text('Outlined'),
)
```

#### Text Button (Low Emphasis)

```dart
TextButton(
  onPressed: () {},
  child: Text('Text'),
)
```

### Cards

```dart
// Elevated Card (default)
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Card Title', style: Theme.of(context).textTheme.titleMedium),
        SizedBox(height: 8),
        Text('Card content', style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  ),
)

// Filled Card
Card(
  elevation: 0,
  color: Theme.of(context).colorScheme.surfaceVariant,
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Filled Card'),
  ),
)

// Outlined Card
Card(
  elevation: 0,
  shape: RoundedRectangleBorder(
    side: BorderSide(
      color: Theme.of(context).colorScheme.outline,
    ),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Outlined Card'),
  ),
)
```

### Floating Action Button (FAB)

```dart
// Regular FAB
FloatingActionButton(
  onPressed: () {},
  child: Icon(Icons.add),
)

// Extended FAB
FloatingActionButton.extended(
  onPressed: () {},
  icon: Icon(Icons.add),
  label: Text('Create'),
)

// Small FAB
FloatingActionButton.small(
  onPressed: () {},
  child: Icon(Icons.add),
)

// Large FAB
FloatingActionButton.large(
  onPressed: () {},
  child: Icon(Icons.add),
)
```

### Navigation Bar

```dart
NavigationBar(
  selectedIndex: selectedIndex,
  onDestinationSelected: (index) {
    setState(() => selectedIndex = index);
  },
  destinations: [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: 'Search',
    ),
    NavigationDestination(
      icon: Badge(
        label: Text('3'),
        child: Icon(Icons.notifications_outlined),
      ),
      selectedIcon: Icon(Icons.notifications),
      label: 'Notifications',
    ),
  ],
)
```

### Navigation Rail

```dart
NavigationRail(
  selectedIndex: selectedIndex,
  onDestinationSelected: (index) {
    setState(() => selectedIndex = index);
  },
  labelType: NavigationRailLabelType.all,
  destinations: [
    NavigationRailDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.search_outlined),
      selectedIcon: Icon(Icons.search),
      label: Text('Search'),
    ),
  ],
)
```

### Navigation Drawer

```dart
NavigationDrawer(
  selectedIndex: selectedIndex,
  onDestinationSelected: (index) {
    setState(() => selectedIndex = index);
  },
  children: [
    DrawerHeader(
      child: Text('App Name'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: Text('Home'),
    ),
    NavigationDrawerDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ],
)
```

### Chips

```dart
// Assist Chip
AssistChip(
  label: Text('Assist'),
  onPressed: () {},
)

// Filter Chip
FilterChip(
  label: Text('Filter'),
  selected: isSelected,
  onSelected: (bool selected) {
    setState(() => isSelected = selected);
  },
)

// Input Chip
InputChip(
  label: Text('Input'),
  onDeleted: () {},
  onPressed: () {},
)

// Suggestion Chip
SuggestionChip(
  label: Text('Suggestion'),
  onPressed: () {},
)
```

### Badges

```dart
Badge(
  label: Text('3'),
  child: Icon(Icons.notifications),
)

Badge(
  child: Icon(Icons.mail),
)

// Positioned badge
Badge(
  label: Text('99+'),
  alignment: Alignment.topRight,
  child: IconButton(
    icon: Icon(Icons.shopping_cart),
    onPressed: () {},
  ),
)
```

### Bottom Sheets

```dart
// Modal Bottom Sheet
showModalBottomSheet(
  context: context,
  builder: (context) => Container(
    padding: EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.share),
          title: Text('Share'),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.link),
          title: Text('Copy link'),
          onTap: () {},
        ),
      ],
    ),
  ),
)

// Persistent Bottom Sheet
showBottomSheet(
  context: context,
  builder: (context) => Container(
    padding: EdgeInsets.all(16),
    child: Text('Persistent bottom sheet'),
  ),
)
```

### Dialogs

```dart
// Alert Dialog
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    icon: Icon(Icons.info),
    title: Text('Dialog Title'),
    content: Text('Dialog content goes here'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Confirm'),
      ),
    ],
  ),
)

// Full-screen Dialog
showDialog(
  context: context,
  builder: (context) => Dialog.fullscreen(
    child: Scaffold(
      appBar: AppBar(
        title: Text('Full-screen Dialog'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(child: Text('Content')),
    ),
  ),
)
```

### Snackbars

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Snackbar message'),
    action: SnackBarAction(
      label: 'Action',
      onPressed: () {},
    ),
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: 3),
  ),
)
```

### Progress Indicators

```dart
// Circular
CircularProgressIndicator()

// Linear
LinearProgressIndicator()

// With value
LinearProgressIndicator(value: 0.7)

// Custom colors
CircularProgressIndicator(
  valueColor: AlwaysStoppedAnimation<Color>(
    Theme.of(context).colorScheme.secondary,
  ),
)
```

### Text Fields

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    hintText: 'Hint text',
    helperText: 'Helper text',
    prefixIcon: Icon(Icons.search),
    suffixIcon: Icon(Icons.clear),
    border: OutlineInputBorder(),
  ),
)

// Filled text field
TextField(
  decoration: InputDecoration(
    labelText: 'Label',
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
  ),
)
```

### Switches, Checkboxes, Radio Buttons

```dart
// Switch
Switch(
  value: isEnabled,
  onChanged: (value) {
    setState(() => isEnabled = value);
  },
)

// Checkbox
Checkbox(
  value: isChecked,
  onChanged: (value) {
    setState(() => isChecked = value!);
  },
)

// Radio
Radio<int>(
  value: 1,
  groupValue: selectedValue,
  onChanged: (value) {
    setState(() => selectedValue = value!);
  },
)
```

### Sliders

```dart
Slider(
  value: sliderValue,
  min: 0,
  max: 100,
  divisions: 10,
  label: sliderValue.round().toString(),
  onChanged: (value) {
    setState(() => sliderValue = value);
  },
)

// Range Slider
RangeSlider(
  values: rangeValues,
  min: 0,
  max: 100,
  divisions: 10,
  labels: RangeLabels(
    rangeValues.start.round().toString(),
    rangeValues.end.round().toString(),
  ),
  onChanged: (values) {
    setState(() => rangeValues = values);
  },
)
```

## Elevation and Shadows

Material 3 uses tonal elevation instead of shadow elevation:

```dart
Card(
  elevation: 1, // Surface tint applied based on elevation
  surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Text('Card with tonal elevation'),
  ),
)

// Disable surface tint
Card(
  elevation: 4,
  surfaceTintColor: Colors.transparent, // Traditional shadow
  child: Text('Card with shadow elevation'),
)
```

## Shape System

```dart
ThemeData(
  useMaterial3: true,
  cardTheme: CardTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
)
```

## Motion and Animations

### Standard Curves

```dart
// Emphasized curves
Curves.easeInOutCubicEmphasized // For important transitions
Curves.easeOutCubic // For entering elements
Curves.easeInCubic // For exiting elements

// Example
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOutCubicEmphasized,
  width: isExpanded ? 200 : 100,
  child: child,
)
```

## Theming Components

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),

  // Button themes
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: Size(88, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),

  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: Size(88, 48),
    ),
  ),

  // Card theme
  cardTheme: CardTheme(
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    clipBehavior: Clip.antiAlias,
  ),

  // AppBar theme
  appBarTheme: AppBarTheme(
    centerTitle: false,
    elevation: 0,
  ),

  // NavigationBar theme
  navigationBarTheme: NavigationBarThemeData(
    height: 80,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
)
```

## Dark Theme

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system, // or ThemeMode.light / ThemeMode.dark
      home: HomeScreen(),
    );
  }
}
```

## Dynamic Color (Android 12+)

```yaml
dependencies:
  dynamic_color: ^1.7.0
```

```dart
import 'package:dynamic_color/dynamic_color.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // Use dynamic colors from system
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Fallback colors
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
          );
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightColorScheme,
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkColorScheme,
          ),
          themeMode: ThemeMode.system,
          home: HomeScreen(),
        );
      },
    );
  }
}
```

## Migration from Material 2

### Key Changes

1. **Enable Material 3**: Set `useMaterial3: true`
2. **Update colors**: Use `ColorScheme.fromSeed()`
3. **Review elevation**: Tonal elevation replaces shadow elevation
4. **Update shapes**: Default corner radius changed
5. **Check component sizes**: Some components have different default sizes
6. **Update text styles**: Use new type scale
7. **Review button styles**: New button variants (FilledButton, FilledButton.tonal)

### Gradual Migration

```dart
// Run both themes side by side
MaterialApp(
  theme: ThemeData(
    useMaterial3: false, // Material 2
  ),
  home: Material2Screen(),
)

// vs

MaterialApp(
  theme: ThemeData(
    useMaterial3: true, // Material 3
  ),
  home: Material3Screen(),
)
```

## Best Practices

1. **Use semantic colors** - primary, secondary, tertiary, not hardcoded colors
2. **Leverage ColorScheme.fromSeed()** - Generates harmonious color palette
3. **Use appropriate button types** - FilledButton for primary actions, TextButton for tertiary
4. **Apply consistent shapes** - Use theme shape system
5. **Test both light and dark themes** - Ensure proper contrast
6. **Use Material 3 components** - NavigationBar instead of BottomNavigationBar
7. **Consider dynamic color** - For Android 12+ devices
8. **Follow type scale** - Use theme text styles
9. **Test accessibility** - Ensure sufficient color contrast
10. **Use proper elevation** - Understand tonal vs shadow elevation

## Resources

- [Material Design 3 Documentation](https://m3.material.io/)
- [Flutter Material 3 Guide](https://docs.flutter.dev/ui/design/material)
- [Color Palette Generator](https://m3.material.io/theme-builder)
