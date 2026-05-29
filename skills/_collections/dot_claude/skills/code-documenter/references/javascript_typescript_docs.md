# JavaScript/TypeScript Documentation Standards

## Overview

JavaScript uses JSDoc comments, while TypeScript combines JSDoc with native type annotations. Use TSDoc for TypeScript-specific projects.

## File/Module Documentation

Place at the top of the file:

```typescript
/**
 * MQTT client wrapper for Stream Deck plugin communication.
 *
 * Provides WebSocket MQTT connectivity for real-time synchronization
 * between Stream Deck buttons and productivity timer devices.
 *
 * @module mqtt-client
 */
```

## Class Documentation

Include purpose, usage examples, and important notes:

```typescript
/**
 * Manages Stream Deck action lifecycle and MQTT communication.
 *
 * Handles connection management, message subscriptions, and button
 * state updates for productivity timer controls.
 *
 * @example
 * ```typescript
 * @action({ UUID: "com.adhd.timer.start" })
 * export class StartTimerAction extends SingletonAction {
 *   // Implementation
 * }
 * ```
 */
@action({ UUID: "com.adhd.timer.control" })
export class TimerControlAction extends SingletonAction {
```

## Function/Method Documentation

Include description, parameters, return values, and examples:

```typescript
/**
 * Formats seconds into MM:SS display format for button labels.
 *
 * @param seconds - Total seconds remaining in timer
 * @returns Formatted time string (e.g., "25:00", "3:45")
 *
 * @example
 * ```typescript
 * formatTime(150);  // Returns "2:30"
 * formatTime(45);   // Returns "0:45"
 * ```
 */
private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
}
```

## Async Function Documentation

Highlight async behavior and error handling:

```typescript
/**
 * Establishes WebSocket MQTT connection to productivity broker.
 *
 * Connects to the Mosquitto broker running on Jetson Nano and
 * subscribes to timer state updates. Implements automatic
 * reconnection with exponential backoff.
 *
 * @param brokerUrl - WebSocket URL (e.g., "ws://192.168.1.100:9001")
 * @returns Promise that resolves when connection is established
 * @throws {ConnectionError} If broker is unreachable after retries
 *
 * @example
 * ```typescript
 * await connectToMQTT("ws://192.168.1.100:9001");
 * ```
 */
async connectToMQTT(brokerUrl: string): Promise<void> {
```

## Interface/Type Documentation

Document each property:

```typescript
/**
 * Configuration settings for timer display button.
 */
interface TimerSettings {
    /** WebSocket URL of MQTT broker */
    brokerUrl: string;

    /** MQTT topic for timer state updates */
    stateTopic: string;

    /** Update interval in milliseconds (default: 1000) */
    updateInterval?: number;

    /** Enable connection status indicator */
    showConnectionStatus?: boolean;
}
```

## React Component Documentation

Document props, state, and behavior:

```typescript
/**
 * Visual timer display component with ADHD-optimized feedback.
 *
 * Renders a circular progress indicator with smooth transitions
 * and color-coded urgency levels.
 *
 * @component
 * @example
 * ```tsx
 * <TimerDisplay
 *   remainingSeconds={1500}
 *   totalSeconds={1500}
 *   onComplete={() => showNotification()}
 * />
 * ```
 */
export function TimerDisplay({
    remainingSeconds,
    totalSeconds,
    onComplete
}: TimerDisplayProps): JSX.Element {
```

## Constants and Enums

Document purpose and usage:

```typescript
/**
 * MQTT topic structure for productivity system.
 *
 * All topics follow hierarchical structure:
 * productivity/{domain}/{action}/{identifier}
 */
export const MQTT_TOPICS = {
    /** Start timer command */
    TIMER_START: 'productivity/timer/control/start',

    /** Timer state synchronization */
    TIMER_SYNC: 'productivity/timer/state/sync',

    /** Visual alert broadcast */
    ALERT_VISUAL: 'productivity/alert/visual',
} as const;
```

## Inline Comments

Explain complex logic or non-obvious decisions:

```typescript
// WebSocket reconnection with exponential backoff prevents
// overwhelming the broker during network instability
const reconnectDelay = Math.min(
    1000 * Math.pow(2, this.reconnectAttempts),
    30000  // Cap at 30 seconds
);
```

## What NOT to Document

Avoid self-explanatory code:

```typescript
// BAD: Obvious comment
const total = a + b;  // Add a and b

// GOOD: Explains why
const total = a + b;  // Combine work and break duration for full cycle
```

## TypeScript-Specific Guidelines

Let types speak for themselves when clear:

```typescript
// Type is obvious from signature - no JSDoc needed
function getButtonId(context: string, action: string): string {
    return `${context}_${action}`;
}

// Complex types need documentation
/**
 * Merges user settings with defaults, validating required fields.
 *
 * @template T - Settings type extending base configuration
 */
function mergeSettings<T extends BaseSettings>(
    user: Partial<T>,
    defaults: T
): T {
```

## Standards Summary

- Use JSDoc `/** */` for documentation blocks
- TSDoc for TypeScript-specific features
- Document public APIs (functions, classes, interfaces)
- Include `@param`, `@returns`, `@throws` tags
- Add `@example` blocks for complex usage
- Type annotations reduce need for parameter docs
- Focus inline comments on "why"
- Use `@deprecated` for outdated APIs
