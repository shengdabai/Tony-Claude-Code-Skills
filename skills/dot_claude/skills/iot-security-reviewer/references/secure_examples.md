# Secure Implementation Examples

This document provides code examples and patterns for implementing common security features in IoT devices, with a focus on ESP32 and embedded systems.

## Secure WiFi Configuration Storage

### ESP32 NVS (Non-Volatile Storage) with Encryption

```cpp
#include "nvs_flash.h"
#include "nvs.h"
#include "esp_log.h"

static const char* TAG = "SecureStorage";

// Initialize NVS with encryption
esp_err_t init_secure_nvs() {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    return ret;
}

// Store WiFi credentials securely
esp_err_t store_wifi_credentials(const char* ssid, const char* password) {
    nvs_handle_t nvs_handle;
    esp_err_t err;

    // Open NVS namespace with read/write access
    err = nvs_open("wifi_config", NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error opening NVS: %s", esp_err_to_name(err));
        return err;
    }

    // Store SSID
    err = nvs_set_str(nvs_handle, "ssid", ssid);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error storing SSID: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }

    // Store password (will be encrypted by NVS if encryption is enabled)
    err = nvs_set_str(nvs_handle, "password", password);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error storing password: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }

    // Commit changes
    err = nvs_commit(nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error committing to NVS: %s", esp_err_to_name(err));
    }

    nvs_close(nvs_handle);

    // Zero out password from stack memory
    memset((void*)password, 0, strlen(password));

    return err;
}

// Retrieve WiFi credentials securely
esp_err_t get_wifi_credentials(char* ssid, size_t ssid_len,
                                char* password, size_t pass_len) {
    nvs_handle_t nvs_handle;
    esp_err_t err;

    err = nvs_open("wifi_config", NVS_READONLY, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error opening NVS: %s", esp_err_to_name(err));
        return err;
    }

    // Get SSID
    err = nvs_get_str(nvs_handle, "ssid", ssid, &ssid_len);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error reading SSID: %s", esp_err_to_name(err));
        nvs_close(nvs_handle);
        return err;
    }

    // Get password
    err = nvs_get_str(nvs_handle, "password", password, &pass_len);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Error reading password: %s", esp_err_to_name(err));
    }

    nvs_close(nvs_handle);
    return err;
}
```

### Enable Flash Encryption (menuconfig)

```
# In platformio.ini or via menuconfig
build_flags =
    -DCONFIG_SECURE_FLASH_ENC_ENABLED=1
    -DCONFIG_SECURE_BOOT_ENABLED=1
```

## MQTT TLS Configuration with Certificate Validation

### ESP32 MQTT over TLS with Certificate Pinning

```cpp
#include "mqtt_client.h"
#include "esp_log.h"

static const char* TAG = "MQTT_TLS";

// Root CA certificate (replace with your CA cert)
extern const uint8_t mqtt_ca_cert_pem_start[] asm("_binary_mqtt_ca_cert_pem_start");
extern const uint8_t mqtt_ca_cert_pem_end[] asm("_binary_mqtt_ca_cert_pem_end");

// Client certificate for mutual TLS
extern const uint8_t mqtt_client_cert_pem_start[] asm("_binary_mqtt_client_cert_pem_start");
extern const uint8_t mqtt_client_cert_pem_end[] asm("_binary_mqtt_client_cert_pem_end");

// Client private key
extern const uint8_t mqtt_client_key_pem_start[] asm("_binary_mqtt_client_key_pem_start");
extern const uint8_t mqtt_client_key_pem_end[] asm("_binary_mqtt_client_key_pem_end");

esp_mqtt_client_handle_t mqtt_client;

void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                        int32_t event_id, void *event_data) {
    esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)event_data;

    switch (event->event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "MQTT_EVENT_CONNECTED");
            break;
        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGI(TAG, "MQTT_EVENT_DISCONNECTED");
            break;
        case MQTT_EVENT_ERROR:
            ESP_LOGE(TAG, "MQTT_EVENT_ERROR");
            if (event->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
                ESP_LOGE(TAG, "TLS error: 0x%x", event->error_handle->esp_tls_last_esp_err);
            }
            break;
        default:
            break;
    }
}

esp_err_t init_secure_mqtt() {
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker = {
            .address = {
                .uri = "mqtts://mqtt.example.com:8883",  // Note: mqtts://
            },
            .verification = {
                .certificate = (const char *)mqtt_ca_cert_pem_start,
                .certificate_len = mqtt_ca_cert_pem_end - mqtt_ca_cert_pem_start,
                // Enable certificate verification
                .skip_cert_common_name_check = false,
            },
        },
        .credentials = {
            .username = "device_username",
            .authentication = {
                .certificate = (const char *)mqtt_client_cert_pem_start,
                .certificate_len = mqtt_client_cert_pem_end - mqtt_client_cert_pem_start,
                .key = (const char *)mqtt_client_key_pem_start,
                .key_len = mqtt_client_key_pem_end - mqtt_client_key_pem_start,
            },
        },
        .session = {
            .protocol_ver = MQTT_PROTOCOL_V_3_1_1,
            .keepalive = 120,
        },
    };

    mqtt_client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(mqtt_client, ESP_EVENT_ANY_ID,
                                   mqtt_event_handler, NULL);

    return esp_mqtt_client_start(mqtt_client);
}
```

### CMakeLists.txt to embed certificates

```cmake
target_add_binary_data(my_project.elf "certs/mqtt_ca_cert.pem" TEXT)
target_add_binary_data(my_project.elf "certs/mqtt_client_cert.pem" TEXT)
target_add_binary_data(my_project.elf "certs/mqtt_client_key.pem" TEXT)
```

## BLE Secure Bonding and Pairing

### ESP32 BLE with Secure Simple Pairing

```cpp
#include "esp_gap_ble_api.h"
#include "esp_gatts_api.h"
#include "esp_bt_main.h"
#include "esp_log.h"

static const char* TAG = "BLE_Security";

// Security parameters
static esp_ble_auth_req_t auth_req = ESP_LE_AUTH_REQ_SC_MITM_BOND;
static esp_ble_io_cap_t iocap = ESP_IO_CAP_OUT;  // Display only
static uint8_t key_size = 16;  // Max encryption key size
static uint8_t init_key = ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK;
static uint8_t rsp_key = ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK;
static uint32_t passkey = 123456;  // Will be displayed to user

void gap_event_handler(esp_gap_ble_cb_event_t event,
                       esp_ble_gap_cb_param_t *param) {
    switch (event) {
        case ESP_GAP_BLE_AUTH_CMPL_EVT:
            if (param->ble_security.auth_cmpl.success) {
                ESP_LOGI(TAG, "BLE pairing successful");
                // Device is now bonded
            } else {
                ESP_LOGE(TAG, "BLE pairing failed, status: %d",
                        param->ble_security.auth_cmpl.fail_reason);
            }
            break;

        case ESP_GAP_BLE_PASSKEY_NOTIF_EVT:
            // Display this passkey to the user
            ESP_LOGI(TAG, "Passkey: %06" PRIu32, param->ble_security.key_notif.passkey);
            break;

        case ESP_GAP_BLE_NC_REQ_EVT:
            // Numeric comparison request
            ESP_LOGI(TAG, "Numeric comparison: %06" PRIu32,
                    param->ble_security.key_notif.passkey);
            esp_ble_confirm_reply(param->ble_security.ble_req.bd_addr, true);
            break;

        case ESP_GAP_BLE_REMOVE_BOND_DEV_COMPLETE_EVT:
            ESP_LOGI(TAG, "Bond device removed");
            break;

        default:
            break;
    }
}

esp_err_t init_ble_security() {
    esp_err_t ret;

    // Set security parameters
    ret = esp_ble_gap_set_security_param(ESP_BLE_SM_AUTHEN_REQ_MODE,
                                         &auth_req, sizeof(uint8_t));
    if (ret) {
        ESP_LOGE(TAG, "Set security auth req failed: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = esp_ble_gap_set_security_param(ESP_BLE_SM_IOCAP_MODE,
                                         &iocap, sizeof(uint8_t));
    if (ret) {
        ESP_LOGE(TAG, "Set security IO cap failed: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = esp_ble_gap_set_security_param(ESP_BLE_SM_MAX_KEY_SIZE,
                                         &key_size, sizeof(uint8_t));
    if (ret) {
        ESP_LOGE(TAG, "Set security key size failed: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = esp_ble_gap_set_security_param(ESP_BLE_SM_SET_INIT_KEY,
                                         &init_key, sizeof(uint8_t));
    if (ret) {
        ESP_LOGE(TAG, "Set init key failed: %s", esp_err_to_name(ret));
        return ret;
    }

    ret = esp_ble_gap_set_security_param(ESP_BLE_SM_SET_RSP_KEY,
                                         &rsp_key, sizeof(uint8_t));
    if (ret) {
        ESP_LOGE(TAG, "Set response key failed: %s", esp_err_to_name(ret));
        return ret;
    }

    // Register GAP callback
    esp_ble_gap_register_callback(gap_event_handler);

    return ESP_OK;
}
```

## Secure OTA Update Verification

### ESP32 OTA with Signature Verification

```cpp
#include "esp_ota_ops.h"
#include "esp_secure_boot.h"
#include "esp_log.h"
#include "esp_http_client.h"

static const char* TAG = "Secure_OTA";

// Server certificate for HTTPS OTA
extern const uint8_t server_cert_pem_start[] asm("_binary_server_cert_pem_start");
extern const uint8_t server_cert_pem_end[] asm("_binary_server_cert_pem_end");

esp_err_t perform_secure_ota(const char* url) {
    esp_err_t err;
    esp_ota_handle_t ota_handle = 0;
    const esp_partition_t *update_partition = NULL;

    ESP_LOGI(TAG, "Starting secure OTA update");

    // Get next OTA partition
    update_partition = esp_ota_get_next_update_partition(NULL);
    if (update_partition == NULL) {
        ESP_LOGE(TAG, "No OTA partition found");
        return ESP_FAIL;
    }

    ESP_LOGI(TAG, "Writing to partition: %s", update_partition->label);

    // Configure HTTP client with TLS
    esp_http_client_config_t config = {
        .url = url,
        .cert_pem = (char *)server_cert_pem_start,
        .timeout_ms = 30000,
        .keep_alive_enable = true,
    };

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        ESP_LOGE(TAG, "Failed to initialize HTTP client");
        return ESP_FAIL;
    }

    err = esp_http_client_open(client, 0);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to open HTTP connection: %s", esp_err_to_name(err));
        esp_http_client_cleanup(client);
        return err;
    }

    int content_length = esp_http_client_fetch_headers(client);
    if (content_length <= 0) {
        ESP_LOGE(TAG, "Invalid content length");
        esp_http_client_close(client);
        esp_http_client_cleanup(client);
        return ESP_FAIL;
    }

    // Begin OTA update
    err = esp_ota_begin(update_partition, content_length, &ota_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "OTA begin failed: %s", esp_err_to_name(err));
        esp_http_client_close(client);
        esp_http_client_cleanup(client);
        return err;
    }

    // Download and write firmware
    int binary_file_length = 0;
    char ota_write_data[1024];

    while (1) {
        int data_read = esp_http_client_read(client, ota_write_data, sizeof(ota_write_data));
        if (data_read < 0) {
            ESP_LOGE(TAG, "Error reading HTTP stream");
            err = ESP_FAIL;
            break;
        } else if (data_read > 0) {
            err = esp_ota_write(ota_handle, (const void *)ota_write_data, data_read);
            if (err != ESP_OK) {
                ESP_LOGE(TAG, "OTA write failed: %s", esp_err_to_name(err));
                break;
            }
            binary_file_length += data_read;
            ESP_LOGD(TAG, "Written %d bytes", binary_file_length);
        } else if (data_read == 0) {
            ESP_LOGI(TAG, "Connection closed, all data received");
            break;
        }
    }

    esp_http_client_close(client);
    esp_http_client_cleanup(client);

    if (err != ESP_OK) {
        esp_ota_abort(ota_handle);
        return err;
    }

    // End OTA (validates signature if secure boot is enabled)
    err = esp_ota_end(ota_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "OTA end failed: %s", esp_err_to_name(err));
        return err;
    }

    // Set boot partition
    err = esp_ota_set_boot_partition(update_partition);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Set boot partition failed: %s", esp_err_to_name(err));
        return err;
    }

    ESP_LOGI(TAG, "OTA update successful, restarting...");
    esp_restart();

    return ESP_OK;
}
```

## API Key Rotation Strategy

### Secure API Key Management

```cpp
#include "nvs_flash.h"
#include "esp_log.h"
#include "mbedtls/sha256.h"

static const char* TAG = "APIKey";

typedef struct {
    char key[64];
    time_t created_at;
    time_t expires_at;
    uint32_t version;
} api_key_t;

#define KEY_ROTATION_DAYS 90
#define KEY_NAMESPACE "api_keys"

// Generate API key hash for validation
void generate_key_hash(const char* key, uint8_t* hash) {
    mbedtls_sha256_context ctx;
    mbedtls_sha256_init(&ctx);
    mbedtls_sha256_starts(&ctx, 0);  // 0 = SHA256
    mbedtls_sha256_update(&ctx, (const unsigned char*)key, strlen(key));
    mbedtls_sha256_finish(&ctx, hash);
    mbedtls_sha256_free(&ctx);
}

// Store API key securely
esp_err_t store_api_key(const api_key_t* key) {
    nvs_handle_t nvs_handle;
    esp_err_t err;

    err = nvs_open(KEY_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) return err;

    // Store current key
    err = nvs_set_blob(nvs_handle, "current_key", key, sizeof(api_key_t));
    if (err != ESP_OK) {
        nvs_close(nvs_handle);
        return err;
    }

    err = nvs_commit(nvs_handle);
    nvs_close(nvs_handle);

    return err;
}

// Check if key rotation is needed
bool needs_rotation(const api_key_t* key) {
    time_t now = time(NULL);
    time_t age = now - key->created_at;
    return (age > (KEY_ROTATION_DAYS * 24 * 60 * 60));
}

// Rotate API key
esp_err_t rotate_api_key(const char* new_key) {
    api_key_t key;
    nvs_handle_t nvs_handle;
    esp_err_t err;

    // Get current key to save as previous
    err = nvs_open(KEY_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) return err;

    size_t required_size = sizeof(api_key_t);
    api_key_t prev_key;
    err = nvs_get_blob(nvs_handle, "current_key", &prev_key, &required_size);

    if (err == ESP_OK) {
        // Save previous key for grace period
        nvs_set_blob(nvs_handle, "previous_key", &prev_key, sizeof(api_key_t));
    }

    // Create new key
    strncpy(key.key, new_key, sizeof(key.key) - 1);
    key.created_at = time(NULL);
    key.expires_at = key.created_at + (KEY_ROTATION_DAYS * 24 * 60 * 60);
    key.version = prev_key.version + 1;

    // Store new key
    err = nvs_set_blob(nvs_handle, "current_key", &key, sizeof(api_key_t));
    if (err == ESP_OK) {
        err = nvs_commit(nvs_handle);
    }

    nvs_close(nvs_handle);

    // Zero out key from memory
    memset(&key, 0, sizeof(api_key_t));
    memset((void*)new_key, 0, strlen(new_key));

    ESP_LOGI(TAG, "API key rotated successfully");

    return err;
}

// Validate API key (accepts current and previous for grace period)
bool validate_api_key(const char* provided_key) {
    nvs_handle_t nvs_handle;
    esp_err_t err;
    bool valid = false;

    err = nvs_open(KEY_NAMESPACE, NVS_READONLY, &nvs_handle);
    if (err != ESP_OK) return false;

    size_t required_size = sizeof(api_key_t);
    api_key_t current_key, previous_key;

    // Check current key
    err = nvs_get_blob(nvs_handle, "current_key", &current_key, &required_size);
    if (err == ESP_OK) {
        uint8_t provided_hash[32], stored_hash[32];
        generate_key_hash(provided_key, provided_hash);
        generate_key_hash(current_key.key, stored_hash);

        if (memcmp(provided_hash, stored_hash, 32) == 0) {
            valid = true;
        }
    }

    // Check previous key (grace period)
    if (!valid) {
        err = nvs_get_blob(nvs_handle, "previous_key", &previous_key, &required_size);
        if (err == ESP_OK) {
            uint8_t provided_hash[32], stored_hash[32];
            generate_key_hash(provided_key, provided_hash);
            generate_key_hash(previous_key.key, stored_hash);

            if (memcmp(provided_hash, stored_hash, 32) == 0) {
                ESP_LOGW(TAG, "Using deprecated API key, please update");
                valid = true;
            }
        }
    }

    nvs_close(nvs_handle);

    // Zero out sensitive data
    memset(&current_key, 0, sizeof(api_key_t));
    memset(&previous_key, 0, sizeof(api_key_t));

    return valid;
}
```

## Security Best Practices Summary

### Memory Safety
- Always zero sensitive data after use
- Use bounds-checked functions (strncpy, snprintf)
- Enable stack protection and ASLR where available
- Validate array indices before access

### Crypto Implementation
- Use proven libraries (mbedTLS, OpenSSL)
- Never implement custom crypto algorithms
- Use constant-time comparison for secrets
- Generate truly random keys (hardware RNG)

### Input Validation
- Validate all external input
- Sanitize data before processing
- Use whitelists over blacklists
- Implement length checks

### Error Handling
- Don't leak information in error messages
- Log security events appropriately
- Fail securely (deny by default)
- Handle all error conditions

### Secure Coding
- Principle of least privilege
- Defense in depth
- Assume all input is malicious
- Keep security simple
