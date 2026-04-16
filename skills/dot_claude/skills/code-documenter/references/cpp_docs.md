# C/C++ Documentation Standards

## Overview

C/C++ documentation uses Doxygen-style comments. Use `///` for single-line or `/** */` for multi-line documentation blocks.

## File Documentation

Place at the top of header and source files:

```cpp
/**
 * @file time_display.h
 * @brief Visual timer display management for RP2350 Presto device
 *
 * Provides smooth animation and color transitions for ADHD-optimized
 * time awareness feedback. Targets 30+ FPS for professional appearance.
 *
 * @author ADHD Productivity System
 * @date 2024-01-15
 */
```

## Class Documentation

Include purpose, usage, and important implementation details:

```cpp
/**
 * @brief Manages visual timer display with smooth transitions
 *
 * Implements double-buffered rendering for flicker-free animations
 * and calculates urgency-based color gradients suitable for users
 * with ADHD who need non-disruptive visual feedback.
 *
 * @note This class uses hardware acceleration via PIO on RP2350
 *
 * Example usage:
 * @code
 * TimeDisplay display;
 * display.initialize(DISPLAY_WIDTH, DISPLAY_HEIGHT);
 * display.setRemainingTime(1500);  // 25 minutes
 * display.render();
 * @endcode
 */
class TimeDisplay {
private:
    uint32_t remaining_seconds_;
    Color current_urgency_color_;

public:
    /**
     * @brief Initialize display with given dimensions
     *
     * @param width Display width in pixels
     * @param height Display height in pixels
     * @return true if initialization succeeded, false otherwise
     */
    bool initialize(uint16_t width, uint16_t height);

    /**
     * @brief Update remaining time and trigger smooth transition
     *
     * Calculates new urgency level and initiates color transition
     * to prevent jarring changes that could break hyperfocus.
     *
     * @param seconds Remaining seconds in timer
     */
    void setRemainingTime(uint32_t seconds);

    /**
     * @brief Render current frame to display
     *
     * Should be called at 30+ FPS for smooth animation. Uses
     * double buffering to prevent tearing.
     */
    void render();
};
```

## Function Documentation

Include description, parameters, return values, and side effects:

```cpp
/**
 * @brief Calculate smooth color transition between urgency levels
 *
 * Uses linear interpolation to transition from current color to
 * target color over specified duration. Prevents sudden changes
 * that could disrupt user focus.
 *
 * @param start_color Starting RGB color value
 * @param end_color Target RGB color value
 * @param progress Transition progress (0.0 to 1.0)
 * @return Interpolated RGB color value
 *
 * @pre progress must be between 0.0 and 1.0
 * @post Returns color between start_color and end_color
 *
 * @warning Color calculations assume 24-bit RGB format
 */
Color calculateSmoothTransition(
    Color start_color,
    Color end_color,
    float progress
);
```

## Enum Documentation

Document each value:

```cpp
/**
 * @brief Visual notification priority levels
 *
 * Defines urgency levels for notifications, with each level having
 * distinct visual characteristics optimized for ADHD users.
 */
enum class NotificationPriority {
    /** Slow ambient color shift, barely noticeable */
    AMBIENT,

    /** Soft pulse at 0.5 Hz, gentle attention grab */
    GENTLE,

    /** Border flash every 2 seconds, clear but not disruptive */
    STANDARD,

    /** Full screen pulse at 1 Hz, requires attention */
    URGENT,

    /** Rapid alternating colors at 2 Hz, immediate action needed */
    CRITICAL
};
```

## Struct Documentation

Document purpose and each member:

```cpp
/**
 * @brief Configuration settings for productivity timer
 *
 * Stores user preferences for timer behavior, visual feedback,
 * and accessibility options.
 */
struct TimerConfig {
    /** Work period duration in seconds */
    uint32_t work_duration;

    /** Break period duration in seconds */
    uint32_t break_duration;

    /** Enable colorblind-friendly patterns */
    bool colorblind_mode;

    /** Animation frame rate (10-60 FPS) */
    uint8_t target_fps;

    /** @brief Validate configuration values
     *  @return true if all values are within acceptable ranges */
    bool isValid() const;
};
```

## Template Documentation

Document template parameters:

```cpp
/**
 * @brief Generic circular buffer for sensor data
 *
 * Implements fixed-size ring buffer with efficient wraparound
 * for streaming sensor data from multiple devices.
 *
 * @tparam T Data type to store (must be trivially copyable)
 * @tparam Size Buffer capacity (must be power of 2)
 *
 * Example:
 * @code
 * CircularBuffer<uint16_t, 256> buffer;
 * buffer.push(sensor_reading);
 * uint16_t value = buffer.pop();
 * @endcode
 */
template<typename T, size_t Size>
class CircularBuffer {
    static_assert((Size & (Size - 1)) == 0, "Size must be power of 2");
```

## Macro Documentation

Always document macros:

```cpp
/**
 * @def CHECK_ERROR
 * @brief Assert condition and log error if false
 *
 * In debug builds, logs error message and halts execution.
 * In release builds, logs error and continues.
 *
 * @param condition Expression to evaluate
 * @param message Error message to log if condition is false
 */
#ifdef DEBUG
#define CHECK_ERROR(condition, message) \
    do { \
        if (!(condition)) { \
            log_error(__FILE__, __LINE__, message); \
            abort(); \
        } \
    } while(0)
#else
#define CHECK_ERROR(condition, message) \
    do { \
        if (!(condition)) { \
            log_error(__FILE__, __LINE__, message); \
        } \
    } while(0)
#endif
```

## Inline Comments

Explain hardware-specific or non-obvious code:

```cpp
// PIO state machine 0 handles WS2812 LED timing
// Must maintain precise 800kHz signal with 0.35μs/0.7μs pulses
pio_sm_config cfg = ws2812_program_get_default_config(offset);
sm_config_set_sideset_pins(&cfg, PIN_LED_DATA);
sm_config_set_out_shift(&cfg, false, true, 24);  // Shift left, auto-pull, 24 bits
```

## Memory Management Comments

Document ownership and lifetime:

```cpp
/**
 * @brief Allocate display buffer in DMA-capable memory
 *
 * Buffer is freed automatically in destructor.
 *
 * @warning Do not manually free this buffer
 * @note Memory aligned to 32-byte boundary for DMA efficiency
 */
uint8_t* allocateDisplayBuffer(size_t byte_count) {
    // Aligned allocation required for RP2350 DMA
    return static_cast<uint8_t*>(
        aligned_alloc(32, byte_count)
    );
}
```

## Thread Safety Documentation

Always note thread safety:

```cpp
/**
 * @brief Update timer state from MQTT callback
 *
 * @param new_state Updated timer state from network
 *
 * @note This function is called from MQTT thread, not main thread
 * @warning Must lock state_mutex_ before accessing shared state
 * @threadsafe Yes, when used with proper mutex locking
 */
void updateTimerState(const TimerState& new_state);
```

## What NOT to Document

Avoid obvious comments:

```cpp
// BAD: States the obvious
i++;  // Increment i

// GOOD: Explains why
i++;  // Advance to next LED in animation sequence
```

## Standards Summary

- Use Doxygen `/** */` or `///` for documentation
- `@brief` for short description
- `@param` for parameters (include type if not obvious)
- `@return` for return values
- `@note`, `@warning`, `@pre`, `@post` for important info
- `@code` blocks for usage examples
- Document thread safety with `@threadsafe`
- Document memory ownership
- Explain hardware-specific code
- Focus inline comments on "why" not "what"
