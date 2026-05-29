#!/bin/bash
# ESP-IDF Component Generator Script
# Creates a new ESP-IDF component with proper structure

set -e

# Check if component name provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <component_name> [output_dir]"
    echo "Example: $0 my_sensor"
    echo "Example: $0 my_sensor ./components"
    exit 1
fi

COMPONENT_NAME=$1
OUTPUT_DIR=${2:-.}

# Validate component name
if [[ ! $COMPONENT_NAME =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo "Error: Component name must start with lowercase letter and contain only lowercase letters, numbers, and underscores"
    exit 1
fi

COMPONENT_DIR="$OUTPUT_DIR/$COMPONENT_NAME"

# Check if component already exists
if [ -d "$COMPONENT_DIR" ]; then
    echo "Error: Component directory already exists: $COMPONENT_DIR"
    exit 1
fi

echo "Creating ESP-IDF component: $COMPONENT_NAME"

# Create directory structure
mkdir -p "$COMPONENT_DIR"/{include,src,test}

# Create CMakeLists.txt
cat > "$COMPONENT_DIR/CMakeLists.txt" <<EOF
idf_component_register(
    SRCS "src/${COMPONENT_NAME}.c"
    INCLUDE_DIRS "include"
    REQUIRES driver esp_timer
)

# Optional: Add tests
# if(CONFIG_${COMPONENT_NAME^^}_ENABLE_TESTS)
#     idf_component_get_property(main_lib \${COMPONENT_NAME} COMPONENT_LIB)
#     idf_component_register(
#         SRCS "test/test_${COMPONENT_NAME}.c"
#         INCLUDE_DIRS "include"
#         WHOLE_ARCHIVE
#         PRIV_REQUIRES unity \${main_lib}
#     )
# endif()
EOF

# Create header file
cat > "$COMPONENT_DIR/include/${COMPONENT_NAME}.h" <<EOF
/**
 * @file ${COMPONENT_NAME}.h
 * @brief ${COMPONENT_NAME} component interface
 */

#ifndef ${COMPONENT_NAME^^}_H
#define ${COMPONENT_NAME^^}_H

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialize ${COMPONENT_NAME} component
 *
 * @return ESP_OK on success
 */
esp_err_t ${COMPONENT_NAME}_init(void);

/**
 * @brief Deinitialize ${COMPONENT_NAME} component
 *
 * @return ESP_OK on success
 */
esp_err_t ${COMPONENT_NAME}_deinit(void);

#ifdef __cplusplus
}
#endif

#endif // ${COMPONENT_NAME^^}_H
EOF

# Create source file
cat > "$COMPONENT_DIR/src/${COMPONENT_NAME}.c" <<EOF
/**
 * @file ${COMPONENT_NAME}.c
 * @brief ${COMPONENT_NAME} component implementation
 */

#include "${COMPONENT_NAME}.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "${COMPONENT_NAME^^}";

static bool is_initialized = false;

esp_err_t ${COMPONENT_NAME}_init(void) {
    if (is_initialized) {
        ESP_LOGW(TAG, "Already initialized");
        return ESP_OK;
    }

    ESP_LOGI(TAG, "Initializing ${COMPONENT_NAME}");

    // TODO: Add initialization code here

    is_initialized = true;
    ESP_LOGI(TAG, "Initialized successfully");

    return ESP_OK;
}

esp_err_t ${COMPONENT_NAME}_deinit(void) {
    if (!is_initialized) {
        ESP_LOGW(TAG, "Not initialized");
        return ESP_OK;
    }

    ESP_LOGI(TAG, "Deinitializing ${COMPONENT_NAME}");

    // TODO: Add deinitialization code here

    is_initialized = false;
    ESP_LOGI(TAG, "Deinitialized successfully");

    return ESP_OK;
}
EOF

# Create test file
cat > "$COMPONENT_DIR/test/test_${COMPONENT_NAME}.c" <<EOF
/**
 * @file test_${COMPONENT_NAME}.c
 * @brief Unit tests for ${COMPONENT_NAME} component
 */

#include "unity.h"
#include "${COMPONENT_NAME}.h"
#include "esp_log.h"

static const char *TAG = "TEST_${COMPONENT_NAME^^}";

void setUp(void) {
    // This is run before EACH test
}

void tearDown(void) {
    // This is run after EACH test
}

TEST_CASE("${COMPONENT_NAME} initialization", "[${COMPONENT_NAME}]") {
    esp_err_t ret = ${COMPONENT_NAME}_init();
    TEST_ASSERT_EQUAL(ESP_OK, ret);

    ret = ${COMPONENT_NAME}_deinit();
    TEST_ASSERT_EQUAL(ESP_OK, ret);
}

TEST_CASE("${COMPONENT_NAME} double initialization", "[${COMPONENT_NAME}]") {
    esp_err_t ret = ${COMPONENT_NAME}_init();
    TEST_ASSERT_EQUAL(ESP_OK, ret);

    // Second init should succeed but warn
    ret = ${COMPONENT_NAME}_init();
    TEST_ASSERT_EQUAL(ESP_OK, ret);

    ret = ${COMPONENT_NAME}_deinit();
    TEST_ASSERT_EQUAL(ESP_OK, ret);
}
EOF

# Create README.md
cat > "$COMPONENT_DIR/README.md" <<EOF
# ${COMPONENT_NAME}

## Overview

Brief description of what this component does.

## Features

- Feature 1
- Feature 2
- Feature 3

## Usage

\`\`\`c
#include "${COMPONENT_NAME}.h"

void app_main(void) {
    esp_err_t ret = ${COMPONENT_NAME}_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initialize ${COMPONENT_NAME}");
        return;
    }

    // Use component here

    ${COMPONENT_NAME}_deinit();
}
\`\`\`

## Configuration

Add to \`sdkconfig\`:

\`\`\`
CONFIG_${COMPONENT_NAME^^}_ENABLE=y
\`\`\`

## Dependencies

- ESP-IDF v5.1 or later
- driver
- esp_timer

## Testing

Run unit tests:

\`\`\`bash
idf.py test
\`\`\`

## License

Your license here
EOF

# Create optional Kconfig file
cat > "$COMPONENT_DIR/Kconfig" <<EOF
menu "${COMPONENT_NAME} Configuration"

    config ${COMPONENT_NAME^^}_ENABLE
        bool "Enable ${COMPONENT_NAME} component"
        default y
        help
            Enable the ${COMPONENT_NAME} component.

    config ${COMPONENT_NAME^^}_ENABLE_TESTS
        bool "Enable ${COMPONENT_NAME} tests"
        default n
        depends on ${COMPONENT_NAME^^}_ENABLE
        help
            Enable unit tests for ${COMPONENT_NAME} component.

endmenu
EOF

echo "✓ Component created successfully at: $COMPONENT_DIR"
echo ""
echo "Structure:"
tree "$COMPONENT_DIR" 2>/dev/null || find "$COMPONENT_DIR" -type f | sed 's|^|  |'
echo ""
echo "Next steps:"
echo "  1. Edit $COMPONENT_DIR/src/${COMPONENT_NAME}.c to implement functionality"
echo "  2. Update $COMPONENT_DIR/include/${COMPONENT_NAME}.h with your API"
echo "  3. Add component to your project's CMakeLists.txt"
echo "  4. Run: idf.py build"
