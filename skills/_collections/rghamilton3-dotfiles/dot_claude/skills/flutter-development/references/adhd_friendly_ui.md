# ADHD-Friendly UI Design Patterns

## Core Principles

ADHD-friendly UI design focuses on reducing cognitive load, minimizing distractions, and providing clear visual hierarchies to help users stay focused and accomplish tasks efficiently.

### Key Principles
1. **Reduce Visual Clutter** - Minimize unnecessary visual elements
2. **Clear Visual Hierarchy** - Make important elements stand out
3. **Predictable Navigation** - Keep navigation consistent and intuitive
4. **Immediate Feedback** - Provide instant visual/haptic feedback for actions
5. **Chunking Information** - Break complex information into digestible pieces
6. **Focus Management** - Guide user attention deliberately
7. **Progress Indicators** - Show progress clearly for multi-step tasks

## Design Patterns

### 1. Simplified Navigation

Avoid deep navigation hierarchies. Prefer flat, visible navigation structures.

```dart
// Good: Bottom navigation with clear icons and labels
BottomNavigationBar(
  type: BottomNavigationBarType.fixed,
  selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
  items: [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list_outlined),
      activeIcon: Icon(Icons.list),
      label: 'Tasks',
    ),
  ],
)
```

### 2. Card-Based Layouts

Use cards to chunk information into scannable, discrete units.

```dart
Card(
  elevation: 2,
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Single, focused piece of information
        Text(
          'Task Title',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 8),
        Text('Due: Today', style: TextStyle(color: Colors.orange)),
      ],
    ),
  ),
)
```

### 3. Clear Visual Feedback

Provide immediate, obvious feedback for all user actions.

```dart
// Use haptic feedback
InkWell(
  onTap: () {
    HapticFeedback.lightImpact();
    // Action
  },
  child: Container(
    decoration: BoxDecoration(
      color: Colors.blue,
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    child: Text('Complete Task'),
  ),
)
```

### 4. Progressive Disclosure

Show only what's needed at each step. Hide complexity until it's relevant.

```dart
ExpansionTile(
  title: Text('Advanced Options'),
  children: [
    // Complex options hidden by default
    ListTile(title: Text('Option 1')),
    ListTile(title: Text('Option 2')),
  ],
)
```

### 5. Color-Coded States

Use consistent color coding to indicate states at a glance.

```dart
enum TaskPriority { low, medium, high }

Color getPriorityColor(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return Colors.green;
    case TaskPriority.medium:
      return Colors.orange;
    case TaskPriority.high:
      return Colors.red;
  }
}
```

### 6. Reduce Animation Overload

Use subtle, purposeful animations. Avoid excessive or distracting motion.

```dart
// Good: Subtle, short animation
AnimatedOpacity(
  opacity: isVisible ? 1.0 : 0.0,
  duration: Duration(milliseconds: 150),
  child: child,
)

// Avoid: Long, bouncy, distracting animations
// Bad: duration: Duration(milliseconds: 1000)
```

### 7. Focus Indicators

Clearly show which element has focus, especially for keyboard navigation.

```dart
Container(
  decoration: BoxDecoration(
    border: Border.all(
      color: hasFocus ? Colors.blue : Colors.transparent,
      width: 3,
    ),
    borderRadius: BorderRadius.circular(8),
  ),
  child: child,
)
```

### 8. Clear Call-to-Action Buttons

Make primary actions obvious and easy to tap.

```dart
// Primary action - large, high contrast
ElevatedButton(
  onPressed: onComplete,
  style: ElevatedButton.styleFrom(
    minimumSize: Size(double.infinity, 56), // Easy to tap
    backgroundColor: Colors.blue,
    foregroundColor: Colors.white,
  ),
  child: Text(
    'Complete Task',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  ),
)
```

### 9. Distraction-Free Mode

Provide options to hide non-essential UI elements when focusing.

```dart
class FocusMode extends StatelessWidget {
  final bool isEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 200),
      child: isEnabled
          ? Container(
              color: Colors.black,
              child: Center(child: child), // Only essential content
            )
          : Scaffold(
              appBar: AppBar(...), // Full UI
              body: child,
            ),
    );
  }
}
```

### 10. Progress Visualization

Show progress clearly for multi-step tasks to reduce anxiety and provide motivation.

```dart
LinearProgressIndicator(
  value: completedSteps / totalSteps,
  backgroundColor: Colors.grey[200],
  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
)

// With text indicator
Text('Step ${completedSteps + 1} of $totalSteps')
```

## Typography

### Font Selection
- Use clear, legible sans-serif fonts (e.g., Roboto, SF Pro)
- Avoid decorative or script fonts
- Ensure sufficient font weight contrast

### Size and Spacing
```dart
TextTheme(
  // Larger than default for readability
  bodyLarge: TextStyle(fontSize: 18, height: 1.5),
  bodyMedium: TextStyle(fontSize: 16, height: 1.5),

  // Clear headings
  headlineMedium: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.5,
  ),
)
```

## Layout Guidelines

### Whitespace
Use generous whitespace to reduce visual clutter:

```dart
Padding(
  padding: EdgeInsets.all(24), // Generous padding
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Item 1'),
      SizedBox(height: 16), // Clear separation
      Text('Item 2'),
    ],
  ),
)
```

### Limited Choices
Avoid overwhelming users with too many options at once:

```dart
// Good: 3-5 visible options
// Bad: Showing 20+ options simultaneously

// Use pagination or progressive disclosure for longer lists
```

## Notifications and Interruptions

### Gentle Notifications
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Task completed!'),
    duration: Duration(seconds: 2), // Brief, not intrusive
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.green,
  ),
)
```

### Avoid Modal Interruptions
Prefer inline notifications over modal dialogs when possible:

```dart
// Good: Inline notification
Container(
  padding: EdgeInsets.all(16),
  color: Colors.blue[50],
  child: Row(
    children: [
      Icon(Icons.info, color: Colors.blue),
      SizedBox(width: 8),
      Expanded(child: Text('New message')),
    ],
  ),
)

// Use dialogs sparingly, only for critical decisions
```

## Form Design

### Single-Column Layouts
Keep forms simple with one input per row:

```dart
Column(
  children: [
    TextField(
      decoration: InputDecoration(
        labelText: 'Task Name',
        border: OutlineInputBorder(),
      ),
    ),
    SizedBox(height: 16),
    TextField(
      decoration: InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
      ),
    ),
  ],
)
```

### Inline Validation
Provide immediate feedback on form inputs:

```dart
TextField(
  onChanged: (value) {
    // Validate immediately and show inline errors
  },
  decoration: InputDecoration(
    labelText: 'Email',
    errorText: isInvalid ? 'Invalid email' : null,
    suffixIcon: isValid ? Icon(Icons.check, color: Colors.green) : null,
  ),
)
```

## Accessibility Integration

ADHD-friendly design naturally aligns with accessibility best practices:

```dart
Semantics(
  label: 'Complete task button',
  hint: 'Double tap to mark this task as complete',
  button: true,
  child: ElevatedButton(...),
)
```

## Testing Guidelines

When testing ADHD-friendly UI:

1. **Cognitive Load Test**: Can a user understand what to do within 3 seconds?
2. **Distraction Count**: Count interactive elements per screen (aim for <7)
3. **Path Clarity**: Is the primary action obvious?
4. **Feedback Speed**: Do actions provide feedback within 100ms?
5. **Navigation Depth**: Can users reach any feature within 3 taps?

## Common Anti-Patterns to Avoid

1. **Auto-playing videos/animations** - Highly distracting
2. **Notification badges without context** - Creates anxiety
3. **Hidden navigation** - Requires memory recall
4. **Inconsistent UI patterns** - Increases cognitive load
5. **Too many simultaneous actions** - Analysis paralysis
6. **Unclear button hierarchies** - Decision fatigue
7. **Tiny tap targets** - Requires precision and focus
