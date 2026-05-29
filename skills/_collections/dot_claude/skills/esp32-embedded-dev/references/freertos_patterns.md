# Advanced FreeRTOS Patterns for ESP32

## Task Design Patterns

### Producer-Consumer with Multiple Queues

Efficient data flow between multiple producers and consumers using priority queues.

```c
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"

#define HIGH_PRIORITY_QUEUE_SIZE  5
#define LOW_PRIORITY_QUEUE_SIZE   20

typedef struct {
    uint8_t priority;
    uint32_t data;
    uint64_t timestamp;
} event_t;

static QueueHandle_t high_priority_queue;
static QueueHandle_t low_priority_queue;

void init_queues(void) {
    high_priority_queue = xQueueCreate(HIGH_PRIORITY_QUEUE_SIZE, sizeof(event_t));
    low_priority_queue = xQueueCreate(LOW_PRIORITY_QUEUE_SIZE, sizeof(event_t));
}

// Producer sends to appropriate queue
void producer_task(void *pvParameters) {
    event_t event;

    while (1) {
        event.data = get_sensor_data();
        event.timestamp = esp_timer_get_time();

        if (event.data > THRESHOLD) {
            event.priority = 1;
            xQueueSend(high_priority_queue, &event, pdMS_TO_TICKS(10));
        } else {
            event.priority = 0;
            xQueueSend(low_priority_queue, &event, pdMS_TO_TICKS(100));
        }

        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

// Consumer checks high priority first
void consumer_task(void *pvParameters) {
    event_t event;

    while (1) {
        // Check high priority queue first (no blocking)
        if (xQueueReceive(high_priority_queue, &event, 0) == pdPASS) {
            process_high_priority_event(&event);
        }
        // Then check low priority queue
        else if (xQueueReceive(low_priority_queue, &event, pdMS_TO_TICKS(100)) == pdPASS) {
            process_low_priority_event(&event);
        }
    }
}
```

### Task Notification Pattern (Lightweight Synchronization)

Task notifications are faster and use less RAM than binary semaphores for simple synchronization.

```c
static TaskHandle_t processing_task_handle = NULL;

// ISR notifies task directly
void IRAM_ATTR sensor_isr(void *arg) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    // Notify task and set bit 0
    vTaskNotifyGiveFromISR(processing_task_handle, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void processing_task(void *pvParameters) {
    while (1) {
        // Wait for notification (consumes notification)
        uint32_t notification_value = ulTaskNotifyTake(pdTRUE, portMAX_DELAY);

        if (notification_value > 0) {
            process_sensor_data();
        }
    }
}

void init_sensor_processing(void) {
    xTaskCreate(processing_task, "processing", 4096, NULL, 5, &processing_task_handle);

    // Install ISR
    gpio_install_isr_service(0);
    gpio_isr_handler_add(SENSOR_GPIO, sensor_isr, NULL);
}
```

### State Machine Pattern

Clean state management for complex task logic.

```c
typedef enum {
    STATE_IDLE,
    STATE_CONNECTING,
    STATE_CONNECTED,
    STATE_TRANSMITTING,
    STATE_ERROR
} network_state_t;

typedef struct {
    network_state_t state;
    uint32_t retry_count;
    uint64_t last_activity;
} network_context_t;

static network_context_t ctx = {.state = STATE_IDLE};

// State handlers
static void handle_idle(network_context_t *ctx) {
    ESP_LOGI("STATE", "IDLE -> CONNECTING");
    start_connection();
    ctx->state = STATE_CONNECTING;
    ctx->retry_count = 0;
}

static void handle_connecting(network_context_t *ctx) {
    if (is_connected()) {
        ESP_LOGI("STATE", "CONNECTING -> CONNECTED");
        ctx->state = STATE_CONNECTED;
    } else if (ctx->retry_count++ > MAX_RETRIES) {
        ESP_LOGE("STATE", "CONNECTING -> ERROR");
        ctx->state = STATE_ERROR;
    }
}

static void handle_connected(network_context_t *ctx) {
    if (has_data_to_send()) {
        ESP_LOGI("STATE", "CONNECTED -> TRANSMITTING");
        ctx->state = STATE_TRANSMITTING;
    } else if (!is_connected()) {
        ESP_LOGW("STATE", "CONNECTED -> IDLE");
        ctx->state = STATE_IDLE;
    }
}

static void handle_transmitting(network_context_t *ctx) {
    if (transmission_complete()) {
        ESP_LOGI("STATE", "TRANSMITTING -> CONNECTED");
        ctx->state = STATE_CONNECTED;
    } else if (!is_connected()) {
        ESP_LOGW("STATE", "TRANSMITTING -> IDLE");
        ctx->state = STATE_IDLE;
    }
}

static void handle_error(network_context_t *ctx) {
    ESP_LOGE("STATE", "ERROR -> IDLE");
    reset_connection();
    ctx->state = STATE_IDLE;
}

// State machine task
void network_task(void *pvParameters) {
    while (1) {
        switch (ctx.state) {
            case STATE_IDLE:        handle_idle(&ctx); break;
            case STATE_CONNECTING:  handle_connecting(&ctx); break;
            case STATE_CONNECTED:   handle_connected(&ctx); break;
            case STATE_TRANSMITTING: handle_transmitting(&ctx); break;
            case STATE_ERROR:       handle_error(&ctx); break;
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

## Synchronization Patterns

### Resource Pool Pattern

Manage limited resources (like DMA channels) with counting semaphores.

```c
#define DMA_CHANNEL_COUNT 4

static SemaphoreHandle_t dma_pool;

void init_dma_pool(void) {
    dma_pool = xSemaphoreCreateCounting(DMA_CHANNEL_COUNT, DMA_CHANNEL_COUNT);
}

esp_err_t acquire_dma_channel(void) {
    if (xSemaphoreTake(dma_pool, pdMS_TO_TICKS(1000)) == pdTRUE) {
        ESP_LOGI("DMA", "Channel acquired");
        return ESP_OK;
    } else {
        ESP_LOGE("DMA", "No channels available");
        return ESP_ERR_TIMEOUT;
    }
}

void release_dma_channel(void) {
    xSemaphoreGive(dma_pool);
    ESP_LOGI("DMA", "Channel released");
}

void transfer_task(void *pvParameters) {
    while (1) {
        if (acquire_dma_channel() == ESP_OK) {
            perform_dma_transfer();
            release_dma_channel();
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
```

### Double-Buffering Pattern

Smooth rendering without tearing.

```c
#define BUFFER_SIZE (320 * 240 * 2)

static uint8_t *front_buffer;
static uint8_t *back_buffer;
static SemaphoreHandle_t buffer_swap_mutex;

void init_double_buffer(void) {
    front_buffer = heap_caps_malloc(BUFFER_SIZE, MALLOC_CAP_SPIRAM);
    back_buffer = heap_caps_malloc(BUFFER_SIZE, MALLOC_CAP_SPIRAM);
    buffer_swap_mutex = xSemaphoreCreateMutex();
}

void render_task(void *pvParameters) {
    TickType_t last_wake_time = xTaskGetTickCount();

    while (1) {
        // Render to back buffer (non-blocking)
        render_frame(back_buffer);

        // Swap buffers atomically
        if (xSemaphoreTake(buffer_swap_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            uint8_t *temp = front_buffer;
            front_buffer = back_buffer;
            back_buffer = temp;
            xSemaphoreGive(buffer_swap_mutex);
        }

        // 30 FPS
        vTaskDelayUntil(&last_wake_time, pdMS_TO_TICKS(33));
    }
}

void display_task(void *pvParameters) {
    while (1) {
        // Display front buffer
        if (xSemaphoreTake(buffer_swap_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            send_to_display(front_buffer, BUFFER_SIZE);
            xSemaphoreGive(buffer_swap_mutex);
        }

        vTaskDelay(pdMS_TO_TICKS(33));
    }
}
```

### Read-Write Lock Pattern

Multiple readers, single writer synchronization.

```c
typedef struct {
    SemaphoreHandle_t read_mutex;
    SemaphoreHandle_t write_mutex;
    int reader_count;
} rw_lock_t;

void rw_lock_init(rw_lock_t *lock) {
    lock->read_mutex = xSemaphoreCreateMutex();
    lock->write_mutex = xSemaphoreCreateMutex();
    lock->reader_count = 0;
}

void rw_lock_read_lock(rw_lock_t *lock) {
    xSemaphoreTake(lock->read_mutex, portMAX_DELAY);

    if (++lock->reader_count == 1) {
        // First reader blocks writers
        xSemaphoreTake(lock->write_mutex, portMAX_DELAY);
    }

    xSemaphoreGive(lock->read_mutex);
}

void rw_lock_read_unlock(rw_lock_t *lock) {
    xSemaphoreTake(lock->read_mutex, portMAX_DELAY);

    if (--lock->reader_count == 0) {
        // Last reader unblocks writers
        xSemaphoreGive(lock->write_mutex);
    }

    xSemaphoreGive(lock->read_mutex);
}

void rw_lock_write_lock(rw_lock_t *lock) {
    xSemaphoreTake(lock->write_mutex, portMAX_DELAY);
}

void rw_lock_write_unlock(rw_lock_t *lock) {
    xSemaphoreGive(lock->write_mutex);
}
```

## Memory Management Patterns

### Static Allocation Pattern

Avoid heap fragmentation for long-running systems.

```c
// Static task stack
static StackType_t task_stack[4096];

// Static task control block
static StaticTask_t task_tcb;

// Static queue storage
static uint8_t queue_storage[10 * sizeof(event_t)];
static StaticQueue_t queue_struct;

void create_static_task(void) {
    TaskHandle_t handle = xTaskCreateStatic(
        task_function,
        "static_task",
        4096,
        NULL,
        5,
        task_stack,
        &task_tcb
    );

    QueueHandle_t queue = xQueueCreateStatic(
        10,
        sizeof(event_t),
        queue_storage,
        &queue_struct
    );
}
```

### Memory Pool Pattern

Pre-allocate fixed-size blocks for predictable allocation.

```c
#define POOL_BLOCK_SIZE  512
#define POOL_BLOCK_COUNT 20

typedef struct pool_block {
    struct pool_block *next;
    uint8_t data[POOL_BLOCK_SIZE];
} pool_block_t;

static pool_block_t pool_blocks[POOL_BLOCK_COUNT];
static pool_block_t *pool_free_list = NULL;
static SemaphoreHandle_t pool_mutex;

void pool_init(void) {
    pool_mutex = xSemaphoreCreateMutex();

    for (int i = 0; i < POOL_BLOCK_COUNT - 1; i++) {
        pool_blocks[i].next = &pool_blocks[i + 1];
    }
    pool_blocks[POOL_BLOCK_COUNT - 1].next = NULL;

    pool_free_list = &pool_blocks[0];
}

void *pool_alloc(void) {
    void *block = NULL;

    if (xSemaphoreTake(pool_mutex, portMAX_DELAY) == pdTRUE) {
        if (pool_free_list != NULL) {
            pool_block_t *b = pool_free_list;
            pool_free_list = b->next;
            block = b->data;
        }
        xSemaphoreGive(pool_mutex);
    }

    return block;
}

void pool_free(void *ptr) {
    if (ptr == NULL) return;

    pool_block_t *b = (pool_block_t *)((uint8_t *)ptr - offsetof(pool_block_t, data));

    if (xSemaphoreTake(pool_mutex, portMAX_DELAY) == pdTRUE) {
        b->next = pool_free_list;
        pool_free_list = b;
        xSemaphoreGive(pool_mutex);
    }
}
```

## Timing Patterns

### Periodic Task with Drift Compensation

```c
void periodic_task(void *pvParameters) {
    TickType_t last_wake_time = xTaskGetTickCount();
    const TickType_t period = pdMS_TO_TICKS(100);

    while (1) {
        // Task work
        do_periodic_work();

        // Absolute timing (compensates for drift)
        vTaskDelayUntil(&last_wake_time, period);
    }
}
```

### Watchdog Pattern with Grace Period

```c
#include "esp_task_wdt.h"

#define WDT_TIMEOUT_S       10
#define WDT_RESET_PERIOD_S  5

void monitored_task(void *pvParameters) {
    esp_task_wdt_add(NULL);

    TickType_t last_reset = xTaskGetTickCount();

    while (1) {
        do_work();

        // Reset watchdog periodically
        TickType_t now = xTaskGetTickCount();
        if ((now - last_reset) > pdMS_TO_TICKS(WDT_RESET_PERIOD_S * 1000)) {
            esp_task_wdt_reset();
            last_reset = now;
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
```

### Debounce Pattern with Timer

```c
static TimerHandle_t debounce_timer = NULL;
static bool button_state = false;

void button_isr(void *arg) {
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;

    // Reset debounce timer
    xTimerResetFromISR(debounce_timer, &xHigherPriorityTaskWoken);

    portYIELD_FROM_ISR(xHigherPriorityTaskWoken);
}

void debounce_timer_callback(TimerHandle_t xTimer) {
    // Stable reading after debounce period
    button_state = gpio_get_level(BUTTON_PIN);
    handle_button_press(button_state);
}

void init_debounce(void) {
    debounce_timer = xTimerCreate("debounce", pdMS_TO_TICKS(50),
                                 pdFALSE, NULL, debounce_timer_callback);

    gpio_install_isr_service(0);
    gpio_isr_handler_add(BUTTON_PIN, button_isr, NULL);
}
```

## Error Handling Patterns

### Retry with Exponential Backoff

```c
esp_err_t retry_with_backoff(esp_err_t (*operation)(void), int max_retries) {
    esp_err_t ret;
    int delay_ms = 100;

    for (int retry = 0; retry < max_retries; retry++) {
        ret = operation();

        if (ret == ESP_OK) {
            return ESP_OK;
        }

        ESP_LOGW("RETRY", "Attempt %d failed, waiting %d ms", retry + 1, delay_ms);
        vTaskDelay(pdMS_TO_TICKS(delay_ms));

        // Exponential backoff with max cap
        delay_ms = (delay_ms * 2 < 10000) ? delay_ms * 2 : 10000;
    }

    ESP_LOGE("RETRY", "All attempts failed");
    return ret;
}
```

### Health Monitoring Pattern

```c
typedef struct {
    uint32_t heartbeat_count;
    uint64_t last_heartbeat;
    bool healthy;
} task_health_t;

static task_health_t health_status[5];

void health_monitor_task(void *pvParameters) {
    while (1) {
        uint64_t now = esp_timer_get_time();

        for (int i = 0; i < 5; i++) {
            uint64_t elapsed = now - health_status[i].last_heartbeat;

            if (elapsed > 5000000) {  // 5 seconds
                ESP_LOGE("HEALTH", "Task %d unhealthy", i);
                health_status[i].healthy = false;

                // Take corrective action
                restart_task(i);
            }
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void monitored_task_heartbeat(int task_id) {
    health_status[task_id].heartbeat_count++;
    health_status[task_id].last_heartbeat = esp_timer_get_time();
    health_status[task_id].healthy = true;
}
```

## Best Practices

### Task Priority Guidelines

```c
// ESP-IDF reserves priorities 19+ for system tasks
#define PRIORITY_CRITICAL   10  // Time-critical ISR processing
#define PRIORITY_HIGH       8   // Network stack, timers
#define PRIORITY_NORMAL     5   // Application logic
#define PRIORITY_LOW        3   // Background tasks
#define PRIORITY_IDLE       1   // Cleanup, logging
```

### Stack Size Recommendations

```c
#define STACK_SIZE_MINIMAL    2048   // Simple tasks
#define STACK_SIZE_NORMAL     4096   // Most tasks
#define STACK_SIZE_NETWORK    6144   // WiFi/BLE/MQTT
#define STACK_SIZE_DISPLAY    8192   // Graphics rendering
```

### Queue Size Calculation

```c
// Formula: (max_production_rate / consumer_rate) * safety_margin
// Example: Sensor at 100 Hz, processor at 50 Hz
// Queue size = (100/50) * 2 = 4 items minimum
```

## Performance Tips

1. **Pin tasks to cores**: Use `xTaskCreatePinnedToCore()` for predictable performance
2. **Minimize context switches**: Batch operations when possible
3. **Use task notifications**: Faster than semaphores for simple synchronization
4. **Static allocation**: Avoid heap fragmentation in long-running systems
5. **Profiling**: Use `vTaskList()` and `vTaskGetRunTimeStats()` for analysis
