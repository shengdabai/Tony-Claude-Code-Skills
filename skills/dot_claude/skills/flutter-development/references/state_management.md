# State Management: Bloc and Riverpod

## Overview

This guide covers two popular state management solutions in Flutter: Bloc (Business Logic Component) and Riverpod (Provider reimagined).

## When to Use Which

### Use Bloc When:
- Building large-scale applications with complex business logic
- Need clear separation between UI and business logic
- Want predictable state transitions with events
- Need comprehensive testing capabilities
- Team prefers event-driven architecture

### Use Riverpod When:
- Need simpler, more flexible state management
- Want compile-time safety and better testability than Provider
- Building smaller to medium applications
- Prefer declarative, reactive patterns
- Need granular rebuilds and optimization

## Bloc Pattern

### Core Concepts

1. **Events**: User actions or system events
2. **States**: Representations of application state
3. **Bloc**: Business logic that maps events to states

### Basic Setup

```yaml
# pubspec.yaml
dependencies:
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
```

### Simple Counter Example

```dart
// counter_event.dart
abstract class CounterEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class IncrementCounter extends CounterEvent {}
class DecrementCounter extends CounterEvent {}

// counter_state.dart
class CounterState extends Equatable {
  final int count;

  const CounterState(this.count);

  @override
  List<Object> get props => [count];
}

// counter_bloc.dart
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(CounterState(0)) {
    on<IncrementCounter>(_onIncrement);
    on<DecrementCounter>(_onDecrement);
  }

  void _onIncrement(IncrementCounter event, Emitter<CounterState> emit) {
    emit(CounterState(state.count + 1));
  }

  void _onDecrement(DecrementCounter event, Emitter<CounterState> emit) {
    emit(CounterState(state.count - 1));
  }
}

// UI usage
BlocProvider(
  create: (context) => CounterBloc(),
  child: BlocBuilder<CounterBloc, CounterState>(
    builder: (context, state) {
      return Column(
        children: [
          Text('Count: ${state.count}'),
          ElevatedButton(
            onPressed: () => context.read<CounterBloc>().add(IncrementCounter()),
            child: Text('Increment'),
          ),
        ],
      );
    },
  ),
)
```

### Advanced Bloc Patterns

#### Loading States with Sealed Classes

```dart
sealed class DataState extends Equatable {
  @override
  List<Object> get props => [];
}

class DataInitial extends DataState {}

class DataLoading extends DataState {}

class DataLoaded extends DataState {
  final List<Item> items;
  DataLoaded(this.items);

  @override
  List<Object> get props => [items];
}

class DataError extends DataState {
  final String message;
  DataError(this.message);

  @override
  List<Object> get props => [message];
}

// Bloc implementation
class DataBloc extends Bloc<DataEvent, DataState> {
  final Repository repository;

  DataBloc(this.repository) : super(DataInitial()) {
    on<LoadData>(_onLoadData);
  }

  Future<void> _onLoadData(LoadData event, Emitter<DataState> emit) async {
    emit(DataLoading());
    try {
      final items = await repository.fetchItems();
      emit(DataLoaded(items));
    } catch (e) {
      emit(DataError(e.toString()));
    }
  }
}

// UI with pattern matching
BlocBuilder<DataBloc, DataState>(
  builder: (context, state) {
    return switch (state) {
      DataInitial() => Center(child: Text('Press button to load')),
      DataLoading() => Center(child: CircularProgressIndicator()),
      DataLoaded(:final items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => ListTile(title: Text(items[index].name)),
        ),
      DataError(:final message) => Center(child: Text('Error: $message')),
    };
  },
)
```

#### Bloc Transformers (Debouncing/Throttling)

```dart
import 'package:stream_transform/stream_transform.dart';

EventTransformer<T> debounce<T>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchInitial()) {
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounce(Duration(milliseconds: 300)),
    );
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(SearchLoading());
    try {
      final results = await _searchRepository.search(event.query);
      emit(SearchLoaded(results));
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }
}
```

#### BlocListener for Side Effects

```dart
BlocListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    } else if (state is AuthAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  },
  child: BlocBuilder<AuthBloc, AuthState>(
    builder: (context, state) {
      // UI rendering
    },
  ),
)
```

#### MultiBlocProvider

```dart
MultiBlocProvider(
  providers: [
    BlocProvider<AuthBloc>(create: (context) => AuthBloc()),
    BlocProvider<UserBloc>(create: (context) => UserBloc()),
    BlocProvider<SettingsBloc>(create: (context) => SettingsBloc()),
  ],
  child: MyApp(),
)
```

### Testing Blocs

```dart
void main() {
  group('CounterBloc', () {
    late CounterBloc counterBloc;

    setUp(() {
      counterBloc = CounterBloc();
    });

    tearDown(() {
      counterBloc.close();
    });

    test('initial state is CounterState(0)', () {
      expect(counterBloc.state, CounterState(0));
    });

    blocTest<CounterBloc, CounterState>(
      'emits [CounterState(1)] when IncrementCounter is added',
      build: () => counterBloc,
      act: (bloc) => bloc.add(IncrementCounter()),
      expect: () => [CounterState(1)],
    );
  });
}
```

## Riverpod Pattern

### Core Concepts

1. **Providers**: Objects that encapsulate state and logic
2. **Consumer**: Widgets that listen to providers
3. **Ref**: Object to interact with providers

### Basic Setup

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.4.9
```

### Simple Counter Example

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define a provider
final counterProvider = StateProvider<int>((ref) => 0);

// Wrap app with ProviderScope
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

// Use in widget with ConsumerWidget
class CounterScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);

    return Column(
      children: [
        Text('Count: $count'),
        ElevatedButton(
          onPressed: () => ref.read(counterProvider.notifier).state++,
          child: Text('Increment'),
        ),
      ],
    );
  }
}
```

### Provider Types

#### 1. Provider (Immutable)

```dart
final configProvider = Provider<Config>((ref) {
  return Config(apiKey: 'abc123', timeout: 30);
});
```

#### 2. StateProvider (Simple Mutable State)

```dart
final selectedIndexProvider = StateProvider<int>((ref) => 0);

// Usage
ref.read(selectedIndexProvider.notifier).state = 2;
```

#### 3. StateNotifierProvider (Complex State)

```dart
class TodosNotifier extends StateNotifier<List<Todo>> {
  TodosNotifier() : super([]);

  void addTodo(String title) {
    state = [...state, Todo(id: state.length, title: title)];
  }

  void removeTodo(int id) {
    state = state.where((todo) => todo.id != id).toList();
  }

  void toggleTodo(int id) {
    state = [
      for (final todo in state)
        if (todo.id == id)
          todo.copyWith(completed: !todo.completed)
        else
          todo,
    ];
  }
}

final todosProvider = StateNotifierProvider<TodosNotifier, List<Todo>>((ref) {
  return TodosNotifier();
});
```

#### 4. FutureProvider (Async Data)

```dart
final userProvider = FutureProvider<User>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.fetchUser();
});

// Usage with AsyncValue
class UserScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
      data: (user) => Text('Hello, ${user.name}'),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

#### 5. StreamProvider (Real-time Data)

```dart
final messagesProvider = StreamProvider<List<Message>>((ref) {
  final repository = ref.watch(messageRepositoryProvider);
  return repository.watchMessages();
});
```

### Advanced Riverpod Patterns

#### Computed/Derived State

```dart
final completedTodosProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todosProvider);
  return todos.where((todo) => todo.completed).toList();
});

final uncompletedTodosCountProvider = Provider<int>((ref) {
  final todos = ref.watch(todosProvider);
  return todos.where((todo) => !todo.completed).length;
});
```

#### Family Modifier (Parameterized Providers)

```dart
final todoProvider = Provider.family<Todo, int>((ref, id) {
  final todos = ref.watch(todosProvider);
  return todos.firstWhere((todo) => todo.id == id);
});

// Usage
ref.watch(todoProvider(5)); // Get todo with id 5
```

#### AutoDispose Modifier

```dart
final searchProvider = StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});
// Automatically disposed when no longer used
```

#### Combining Providers

```dart
final filteredTodosProvider = Provider<List<Todo>>((ref) {
  final todos = ref.watch(todosProvider);
  final filter = ref.watch(filterProvider);

  return switch (filter) {
    Filter.all => todos,
    Filter.completed => todos.where((todo) => todo.completed).toList(),
    Filter.uncompleted => todos.where((todo) => !todo.completed).toList(),
  };
});
```

#### Invalidating/Refreshing Providers

```dart
// Invalidate to force refresh
ref.invalidate(userProvider);

// Refresh (for FutureProvider/StreamProvider)
ref.refresh(userProvider);
```

### Testing Riverpod

```dart
void main() {
  test('counterProvider initial value is 0', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(counterProvider), 0);
  });

  test('counterProvider increments', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(counterProvider.notifier).state++;
    expect(container.read(counterProvider), 1);
  });

  test('can override providers', () {
    final container = ProviderContainer(
      overrides: [
        counterProvider.overrideWith((ref) => 100),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(counterProvider), 100);
  });
}
```

## Comparing Bloc vs Riverpod

| Aspect | Bloc | Riverpod |
|--------|------|----------|
| **Boilerplate** | More verbose | Less boilerplate |
| **Learning Curve** | Steeper | Gentler |
| **Event-Driven** | Yes | No |
| **Compile Safety** | Good | Excellent |
| **Testing** | Excellent | Excellent |
| **Debugging** | BlocObserver | ProviderObserver |
| **Time Travel** | Yes (with replay_bloc) | Limited |
| **Best For** | Large apps, complex flows | Small-medium apps, flexibility |

## Hybrid Approach

Use both in the same app based on use case:

```dart
// Use Bloc for complex authentication flow
final authBlocProvider = Provider<AuthBloc>((ref) => AuthBloc());

// Use Riverpod for simple UI state
final selectedTabProvider = StateProvider<int>((ref) => 0);
```

## Performance Optimization

### Bloc Optimization

```dart
// Use BlocSelector for granular rebuilds
BlocSelector<UserBloc, UserState, String>(
  selector: (state) => state.name,
  builder: (context, name) {
    // Only rebuilds when name changes
    return Text(name);
  },
)
```

### Riverpod Optimization

```dart
// Use select to watch specific fields
final userName = ref.watch(userProvider.select((user) => user.name));

// Or use Provider with computed state
final userNameProvider = Provider<String>((ref) {
  final user = ref.watch(userProvider);
  return user.name;
});
```

## Best Practices

### Bloc Best Practices
1. Keep Blocs focused on single responsibility
2. Use sealed classes for state variants
3. Always use Equatable for states and events
4. Handle all error cases
5. Use BlocListener for side effects, BlocBuilder for UI
6. Test business logic independently

### Riverpod Best Practices
1. Keep providers focused and composable
2. Use .autoDispose when appropriate
3. Leverage .family for parameterized providers
4. Use ConsumerWidget instead of StatefulWidget when possible
5. Handle AsyncValue states (data, loading, error)
6. Override providers in tests

## Migration Guide

### From Provider to Riverpod

```dart
// Provider
ChangeNotifierProvider(
  create: (_) => Counter(),
  child: Consumer<Counter>(
    builder: (context, counter, _) => Text('${counter.value}'),
  ),
)

// Riverpod
final counterProvider = StateNotifierProvider<Counter, int>((ref) => Counter());

ConsumerWidget(
  builder: (context, ref, _) {
    final count = ref.watch(counterProvider);
    return Text('$count');
  },
)
```

### From Bloc to Riverpod

```dart
// Bloc
context.read<CounterBloc>().add(IncrementCounter());

// Riverpod
ref.read(counterProvider.notifier).increment();
```
