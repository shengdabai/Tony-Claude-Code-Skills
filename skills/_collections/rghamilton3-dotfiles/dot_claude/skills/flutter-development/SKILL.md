---
name: flutter-development
description: Comprehensive Flutter development guidance covering widget composition (including ADHD-friendly UI patterns), state management (Bloc and Riverpod), navigation with go_router, platform-specific code for iOS/Android/Web/Desktop, Material Design 3 implementation, and performance optimization. Use when building Flutter applications, implementing state management, creating cross-platform features, optimizing performance, or designing accessible user interfaces.
---

# Flutter Development

## Overview

Provide expert guidance on Flutter application development with focus on modern best practices, accessible UI design, efficient state management, and cross-platform development. Leverage comprehensive reference documentation for detailed patterns and techniques.

## When to Use This Skill

Use this skill when:
- Building or maintaining Flutter applications
- Implementing state management with Bloc or Riverpod
- Creating ADHD-friendly or accessible user interfaces
- Setting up navigation and routing (especially with go_router)
- Writing platform-specific code for iOS, Android, Web, or Desktop
- Implementing Material Design 3 components and theming
- Optimizing Flutter app performance
- Designing reusable widget compositions
- Debugging performance issues or memory leaks
- Migrating from Material 2 to Material 3

## Core Capabilities

### 1. ADHD-Friendly UI Design

Create user interfaces optimized for users with ADHD, following principles that reduce cognitive load and improve focus.

**Key considerations:**
- Minimize visual clutter and distractions
- Establish clear visual hierarchies
- Provide immediate, obvious feedback
- Use card-based layouts for information chunking
- Implement focus management and progressive disclosure
- Apply consistent color coding for states

**Reference:** Load `references/adhd_friendly_ui.md` for comprehensive patterns including:
- Simplified navigation patterns
- Distraction-free mode implementations
- Progress visualization techniques
- Typography and spacing guidelines
- Form design best practices

**Example request:** "Design a task management screen with ADHD-friendly UI patterns"

### 2. State Management

Implement robust state management using Bloc (event-driven) or Riverpod (reactive) patterns.

**Choose Bloc when:**
- Building large-scale applications with complex business logic
- Need clear separation between UI and business logic
- Want predictable state transitions with events
- Prefer event-driven architecture

**Choose Riverpod when:**
- Need simpler, more flexible state management
- Want compile-time safety
- Building small to medium applications
- Prefer declarative, reactive patterns

**Reference:** Load `references/state_management.md` for:
- Complete Bloc implementation patterns with sealed classes
- Riverpod provider types and advanced patterns
- Testing strategies for both approaches
- Performance optimization techniques
- Migration guides between state management solutions

**Example requests:**
- "Implement authentication flow using Bloc with loading states"
- "Create a Riverpod provider for user profile data with caching"
- "Set up state management for a shopping cart feature"

### 3. Navigation and Routing

Implement modern, declarative navigation using go_router with support for deep linking, route guards, and nested navigation.

**Key capabilities:**
- Declarative routing with go_router
- Nested routes and shell routes
- Route guards and redirects
- Deep linking for iOS, Android, and Web
- Integration with state management (Bloc/Riverpod)
- Platform-specific navigation patterns

**Reference:** Load `references/navigation_routing.md` for:
- go_router setup and configuration
- Shell routes for persistent UI (bottom nav, drawer)
- Deep linking implementation
- Route guards and authentication flows
- Custom page transitions
- Multi-platform navigation patterns

**Example requests:**
- "Set up go_router with authentication guards"
- "Implement bottom navigation that persists across routes"
- "Add deep linking support for product details pages"

### 4. Platform-Specific Code

Handle platform differences across iOS, Android, Web, Desktop (Windows, macOS, Linux), and embedded platforms.

**Key capabilities:**
- Platform detection and conditional code
- Platform channels (Method and Event channels)
- Adaptive widgets (Material vs Cupertino)
- Platform-specific permissions
- Conditional imports
- Responsive design for different form factors

**Reference:** Load `references/platform_specific.md` for:
- Platform detection patterns
- Platform channel implementation (iOS Swift, Android Kotlin)
- Adaptive widget patterns
- Permission handling per platform
- Desktop-specific features (window management, system tray)
- Web-specific features (URL strategy, JavaScript interop)

**Example requests:**
- "Implement platform-specific camera functionality"
- "Create adaptive UI that uses Cupertino on iOS and Material on Android"
- "Add desktop window management features"
- "Implement platform channels to access native APIs"

### 5. Material Design 3

Implement Material Design 3 (Material You) with dynamic colors, updated components, and modern theming.

**Key capabilities:**
- Material 3 color system with dynamic colors
- Updated component library
- Typography and shape system
- Tonal elevation
- Dark theme support
- Migration from Material 2

**Reference:** Load `references/material_design_3.md` for:
- Complete Material 3 setup and configuration
- Color scheme generation from seed colors
- All Material 3 components with examples
- Dynamic color support (Android 12+)
- Component theming
- Migration guide from Material 2

**Example requests:**
- "Set up Material 3 theming with dynamic colors"
- "Implement NavigationBar with badges"
- "Create a dark theme variant"
- "Migrate this Material 2 app to Material 3"

### 6. Performance Optimization

Optimize Flutter apps for smooth 60fps rendering, minimal memory usage, and fast load times.

**Key areas:**
- Widget optimization (const constructors, RepaintBoundary)
- List performance (ListView.builder, itemExtent)
- Image optimization (caching, sizing)
- Build method optimization
- Memory management (resource disposal)
- Async operations (compute, debouncing)
- Animation performance
- Build size optimization

**Reference:** Load `references/performance_optimization.md` for:
- Profiling with Flutter DevTools
- Widget optimization techniques
- Image caching strategies
- Memory leak prevention
- Async operation best practices
- JSON parsing in isolates
- Testing performance

**Example requests:**
- "Optimize this ListView with many images"
- "Profile and fix performance issues in this animation"
- "Reduce app size and improve load time"
- "Fix memory leaks in this widget"

### 7. Widget Composition

Design reusable, maintainable widget hierarchies following Flutter best practices.

**Key principles:**
- Single responsibility per widget
- Composition over inheritance
- Proper use of const constructors
- Clear data flow (data down, callbacks up)
- Separation of concerns
- Testability

**Reference:** Load `references/widget_composition.md` for:
- Core composition principles
- Reusable widget patterns
- Layout patterns (responsive, spacing utilities)
- State management patterns
- Error handling patterns
- Testing patterns
- Anti-patterns to avoid

**Example requests:**
- "Refactor this large widget into smaller, reusable components"
- "Create a reusable product card component"
- "Design a responsive layout that works on mobile and desktop"

## Workflow Guidelines

### Initial Assessment

When receiving a Flutter development request:

1. **Identify the primary concern** (UI, state, navigation, platform-specific, theming, performance)
2. **Determine which reference(s) to load** based on the request
3. **Consider cross-cutting concerns** (accessibility, performance, platform differences)
4. **Ask clarifying questions** if requirements are ambiguous

### Reference Loading Strategy

Load reference documentation as needed rather than all at once:

- **Single focus requests**: Load one reference file
- **Complex requests**: Load multiple references progressively
- **Performance concerns**: Always consider loading `performance_optimization.md`
- **UI requests**: Consider if `adhd_friendly_ui.md` applies for better accessibility

### Implementation Approach

Follow these principles when implementing solutions:

1. **Start with current Flutter best practices** (Flutter 3.x, Dart 3.x)
2. **Use Material 3** unless Material 2 is explicitly required
3. **Apply const constructors** wherever possible
4. **Consider performance implications** from the start
5. **Think multi-platform** unless single platform specified
6. **Prioritize accessibility** and inclusive design
7. **Write testable code** with clear separation of concerns
8. **Follow widget composition best practices** (small, focused widgets)

### Code Quality Standards

Ensure all generated code:
- Uses modern Flutter/Dart syntax (null safety, pattern matching, records)
- Follows official Dart style guide
- Includes necessary imports
- Uses meaningful variable and widget names
- Has appropriate const constructors
- Disposes resources properly (controllers, streams, listeners)
- Handles errors gracefully
- Is testable

## Examples

### Example 1: ADHD-Friendly Task Manager

**Request:** "Build a task management screen with ADHD-friendly UI"

**Approach:**
1. Load `references/adhd_friendly_ui.md`
2. Implement card-based layout for discrete information chunks
3. Use clear visual hierarchy with Material 3 typography
4. Provide immediate feedback for all actions
5. Include progress indicators for multi-step tasks
6. Apply simplified navigation patterns
7. Consider focus mode for distraction-free work

### Example 2: Authentication with Bloc

**Request:** "Implement authentication flow with Bloc"

**Approach:**
1. Load `references/state_management.md`
2. Create sealed classes for auth states (Initial, Loading, Authenticated, Unauthenticated, Error)
3. Define auth events (Login, Logout, CheckAuth)
4. Implement AuthBloc with proper event handlers
5. Use BlocListener for navigation side effects
6. Use BlocBuilder for UI rendering
7. Add proper error handling

### Example 3: Multi-Platform App

**Request:** "Create an app that works on iOS, Android, and Web"

**Approach:**
1. Load `references/platform_specific.md` and `references/navigation_routing.md`
2. Set up go_router with web-friendly URLs
3. Implement adaptive widgets for iOS/Android differences
4. Handle platform-specific features (permissions, deep linking)
5. Create responsive layouts for different screen sizes
6. Test on all target platforms

### Example 4: Performance Optimization

**Request:** "This list is laggy with many images"

**Approach:**
1. Load `references/performance_optimization.md`
2. Profile with Flutter DevTools to identify bottlenecks
3. Switch to ListView.builder if not already using it
4. Add itemExtent for fixed-height items
5. Implement image caching with cached_network_image
6. Use cacheWidth/cacheHeight to decode images at appropriate size
7. Add RepaintBoundary if needed
8. Extract static widgets to prevent unnecessary rebuilds

## Additional Notes

- **Stay Current**: Follow Flutter's official blog and release notes for latest features
- **Test Thoroughly**: Always test on target platforms (physical devices when possible)
- **Consider Accessibility**: Use Semantics widgets and test with screen readers
- **Document Decisions**: Explain why specific patterns or approaches are chosen
- **Performance First**: Consider performance implications from the start, not as an afterthought
- **Progressive Enhancement**: Start with core functionality, add enhancements progressively

## Resources

This skill includes comprehensive reference documentation in the `references/` directory:

- **adhd_friendly_ui.md**: ADHD-friendly UI design patterns and principles
- **state_management.md**: Bloc and Riverpod implementation patterns
- **navigation_routing.md**: go_router and navigation best practices
- **platform_specific.md**: Cross-platform development techniques
- **material_design_3.md**: Material Design 3 implementation guide
- **performance_optimization.md**: Performance profiling and optimization
- **widget_composition.md**: Widget composition patterns and best practices

Load these references as needed to provide detailed, accurate guidance.
