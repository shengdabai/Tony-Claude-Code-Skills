# Wireless Protocols (BLE, WiFi)

Detailed specifications for Bluetooth Low Energy and WiFi networking.

## Bluetooth Low Energy (BLE)

### Architecture Layers

```
Application
    ↓
GATT (Generic Attribute Profile)
    ↓
ATT (Attribute Protocol)
    ↓
L2CAP (Logical Link Control)
    ↓
Link Layer
    ↓
Physical Layer (2.4 GHz)
```

### GAP Roles

**Central (Master)**:
- Scans for peripherals
- Initiates connections
- Example: Android app

**Peripheral (Slave)**:
- Advertises presence
- Accepts connections
- Example: Presto device

**Broadcaster**:
- Only advertises (no connections)
- Example: Beacon

**Observer**:
- Only scans (no connections)
- Example: Beacon scanner

### GATT Hierarchy

```
Profile
  └── Service (UUID: 16-bit or 128-bit)
        ├── Characteristic (UUID + Properties + Value)
        │     ├── Descriptor (CCCD, User Description, etc.)
        │     └── Descriptor
        └── Characteristic
              └── Descriptor
```

### Example: Heart Rate Service

```
Heart Rate Service (UUID: 0x180D)
  ├── Heart Rate Measurement (UUID: 0x2A37)
  │     ├── Properties: Notify
  │     ├── Value: uint8 (BPM)
  │     └── CCCD: Enable/disable notifications
  └── Body Sensor Location (UUID: 0x2A38)
        ├── Properties: Read
        └── Value: uint8 (0=Other, 1=Chest, 2=Wrist, ...)
```

### Characteristic Properties

| Property | Description | Direction |
|----------|-------------|-----------|
| Read | Can read value | Central ← Peripheral |
| Write | Can write value (with response) | Central → Peripheral |
| Write Without Response | Can write value (no ack) | Central → Peripheral |
| Notify | Receives updates (no ack) | Central ← Peripheral |
| Indicate | Receives updates (with ack) | Central ← Peripheral |
| Broadcast | Advertised in scan response | - |

### Connection Parameters

```c
struct ble_gap_conn_params {
    uint16_t min_conn_interval;  // Units of 1.25ms
    uint16_t max_conn_interval;  // Units of 1.25ms
    uint16_t slave_latency;      // Number of events to skip
    uint16_t conn_sup_timeout;   // Units of 10ms
};
```

**Example: Fast updates (timer display)**
```c
{
    .min_conn_interval = 16,   // 16 * 1.25ms = 20ms
    .max_conn_interval = 32,   // 32 * 1.25ms = 40ms
    .slave_latency = 0,        // No skipping
    .conn_sup_timeout = 400,   // 400 * 10ms = 4s
}
```

**Example: Power saving (idle)**
```c
{
    .min_conn_interval = 160,  // 160 * 1.25ms = 200ms
    .max_conn_interval = 320,  // 320 * 1.25ms = 400ms
    .slave_latency = 4,        // Skip 4 events (saves power)
    .conn_sup_timeout = 500,   // 500 * 10ms = 5s
}
```

### Advertising

**Advertising Interval**:
- Standard: 20ms - 10.24s
- Recommended: 100ms - 1s
- Shorter interval: Faster discovery, higher power
- Longer interval: Slower discovery, lower power

**Advertising Data** (max 31 bytes):
```
Flags: 0x02, 0x01, 0x06
Name:  0x09, 0x09, "Orbit-Presto" (12 bytes)
UUID:  0x03, 0x03, 0x180D (Heart Rate Service)
Manufacturer Data: Variable
```

**Scan Response Data** (additional 31 bytes):
```
Can include more services, device info, etc.
```

### Data Throughput

**Theoretical Maximum**:
```
PHY rate: 1 Mbps
Effective: ~100 KB/s (after protocol overhead)
```

**Practical Limits**:
```
Connection interval: 20ms
MTU (Max Transmission Unit): 512 bytes
Throughput: 512 bytes / 20ms = 25.6 KB/s
```

**Optimization**:
1. Increase MTU: Negotiate higher MTU (up to 512 bytes)
2. Reduce interval: Use faster connection intervals
3. Use Write Without Response: No waiting for ACKs
4. Data compression: Compress payloads

### Security and Pairing

**Security Modes**:

| Mode | Level | Description |
|------|-------|-------------|
| 1 | 1 | No security (open) |
| 1 | 2 | Unauthenticated pairing with encryption |
| 1 | 3 | Authenticated pairing with encryption |
| 1 | 4 | Authenticated LE Secure Connections |

**Pairing Methods**:
- **Just Works**: No user interaction (no MITM protection)
- **Passkey Entry**: User enters 6-digit code
- **Numeric Comparison**: User confirms matching codes
- **Out-of-Band**: Exchange keys via NFC or QR code

**Bonding**:
Store encryption keys for future reconnections:
```c
// Enable bonding
ble_set_bonding_enabled(true);

// On reconnect, use stored keys
// (no re-pairing needed)
```

### Power Consumption

**Advertising** (depends on interval):
```
100ms interval: ~20-30 μA average
1s interval: ~2-5 μA average
```

**Connected** (depends on connection interval):
```
20ms interval: ~500-800 μA average
200ms interval: ~50-100 μA average
```

**Active data transfer**:
```
Receiving notifications: ~5-10 mA
Transmitting data: ~10-15 mA
```

### Common Issues

**Cannot discover device**:
- Advertising not started
- Advertising interval too long (try 100ms)
- Device name not in advertising data
- Bluetooth off on phone
- Too far away (>10m)

**Connection drops**:
- Weak signal (move closer)
- Connection interval too short (try longer)
- Supervision timeout too short (increase to 4-6s)
- Interference from WiFi on 2.4 GHz

**Slow data transfer**:
- MTU too small (negotiate higher MTU)
- Connection interval too long (reduce to 20-40ms)
- Using Indications instead of Notifications
- Waiting for Write Response (use Write Without Response)

---

## WiFi (802.11)

### Modes

**Station (STA)**: Connect to access point
```c
wifi_config_t wifi_config = {
    .sta = {
        .ssid = "MyNetwork",
        .password = "MyPassword",
    },
};
esp_wifi_set_mode(WIFI_MODE_STA);
esp_wifi_set_config(WIFI_IF_STA, &wifi_config);
```

**Access Point (AP)**: Act as hotspot
```c
wifi_config_t wifi_config = {
    .ap = {
        .ssid = "ESP32-AP",
        .password = "12345678",
        .max_connection = 4,
        .authmode = WIFI_AUTH_WPA2_PSK,
    },
};
esp_wifi_set_mode(WIFI_MODE_AP);
esp_wifi_set_config(WIFI_IF_AP, &wifi_config);
```

**Station + AP (APSTA)**: Both modes simultaneously
```c
esp_wifi_set_mode(WIFI_MODE_APSTA);
// Configure both STA and AP
```

### Security

**WPA2-PSK** (recommended):
```c
.authmode = WIFI_AUTH_WPA2_PSK
```

**WPA3-PSK** (newer devices):
```c
.authmode = WIFI_AUTH_WPA3_PSK
```

**Open** (insecure, testing only):
```c
.authmode = WIFI_AUTH_OPEN
```

### Connection States

```
WIFI_EVENT_STA_START
  ↓ (esp_wifi_connect())
WIFI_EVENT_STA_CONNECTING
  ↓ (success)
WIFI_EVENT_STA_CONNECTED
  ↓ (DHCP request)
IP_EVENT_STA_GOT_IP
  ↓
[Connected and ready]

  ↓ (connection lost)
WIFI_EVENT_STA_DISCONNECTED
  ↓ (auto-reconnect)
WIFI_EVENT_STA_CONNECTING
```

### Auto-Reconnection

```c
void wifi_event_handler(void* arg, esp_event_base_t event_base,
                        int32_t event_id, void* event_data) {
    if (event_id == WIFI_EVENT_STA_DISCONNECTED) {
        wifi_event_sta_disconnected_t* event =
            (wifi_event_sta_disconnected_t*)event_data;

        ESP_LOGI(TAG, "Disconnect reason: %d", event->reason);

        // Exponential backoff
        static int retry_count = 0;
        if (retry_count < 10) {
            int delay_ms = (1 << retry_count) * 100;  // 100ms, 200ms, 400ms, ...
            vTaskDelay(pdMS_TO_TICKS(delay_ms));
            esp_wifi_connect();
            retry_count++;
        }
    } else if (event_id == IP_EVENT_STA_GOT_IP) {
        retry_count = 0;  // Reset on successful connection
    }
}
```

### Power Management

**Modem Sleep** (default):
```c
esp_wifi_set_ps(WIFI_PS_MIN_MODEM);  // Light sleep between DTIM
esp_wifi_set_ps(WIFI_PS_MAX_MODEM);  // Deep sleep between DTIM
```

**No Power Saving**:
```c
esp_wifi_set_ps(WIFI_PS_NONE);  // Always on (lowest latency)
```

**DTIM Period**: How often AP sends buffered broadcast/multicast
```
DTIM 1: Wake every beacon (~100ms)
DTIM 3: Wake every 3rd beacon (~300ms)
DTIM 10: Wake every 10th beacon (~1s)
```

### Static IP Configuration

```c
// Disable DHCP client
esp_netif_dhcpc_stop(netif);

// Set static IP
esp_netif_ip_info_t ip_info;
IP4_ADDR(&ip_info.ip, 192, 168, 1, 100);
IP4_ADDR(&ip_info.gw, 192, 168, 1, 1);
IP4_ADDR(&ip_info.netmask, 255, 255, 255, 0);
esp_netif_set_ip_info(netif, &ip_info);

// Set DNS
esp_netif_dns_info_t dns;
IP4_ADDR(&dns.ip.u_addr.ip4, 8, 8, 8, 8);  // Google DNS
esp_netif_set_dns_info(netif, ESP_NETIF_DNS_MAIN, &dns);
```

### mDNS Service Discovery

**Advertise service**:
```c
mdns_init();
mdns_hostname_set("orbit-presto");
mdns_instance_name_set("Orbit Timer Display");

// Advertise MQTT broker
mdns_service_add("Orbit MQTT", "_mqtt", "_tcp", 1883, NULL, 0);

// Advertise HTTP server
mdns_txt_item_t txt_data[] = {
    {"board", "esp32"},
    {"version", "1.0"}
};
mdns_service_add("Orbit Web", "_http", "_tcp", 80, txt_data, 2);
```

**Discover services**:
```c
mdns_result_t* results = NULL;
esp_err_t err = mdns_query_ptr("_mqtt", "_tcp", 3000, 20, &results);

if (err == ESP_OK && results) {
    mdns_result_t* r = results;
    while (r) {
        printf("Found: %s at %s:%d\n",
               r->instance_name,
               ip4addr_ntoa(&r->addr->addr.u_addr.ip4),
               r->port);
        r = r->next;
    }
    mdns_query_results_free(results);
}
```

### WiFi Scan

```c
wifi_scan_config_t scan_config = {
    .ssid = NULL,  // Scan all SSIDs
    .bssid = NULL,
    .channel = 0,  // All channels
    .show_hidden = false,
    .scan_type = WIFI_SCAN_TYPE_ACTIVE,
};

esp_wifi_scan_start(&scan_config, true);  // Blocking

uint16_t ap_count = 0;
esp_wifi_scan_get_ap_num(&ap_count);

wifi_ap_record_t* ap_info =
    malloc(sizeof(wifi_ap_record_t) * ap_count);
esp_wifi_scan_get_ap_records(&ap_count, ap_info);

for (int i = 0; i < ap_count; i++) {
    printf("SSID: %s, RSSI: %d, Channel: %d, Auth: %d\n",
           ap_info[i].ssid,
           ap_info[i].rssi,
           ap_info[i].primary,
           ap_info[i].authmode);
}

free(ap_info);
```

### Channel Selection

**2.4 GHz Band**:
```
Non-overlapping channels: 1, 6, 11 (US)
Use these to avoid interference
```

**5 GHz Band**:
```
More channels available, less interference
Shorter range than 2.4 GHz
Not all devices support 5 GHz
```

### Common Issues

**Cannot connect**:
- Wrong SSID or password
- WPA3 device connecting to WPA2-only AP (or vice versa)
- MAC filtering on router
- 5 GHz AP but device only supports 2.4 GHz

**Frequent disconnections**:
- Weak signal (check RSSI < -70 dBm)
- Channel congestion (try different channel)
- Power management too aggressive
- AP configured for short lease times

**Slow connection**:
- Weak signal causing low PHY rate
- Channel congestion
- Too many devices on AP
- DNS resolution slow (try static DNS: 8.8.8.8)

**High power consumption**:
- WIFI_PS_NONE enabled
- Constant data transfer
- Poor signal requiring high TX power
- Enable modem sleep for battery devices
