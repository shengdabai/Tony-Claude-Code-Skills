# Advanced WiFi & BLE Configuration

## WiFi Advanced Patterns

### WiFi Power Save Modes

```c
// Modem sleep (WiFi sleeps between DTIM beacons)
esp_wifi_set_ps(WIFI_PS_MIN_MODEM);  // Minimal power save
esp_wifi_set_ps(WIFI_PS_MAX_MODEM);  // Maximum power save

// Listen interval (how many beacons to skip)
wifi_config_t wifi_config = {
    .sta = {
        .listen_interval = 3,  // Wake every 3 beacons (default)
    },
};
```

### WiFi Event Handling (Complete)

```c
static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data) {
    switch (event_id) {
        case WIFI_EVENT_STA_START:
            esp_wifi_connect();
            break;

        case WIFI_EVENT_STA_CONNECTED:
            ESP_LOGI("WIFI", "Connected to AP");
            break;

        case WIFI_EVENT_STA_DISCONNECTED: {
            wifi_event_sta_disconnected_t *event =
                (wifi_event_sta_disconnected_t *)event_data;
            ESP_LOGW("WIFI", "Disconnected, reason: %d", event->reason);

            // Reason codes
            switch (event->reason) {
                case WIFI_REASON_AUTH_EXPIRE:
                case WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT:
                case WIFI_REASON_BEACON_TIMEOUT:
                case WIFI_REASON_HANDSHAKE_TIMEOUT:
                    // Reconnect immediately
                    esp_wifi_connect();
                    break;

                default:
                    // Backoff before retry
                    vTaskDelay(pdMS_TO_TICKS(5000));
                    esp_wifi_connect();
                    break;
            }
            break;
        }

        case WIFI_EVENT_STA_AUTHMODE_CHANGE:
            ESP_LOGW("WIFI", "AP authmode changed");
            break;

        default:
            break;
    }
}

static void ip_event_handler(void *arg, esp_event_base_t event_base,
                            int32_t event_id, void *event_data) {
    if (event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        ESP_LOGI("IP", "Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
        ESP_LOGI("IP", "Netmask: " IPSTR, IP2STR(&event->ip_info.netmask));
        ESP_LOGI("IP", "Gateway: " IPSTR, IP2STR(&event->ip_info.gw));
    } else if (event_id == IP_EVENT_STA_LOST_IP) {
        ESP_LOGW("IP", "Lost IP address");
    }
}
```

### WiFi Scanning

```c
esp_err_t scan_wifi_networks(void) {
    wifi_scan_config_t scan_config = {
        .ssid = NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = false,
        .scan_type = WIFI_SCAN_TYPE_ACTIVE,
        .scan_time = {
            .active = {
                .min = 100,
                .max = 300
            }
        }
    };

    ESP_ERROR_CHECK(esp_wifi_scan_start(&scan_config, true));  // Blocking

    uint16_t ap_count = 0;
    esp_wifi_scan_get_ap_num(&ap_count);

    wifi_ap_record_t *ap_list = malloc(sizeof(wifi_ap_record_t) * ap_count);
    ESP_ERROR_CHECK(esp_wifi_scan_get_ap_records(&ap_count, ap_list));

    for (int i = 0; i < ap_count; i++) {
        ESP_LOGI("SCAN", "SSID: %s, RSSI: %d, Channel: %d",
                ap_list[i].ssid, ap_list[i].rssi, ap_list[i].primary);
    }

    free(ap_list);
    return ESP_OK;
}
```

### WiFi AP Mode

```c
esp_err_t wifi_init_ap(void) {
    esp_netif_create_default_wifi_ap();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    wifi_config_t wifi_config = {
        .ap = {
            .ssid = "ESP32_AP",
            .ssid_len = strlen("ESP32_AP"),
            .channel = 1,
            .password = "password123",
            .max_connection = 4,
            .authmode = WIFI_AUTH_WPA2_PSK,
            .pmf_cfg = {
                .required = false,
            },
        },
    };

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    return ESP_OK;
}
```

## BLE Advanced Patterns

### BLE GATT Server (Complete)

```c
#include "esp_gatts_api.h"
#include "esp_gap_ble_api.h"

#define PROFILE_NUM  1
#define PROFILE_APP_IDX  0

struct gatts_profile_inst {
    esp_gatts_cb_t gatts_cb;
    uint16_t gatts_if;
    uint16_t app_id;
    uint16_t conn_id;
    uint16_t service_handle;
    esp_gatt_srvc_id_t service_id;
    uint16_t char_handle;
    esp_bt_uuid_t char_uuid;
    esp_gatt_perm_t perm;
    esp_gatt_char_prop_t property;
    uint16_t descr_handle;
    esp_bt_uuid_t descr_uuid;
};

static struct gatts_profile_inst profile_tab[PROFILE_NUM];

static void gap_event_handler(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
    switch (event) {
        case ESP_GAP_BLE_ADV_DATA_SET_COMPLETE_EVT:
            esp_ble_gap_start_advertising(&adv_params);
            break;

        case ESP_GAP_BLE_ADV_START_COMPLETE_EVT:
            if (param->adv_start_cmpl.status == ESP_BT_STATUS_SUCCESS) {
                ESP_LOGI("GAP", "Advertising started");
            }
            break;

        default:
            break;
    }
}

static void gatts_profile_event_handler(esp_gatts_cb_event_t event,
                                       esp_gatt_if_t gatts_if,
                                       esp_ble_gatts_cb_param_t *param) {
    switch (event) {
        case ESP_GATTS_REG_EVT:
            // Create service
            esp_ble_gatts_create_service(gatts_if, &service_id, 4);
            break;

        case ESP_GATTS_CREATE_EVT:
            profile_tab[PROFILE_APP_IDX].service_handle = param->create.service_handle;

            // Start service
            esp_ble_gatts_start_service(param->create.service_handle);

            // Add characteristic
            esp_ble_gatts_add_char(param->create.service_handle,
                                  &char_uuid, perm, property, NULL, NULL);
            break;

        case ESP_GATTS_ADD_CHAR_EVT:
            profile_tab[PROFILE_APP_IDX].char_handle = param->add_char.attr_handle;
            break;

        case ESP_GATTS_CONNECT_EVT:
            profile_tab[PROFILE_APP_IDX].conn_id = param->connect.conn_id;
            ESP_LOGI("GATTS", "Client connected");

            // Update connection parameters for lower latency
            esp_ble_conn_update_params_t conn_params = {
                .bda = {0},
                .min_int = 6,   // 7.5ms
                .max_int = 12,  // 15ms
                .latency = 0,
                .timeout = 400  // 4s
            };
            memcpy(conn_params.bda, param->connect.remote_bda, sizeof(esp_bd_addr_t));
            esp_ble_gap_update_conn_params(&conn_params);
            break;

        case ESP_GATTS_DISCONNECT_EVT:
            ESP_LOGI("GATTS", "Client disconnected");
            esp_ble_gap_start_advertising(&adv_params);
            break;

        default:
            break;
    }
}
```

### BLE GATT Client

```c
static void gattc_event_handler(esp_gattc_cb_event_t event,
                               esp_gatt_if_t gattc_if,
                               esp_ble_gattc_cb_param_t *param) {
    switch (event) {
        case ESP_GATTC_REG_EVT:
            // Start scanning
            esp_ble_gap_start_scanning(30);
            break;

        case ESP_GATTC_OPEN_EVT:
            if (param->open.status == ESP_GATT_OK) {
                ESP_LOGI("GATTC", "Connected");

                // Search for services
                esp_ble_gattc_search_service(gattc_if, param->open.conn_id, NULL);
            }
            break;

        case ESP_GATTC_SEARCH_RES_EVT:
            // Service found
            ESP_LOGI("GATTC", "Service UUID: %x", param->search_res.srvc_id.uuid.uuid.uuid16);
            break;

        case ESP_GATTC_SEARCH_CMPL_EVT:
            // Get characteristic
            esp_ble_gattc_get_characteristic(gattc_if, param->search_cmpl.conn_id,
                                            &service_id, NULL);
            break;

        case ESP_GATTC_GET_CHAR_EVT:
            // Characteristic found
            break;

        case ESP_GATTC_READ_CHAR_EVT:
            ESP_LOGI("GATTC", "Read value: %.*s",
                    param->read.value_len, param->read.value);
            break;

        default:
            break;
    }
}
```

### BLE Security & Bonding

```c
esp_ble_auth_req_t auth_req = ESP_LE_AUTH_REQ_SC_MITM_BOND;
esp_ble_io_cap_t iocap = ESP_IO_CAP_OUT;  // Display only
uint8_t key_size = 16;
uint8_t init_key = ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK;
uint8_t rsp_key = ESP_BLE_ENC_KEY_MASK | ESP_BLE_ID_KEY_MASK;

esp_ble_gap_set_security_param(ESP_BLE_SM_AUTHEN_REQ_MODE, &auth_req, sizeof(uint8_t));
esp_ble_gap_set_security_param(ESP_BLE_SM_IOCAP_MODE, &iocap, sizeof(uint8_t));
esp_ble_gap_set_security_param(ESP_BLE_SM_MAX_KEY_SIZE, &key_size, sizeof(uint8_t));
esp_ble_gap_set_security_param(ESP_BLE_SM_SET_INIT_KEY, &init_key, sizeof(uint8_t));
esp_ble_gap_set_security_param(ESP_BLE_SM_SET_RSP_KEY, &rsp_key, sizeof(uint8_t));

// Passkey entry
static void gap_event_handler(esp_gap_ble_cb_event_t event, esp_ble_gap_cb_param_t *param) {
    switch (event) {
        case ESP_GAP_BLE_PASSKEY_REQ_EVT:
            ESP_LOGI("SEC", "Passkey request");
            esp_ble_passkey_reply(param->ble_security.ble_req.bd_addr, true, 123456);
            break;

        case ESP_GAP_BLE_AUTH_CMPL_EVT:
            if (param->ble_security.auth_cmpl.success) {
                ESP_LOGI("SEC", "Pairing successful");
            } else {
                ESP_LOGE("SEC", "Pairing failed: %d", param->ble_security.auth_cmpl.fail_reason);
            }
            break;

        default:
            break;
    }
}
```

## Coexistence (WiFi + BLE)

### Coexistence Configuration

```c
#include "esp_coexist.h"

void init_coexistence(void) {
    // Enable coexistence
    esp_coex_preference_set(ESP_COEX_PREFER_BALANCE);

    // Or prioritize WiFi
    esp_coex_preference_set(ESP_COEX_PREFER_WIFI);

    // Or prioritize BLE
    esp_coex_preference_set(ESP_COEX_PREFER_BT);
}
```

### Best Practices for Coexistence

1. **WiFi station + BLE**: Works well with balanced preference
2. **WiFi AP + BLE**: Increase BLE connection interval
3. **Scanning**: Avoid BLE scanning during critical WiFi operations
4. **Advertising**: Use non-connectable advertising for beacons
5. **Connection intervals**: BLE interval should be multiple of WiFi DTIM

## Troubleshooting

### WiFi Connection Failures

**Auth timeout**:
```c
// Increase timeout
wifi_config_t wifi_config = {
    .sta = {
        .scan_method = WIFI_ALL_CHANNEL_SCAN,
        .sort_method = WIFI_CONNECT_AP_BY_SIGNAL,
    },
};
```

**Weak signal**:
```c
// Set min RSSI threshold
esp_wifi_set_rssi_threshold(-70);
```

**Channel congestion**:
```c
// Scan all channels
wifi_scan_config_t scan_config = {
    .scan_type = WIFI_SCAN_TYPE_ACTIVE,
    .scan_time.active.min = 100,
    .scan_time.active.max = 300,
};
```

### BLE Connection Issues

**Connection timeout**:
```c
// Increase scan window
esp_ble_gap_set_scan_params(&scan_params);
scan_params.scan_window = 0x30;  // 30ms
scan_params.scan_interval = 0x40;  // 40ms
```

**Frequent disconnections**:
```c
// Adjust connection interval
esp_ble_conn_update_params_t conn_params = {
    .min_int = 12,   // 15ms
    .max_int = 24,   // 30ms
    .latency = 0,
    .timeout = 400,
};
esp_ble_gap_update_conn_params(&conn_params);
```

**MTU size issues**:
```c
// Negotiate larger MTU
esp_ble_gatt_set_local_mtu(512);
```

### Performance Optimization

**WiFi throughput**:
- Use WiFi QoS (WMM)
- Enable AMPDU/AMSDU
- Optimize TCP window size
- Use UDP for real-time data

**BLE data rate**:
- Maximize MTU (up to 512 bytes)
- Minimize connection interval
- Use write-without-response
- Batch notifications

**Power consumption**:
- Enable WiFi modem sleep
- Increase BLE connection interval
- Use BLE advertising instead of scanning
- Disable unused peripherals
