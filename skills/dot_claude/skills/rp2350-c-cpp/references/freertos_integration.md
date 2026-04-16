# FreeRTOS Integration for RP2350

## Overview

FreeRTOS provides real-time task scheduling, synchronization primitives, and memory management for embedded systems. The Pico SDK includes official FreeRTOS support for RP2040/RP2350.

## Setup

### 1. Get FreeRTOS Kernel

```bash
cd my_project
git clone https://github.com/FreeRTOS/FreeRTOS-Kernel.git
cd FreeRTOS-Kernel
git submodule update --init
```

### 2. CMakeLists.txt Configuration

```cmake
cmake_minimum_required(VERSION 3.13)

include(pico_sdk_import.cmake)

project(freertos_project C CXX ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)

pico_sdk_init()

# Include FreeRTOS
set(FREERTOS_KERNEL_PATH ${CMAKE_CURRENT_LIST_DIR}/FreeRTOS-Kernel)
include(${FREERTOS_KERNEL_PATH}/portable/ThirdParty/GCC/RP2040/FreeRTOS_Kernel_import.cmake)

add_executable(freertos_project
    src/main.c
    src/tasks.c
)

target_include_directories(freertos_project PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/config  # FreeRTOSConfig.h location
)

target_link_libraries(freertos_project
    pico_stdlib
    FreeRTOS-Kernel
    FreeRTOS-Kernel-Heap4  # Use heap_4 allocator
)

# Disable Pico SDK heap (use FreeRTOS heap instead)
target_compile_definitions(freertos_project PRIVATE
    PICO_HEAP_SIZE=0
)

pico_enable_stdio_usb(freertos_project 1)
pico_add_extra_outputs(freertos_project)
```

### 3. FreeRTOSConfig.h

Create `config/FreeRTOSConfig.h`:

```c
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

// Scheduler configuration
#define configUSE_PREEMPTION                    1
#define configUSE_TICKLESS_IDLE                 0
#define configUSE_IDLE_HOOK                     0
#define configUSE_TICK_HOOK                     0
#define configTICK_RATE_HZ                      ((TickType_t)1000)
#define configMAX_PRIORITIES                    5
#define configMINIMAL_STACK_SIZE                ((configSTACK_DEPTH_TYPE)128)
#define configUSE_16_BIT_TICKS                  0

// Memory allocation
#define configTOTAL_HEAP_SIZE                   (64 * 1024)  // 64KB
#define configAPPLICATION_ALLOCATED_HEAP        0

// Task utilities
#define configUSE_MUTEXES                       1
#define configUSE_RECURSIVE_MUTEXES             1
#define configUSE_COUNTING_SEMAPHORES           1
#define configUSE_TASK_NOTIFICATIONS            1
#define configUSE_TRACE_FACILITY                1
#define configUSE_QUEUE_SETS                    0

// Software timer
#define configUSE_TIMERS                        1
#define configTIMER_TASK_PRIORITY               (configMAX_PRIORITIES - 1)
#define configTIMER_QUEUE_LENGTH                10
#define configTIMER_TASK_STACK_DEPTH            configMINIMAL_STACK_SIZE

// Debugging
#define configCHECK_FOR_STACK_OVERFLOW          2
#define configASSERT(x)                         if((x)==0) { taskDISABLE_INTERRUPTS(); for(;;); }

// Hook functions
#define configUSE_MALLOC_FAILED_HOOK            1
#define configUSE_DAEMON_TASK_STARTUP_HOOK      0

// Statistics
#define configGENERATE_RUN_TIME_STATS           0
#define configUSE_STATS_FORMATTING_FUNCTIONS    0

// Co-routine definitions
#define configUSE_CO_ROUTINES                   0
#define configMAX_CO_ROUTINE_PRIORITIES         2

// Cortex-M specific
#define configMAX_SYSCALL_INTERRUPT_PRIORITY    191
#define configKERNEL_INTERRUPT_PRIORITY         255

// RP2040/RP2350 specific
#define configSUPPORT_PICO_SYNC_INTEROP         1
#define configSUPPORT_PICO_TIME_INTEROP         1

// Include standard definitions
#include <stdint.h>
extern uint32_t SystemCoreClock;

#endif /* FREERTOS_CONFIG_H */
```

## Basic Usage

### Main Entry Point

```c
#include "FreeRTOS.h"
#include "task.h"
#include "pico/stdlib.h"

void task1(void *pvParameters) {
    while (1) {
        printf("Task 1\n");
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void task2(void *pvParameters) {
    while (1) {
        printf("Task 2\n");
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

int main() {
    stdio_init_all();

    xTaskCreate(task1, "Task1", 256, NULL, 1, NULL);
    xTaskCreate(task2, "Task2", 256, NULL, 1, NULL);

    vTaskStartScheduler();

    // Should never reach here
    while (1) {
        tight_loop_contents();
    }
}
```

## Task Management

### Creating Tasks

```c
TaskHandle_t task_handle;

BaseType_t result = xTaskCreate(
    task_function,           // Task function
    "Task Name",            // Task name (for debugging)
    256,                    // Stack size (words, not bytes)
    NULL,                   // Parameters
    1,                      // Priority (0 = lowest)
    &task_handle            // Task handle (optional)
);

if (result != pdPASS) {
    printf("Failed to create task\n");
}
```

### Task Delays

```c
// Absolute delay
vTaskDelay(pdMS_TO_TICKS(1000));  // Delay 1 second

// Delay until
TickType_t xLastWakeTime = xTaskGetTickCount();
while (1) {
    // This task will execute exactly every 100ms
    vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(100));
    // Do work...
}
```

### Task Priorities

```c
// Change task priority
vTaskPrioritySet(task_handle, 2);

// Get current priority
UBaseType_t priority = uxTaskPriorityGet(task_handle);
```

### Task Suspension

```c
// Suspend a task
vTaskSuspend(task_handle);

// Resume a task
vTaskResume(task_handle);

// Delete a task
vTaskDelete(task_handle);  // NULL = delete self
```

## Synchronization

### Mutexes

```c
SemaphoreHandle_t mutex;

void setup_mutex() {
    mutex = xSemaphoreCreateMutex();
    if (mutex == NULL) {
        printf("Failed to create mutex\n");
    }
}

void task_with_mutex(void *pvParameters) {
    while (1) {
        // Take mutex with 1-second timeout
        if (xSemaphoreTake(mutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
            // Critical section
            printf("In critical section\n");

            // Release mutex
            xSemaphoreGive(mutex);
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

### Binary Semaphores

```c
SemaphoreHandle_t semaphore;

void producer_task(void *pvParameters) {
    while (1) {
        // Signal that data is ready
        xSemaphoreGive(semaphore);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void consumer_task(void *pvParameters) {
    while (1) {
        // Wait for data
        if (xSemaphoreTake(semaphore, portMAX_DELAY) == pdTRUE) {
            printf("Data received\n");
        }
    }
}

int main() {
    semaphore = xSemaphoreCreateBinary();
    xTaskCreate(producer_task, "Producer", 256, NULL, 1, NULL);
    xTaskCreate(consumer_task, "Consumer", 256, NULL, 1, NULL);
    vTaskStartScheduler();
}
```

### Counting Semaphores

```c
SemaphoreHandle_t counting_sem;

void setup() {
    // Create semaphore with max count of 5, initial count 0
    counting_sem = xSemaphoreCreateCounting(5, 0);
}

void resource_producer(void *pvParameters) {
    while (1) {
        xSemaphoreGive(counting_sem);  // Add resource
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void resource_consumer(void *pvParameters) {
    while (1) {
        xSemaphoreTake(counting_sem, portMAX_DELAY);  // Take resource
        printf("Resource consumed\n");
    }
}
```

## Queues

### Basic Queue Usage

```c
QueueHandle_t queue;

typedef struct {
    uint8_t sensor_id;
    float value;
} sensor_data_t;

void sender_task(void *pvParameters) {
    sensor_data_t data;

    while (1) {
        data.sensor_id = 1;
        data.value = 25.5;

        // Send to queue with 100ms timeout
        if (xQueueSend(queue, &data, pdMS_TO_TICKS(100)) != pdTRUE) {
            printf("Queue full\n");
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void receiver_task(void *pvParameters) {
    sensor_data_t data;

    while (1) {
        // Receive from queue, block indefinitely
        if (xQueueReceive(queue, &data, portMAX_DELAY) == pdTRUE) {
            printf("Sensor %d: %.2f\n", data.sensor_id, data.value);
        }
    }
}

int main() {
    stdio_init_all();

    // Create queue with 10 items
    queue = xQueueCreate(10, sizeof(sensor_data_t));

    xTaskCreate(sender_task, "Sender", 256, NULL, 1, NULL);
    xTaskCreate(receiver_task, "Receiver", 256, NULL, 1, NULL);

    vTaskStartScheduler();
}
```

### Queue Utilities

```c
// Check queue status
UBaseType_t spaces_available = uxQueueSpacesAvailable(queue);
UBaseType_t messages_waiting = uxQueueMessagesWaiting(queue);

// Peek at queue without removing
xQueuePeek(queue, &data, pdMS_TO_TICKS(100));

// Send to front of queue (high priority)
xQueueSendToFront(queue, &data, pdMS_TO_TICKS(100));

// Send to back (normal)
xQueueSendToBack(queue, &data, pdMS_TO_TICKS(100));

// Reset queue
xQueueReset(queue);
```

## Software Timers

```c
TimerHandle_t timer;

void timer_callback(TimerHandle_t xTimer) {
    printf("Timer expired\n");
}

void setup_timer() {
    // Create one-shot timer (1 second)
    timer = xTimerCreate(
        "Timer1",                    // Name
        pdMS_TO_TICKS(1000),        // Period
        pdFALSE,                    // Auto-reload (pdFALSE = one-shot)
        NULL,                       // Timer ID
        timer_callback              // Callback
    );

    // Start timer
    xTimerStart(timer, 0);
}

// Create auto-reload timer (periodic)
TimerHandle_t periodic_timer = xTimerCreate(
    "Periodic",
    pdMS_TO_TICKS(500),
    pdTRUE,                         // Auto-reload
    NULL,
    timer_callback
);
```

## Task Notifications

Task notifications are a lightweight alternative to semaphores and queues.

```c
TaskHandle_t task_to_notify;

void notifying_task(void *pvParameters) {
    while (1) {
        // Send notification
        xTaskNotifyGive(task_to_notify);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void notified_task(void *pvParameters) {
    while (1) {
        // Wait for notification
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        printf("Notification received\n");
    }
}

int main() {
    xTaskCreate(notified_task, "Notified", 256, NULL, 1, &task_to_notify);
    xTaskCreate(notifying_task, "Notifier", 256, NULL, 1, NULL);
    vTaskStartScheduler();
}
```

## Interrupt Handling

### ISR-Safe Functions

Use `FromISR` variants in interrupt handlers:

```c
SemaphoreHandle_t isr_semaphore;

void gpio_isr() {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    // Give semaphore from ISR
    xSemaphoreGiveFromISR(isr_semaphore, &xHigherPriorityTaskWoken);

    // Context switch if needed
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void handler_task(void *pvParameters) {
    while (1) {
        xSemaphoreTake(isr_semaphore, portMAX_DELAY);
        printf("Interrupt handled\n");
    }
}
```

### Deferred Interrupt Processing

```c
TaskHandle_t handler_task_handle;

void gpio_isr() {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    // Notify handler task
    vTaskNotifyGiveFromISR(handler_task_handle, &xHigherPriorityTaskWoken);
    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void handler_task(void *pvParameters) {
    while (1) {
        // Wait for notification from ISR
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        // Process interrupt (outside ISR context)
        printf("Processing interrupt\n");
        // Heavy processing here...
    }
}
```

## Memory Management

### Heap Selection

FreeRTOS provides 5 heap implementations:

- **heap_1**: Simple, no free support
- **heap_2**: Basic, allows free but no coalescence
- **heap_3**: Wraps malloc/free
- **heap_4**: Recommended, coalescence support
- **heap_5**: Like heap_4, supports non-contiguous memory

Configure in CMakeLists.txt:
```cmake
target_link_libraries(my_project
    FreeRTOS-Kernel-Heap4  # or Heap1, Heap2, etc.
)
```

### Memory Functions

```c
// Allocate memory
void *ptr = pvPortMalloc(1024);

// Free memory
vPortFree(ptr);

// Get free heap size
size_t free_heap = xPortGetFreeHeapSize();
printf("Free heap: %zu bytes\n", free_heap);

// Get minimum ever free heap
size_t min_free = xPortGetMinimumEverFreeHeapSize();
```

## Debugging and Diagnostics

### Stack Overflow Detection

Enable in FreeRTOSConfig.h:
```c
#define configCHECK_FOR_STACK_OVERFLOW 2
```

Implement hook:
```c
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
    printf("Stack overflow in task: %s\n", pcTaskName);
    while (1) {
        tight_loop_contents();
    }
}
```

### Malloc Failed Hook

```c
void vApplicationMallocFailedHook(void) {
    printf("Malloc failed! Free heap: %zu\n", xPortGetFreeHeapSize());
    while (1) {
        tight_loop_contents();
    }
}
```

### Task Statistics

Enable in FreeRTOSConfig.h:
```c
#define configUSE_TRACE_FACILITY 1
#define configUSE_STATS_FORMATTING_FUNCTIONS 1
```

Usage:
```c
char task_list_buffer[512];

void print_task_stats() {
    vTaskList(task_list_buffer);
    printf("Task Name\tState\tPrio\tStack\tNum\n");
    printf("%s\n", task_list_buffer);
}
```

## Best Practices

### 1. Task Design

```c
// Good: Periodic task with delay
void periodic_task(void *pvParameters) {
    TickType_t xLastWakeTime = xTaskGetTickCount();

    while (1) {
        // Do work
        process_data();

        // Fixed-rate delay
        vTaskDelayUntil(&xLastWakeTime, pdMS_TO_TICKS(100));
    }
}

// Bad: Busy-wait loop
void bad_task(void *pvParameters) {
    while (1) {
        process_data();
        // No delay - wastes CPU
    }
}
```

### 2. Priority Assignment

```c
// Priority levels (example)
#define PRIORITY_IDLE       0
#define PRIORITY_LOW        1
#define PRIORITY_NORMAL     2
#define PRIORITY_HIGH       3
#define PRIORITY_CRITICAL   4

xTaskCreate(ui_task, "UI", 256, NULL, PRIORITY_LOW, NULL);
xTaskCreate(sensor_task, "Sensor", 256, NULL, PRIORITY_NORMAL, NULL);
xTaskCreate(control_task, "Control", 256, NULL, PRIORITY_HIGH, NULL);
xTaskCreate(safety_task, "Safety", 256, NULL, PRIORITY_CRITICAL, NULL);
```

### 3. Stack Size Calculation

```c
// Monitor stack usage
UBaseType_t stack_high_water = uxTaskGetStackHighWaterMark(NULL);
printf("Unused stack: %u words\n", stack_high_water);

// Allocate appropriate stack
// Rule of thumb: Start with 256 words, adjust based on high water mark
xTaskCreate(my_task, "Task", 256, NULL, 1, NULL);
```

### 4. Critical Sections

```c
// Short critical section
taskENTER_CRITICAL();
// Modify shared data
shared_variable++;
taskEXIT_CRITICAL();

// Alternative: Use mutex for longer sections
xSemaphoreTake(mutex, portMAX_DELAY);
// Longer operation
for (int i = 0; i < 100; i++) {
    process(i);
}
xSemaphoreGive(mutex);
```

## Common Patterns

### Producer-Consumer with Queue

```c
QueueHandle_t data_queue;

void producer(void *pvParameters) {
    uint32_t counter = 0;
    while (1) {
        xQueueSend(data_queue, &counter, pdMS_TO_TICKS(100));
        counter++;
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}

void consumer(void *pvParameters) {
    uint32_t data;
    while (1) {
        if (xQueueReceive(data_queue, &data, portMAX_DELAY) == pdTRUE) {
            printf("Consumed: %lu\n", data);
        }
    }
}

int main() {
    data_queue = xQueueCreate(10, sizeof(uint32_t));
    xTaskCreate(producer, "Producer", 256, NULL, 1, NULL);
    xTaskCreate(consumer, "Consumer", 256, NULL, 1, NULL);
    vTaskStartScheduler();
}
```

### Event-Driven Task

```c
TaskHandle_t event_task_handle;

void event_task(void *pvParameters) {
    uint32_t event_bits;

    while (1) {
        // Wait for any event
        if (xTaskNotifyWait(0, 0xFFFFFFFF, &event_bits, portMAX_DELAY) == pdTRUE) {
            if (event_bits & 0x01) {
                printf("Event 1\n");
            }
            if (event_bits & 0x02) {
                printf("Event 2\n");
            }
        }
    }
}

// Trigger events from other tasks or ISRs
void trigger_event() {
    xTaskNotify(event_task_handle, 0x01, eSetBits);
}
```
