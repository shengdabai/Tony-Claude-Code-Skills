# Argus-Specific Security Considerations

This document covers security considerations specific to the Argus system architecture and components.

## System Overview

Argus is a smart sensor system consisting of:
- **T-Embed devices**: ESP32-S3 based sensors with touchscreen
- **Presto gateway**: RP2350 based gateway with display and RGB lighting
- **Android app**: Mobile application for monitoring and control
- **MQTT broker**: Local network message broker
- **BLE communication**: Direct device-to-device communication

## Architecture Security

### Network Segmentation

```
Internet
   |
   | (Firewall)
   v
Home Router
   |
   +-- IoT VLAN (isolated)
   |     |
   |     +-- MQTT Broker (local only)
   |     +-- T-Embed devices
   |     +-- Presto gateway
   |
   +-- Main Network
         |
         +-- Android app (phone/tablet)
```

**Security Measures:**
- IoT devices on separate VLAN
- MQTT broker not exposed to internet
- Android app connects via local network only
- mDNS for local service discovery

### Trust Model

```
┌─────────────┐
│ Android App │ ◄──── User Authentication
└──────┬──────┘
       │ TLS + API Key
       │
┌──────▼──────┐
│ MQTT Broker │
└──────┬──────┘
       │ Username/Password + TLS
       │
┌──────▼──────────┐    BLE     ┌─────────┐
│ Presto Gateway  │ ◄────────► │ T-Embed │
└─────────────────┘  Bonded    └─────────┘
```

**Trust Boundaries:**
1. User ↔ Android App: PIN/biometric authentication
2. Android App ↔ MQTT: API key + TLS
3. MQTT ↔ Devices: Device credentials + TLS
4. Presto ↔ T-Embed: BLE bonding with passkey

## Component-Specific Security

### T-Embed (ESP32-S3) Security

#### Flash Encryption
```c
// Enable in menuconfig or platformio.ini
#define CONFIG_SECURE_FLASH_ENC_ENABLED 1
#define CONFIG_SECURE_FLASH_ENCRYPTION_MODE_RELEASE 1
```

**What it protects:**
- WiFi credentials in NVS
- MQTT credentials
- Device private keys
- Sensor calibration data

#### Secure Boot
```c
#define CONFIG_SECURE_BOOT_V2_ENABLED 1
#define CONFIG_SECURE_BOOTLOADER_MODE_RELEASE 1
```

**Protection provided:**
- Only signed firmware can boot
- Prevents firmware tampering
- Rollback protection

#### Sensor Data Security

**Privacy Considerations:**
- Temperature/humidity: Low sensitivity
- Motion detection: Medium sensitivity (occupancy tracking)
- Location data: Not collected by sensors
- Usage patterns: Should be anonymized

**Data Minimization:**
- Only send necessary data over MQTT
- Aggregate data locally where possible
- Implement data retention policies
- Clear old data periodically

### Presto Gateway (RP2350) Security

#### MicroPython Security Considerations

**Code Signing:**
- Hash validation for uploaded scripts
- Whitelist allowed modules
- Restrict filesystem access
- Disable unnecessary built-ins

```python
# Disable dangerous functions in production
import sys
sys.modules['os'].system = None  # Prevent command execution
```

#### BLE Security

**Bonding Storage:**
```python
# Store bonded device info securely
import machine
import ubinascii

def store_bond(addr, ltk):
    """Store BLE long-term key securely"""
    # Use RP2350 flash for secure storage
    # Encrypt LTK before storing
    with open('/flash/bonds.dat', 'ab') as f:
        encrypted_ltk = encrypt_ltk(ltk)  # Implement encryption
        f.write(addr + encrypted_ltk)
```

**Pairing Process:**
1. T-Embed initiates pairing
2. Presto displays 6-digit passkey on screen
3. User confirms passkey on T-Embed touchscreen
4. Secure bonding established
5. LTK stored for future connections

#### Display Security

**Information Disclosure:**
- Don't display sensitive info (passwords, keys)
- Timeout for sensitive screens
- Screen lock after inactivity
- Visible indicator when secured

### Android App Security

#### API Authentication

**JWT Token Flow:**
```kotlin
// Token-based authentication
data class AuthToken(
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: Long
)

class AuthManager {
    private val keyStore = KeyStore.getInstance("AndroidKeyStore")

    fun storeToken(token: AuthToken) {
        // Store in Android Keystore (hardware-backed)
        val encryptedToken = encryptCipher.doFinal(token.accessToken.toByteArray())
        // Save encrypted token to SharedPreferences
    }

    fun getToken(): AuthToken? {
        // Retrieve and decrypt from Keystore
        val encrypted = sharedPrefs.getString("access_token", null) ?: return null
        val decrypted = decryptCipher.doFinal(Base64.decode(encrypted, Base64.DEFAULT))
        return AuthToken(String(decrypted), "", 0)
    }
}
```

#### Secure Storage

**Android Keystore for Secrets:**
```kotlin
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties

class SecureStorage {
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    fun generateKey(alias: String) {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            "AndroidKeyStore"
        )

        val keyGenParameterSpec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true)  // Requires biometric/PIN
            .setUserAuthenticationValidityDurationSeconds(300)
            .build()

        keyGenerator.init(keyGenParameterSpec)
        keyGenerator.generateKey()
    }

    fun encrypt(alias: String, data: ByteArray): ByteArray {
        val secretKey = keyStore.getKey(alias, null) as SecretKey
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        return cipher.doFinal(data)
    }
}
```

#### Network Security Configuration

**network_security_config.xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- No cleartext traffic allowed -->
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>

    <!-- Pin MQTT broker certificate -->
    <domain-config>
        <domain includeSubdomains="false">mqtt.local</domain>
        <pin-set>
            <pin digest="SHA-256">base64EncodedPublicKeyHash==</pin>
            <!-- Backup pin -->
            <pin digest="SHA-256">backupKeyHash==</pin>
        </pin-set>
    </domain-config>
</network-security-config>
```

#### ProGuard/R8 Obfuscation

**proguard-rules.pro:**
```
# Keep security-related classes
-keep class com.example.argus.security.** { *; }

# Obfuscate everything else
-obfuscate
-repackageclasses 'o'

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}
```

### MQTT Broker Security

#### Mosquitto Configuration

**mosquitto.conf:**
```conf
# Listener configuration
listener 8883
protocol mqtt

# TLS configuration
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key

# Require certificate from clients
require_certificate true
use_identity_as_username true

# TLS version
tls_version tlsv1.2

# Authentication
allow_anonymous false
password_file /etc/mosquitto/passwd

# ACL for topic-based access control
acl_file /etc/mosquitto/acl

# Logging
log_type error
log_type warning
log_type notice
log_type information

# Connection limits
max_connections 100
max_queued_messages 1000
```

**ACL Configuration (acl):**
```
# Android app can publish and subscribe to all topics
user app_user
topic readwrite #

# T-Embed devices can only publish to their own topics
user device_001
topic write sensors/device_001/#
topic read commands/device_001/#

user device_002
topic write sensors/device_002/#
topic read commands/device_002/#

# Presto gateway can read all sensor data
user presto_gateway
topic read sensors/#
topic write commands/#
```

## Security Checklist for Argus

### Device Provisioning
- [ ] Unique device ID generated during manufacturing
- [ ] Flash encryption enabled before first boot
- [ ] Secure boot configured and enabled
- [ ] Default credentials removed
- [ ] Device certificate generated and stored
- [ ] Factory reset capability implemented

### Network Security
- [ ] WiFi WPA2/WPA3 only (no WEP/WPA)
- [ ] MQTT over TLS only (port 8883)
- [ ] Certificate validation enabled
- [ ] No hardcoded credentials
- [ ] mDNS restricted to local network
- [ ] Firewall rules configured

### Data Protection
- [ ] Sensor data encrypted in transit
- [ ] Historical data encrypted at rest
- [ ] Logs don't contain sensitive info
- [ ] User data anonymized where possible
- [ ] Data retention policy implemented
- [ ] Secure deletion on device removal

### Authentication & Authorization
- [ ] Android app requires authentication
- [ ] MQTT requires valid credentials
- [ ] BLE pairing requires passkey
- [ ] API tokens expire and refresh
- [ ] Failed auth attempts logged
- [ ] Rate limiting on authentication

### Update & Maintenance
- [ ] OTA updates signed and verified
- [ ] Update server uses HTTPS
- [ ] Rollback capability for failed updates
- [ ] Update notifications secure
- [ ] Version tracking implemented
- [ ] Emergency update mechanism

### Monitoring & Logging
- [ ] Security events logged
- [ ] Anomaly detection implemented
- [ ] Failed auth attempts tracked
- [ ] System health monitoring
- [ ] Log rotation configured
- [ ] Centralized logging (optional)

### Physical Security
- [ ] Debug ports disabled in production
- [ ] Enclosures prevent easy access
- [ ] Tamper detection (optional)
- [ ] Factory reset button secured
- [ ] No test points on production PCBs
- [ ] Secure element for keys (optional)

## Threat Scenarios

### Scenario 1: Compromised WiFi Network

**Attack:** Attacker on same WiFi network attempts MITM attack on MQTT traffic.

**Mitigations:**
- TLS encryption prevents packet inspection
- Certificate pinning detects MITM
- Mutual TLS authenticates both parties
- Network segmentation limits access

### Scenario 2: Stolen T-Embed Device

**Attack:** Physical access to T-Embed device, attempt to extract credentials.

**Mitigations:**
- Flash encryption protects stored credentials
- Secure boot prevents firmware modification
- Remote device decommissioning via app
- Device can be removed from system

### Scenario 3: Malicious Android App

**Attack:** Fake app attempts to impersonate legitimate Argus app.

**Mitigations:**
- App signing verification
- SSL pinning to MQTT broker
- API key validation server-side
- Device allowlist on MQTT broker

### Scenario 4: BLE Eavesdropping

**Attack:** Attempt to intercept BLE communication between Presto and T-Embed.

**Mitigations:**
- BLE encryption after bonding
- Secure Simple Pairing (SSP)
- Passkey entry prevents passive sniffing
- Limited BLE range

### Scenario 5: Firmware Downgrade Attack

**Attack:** Attempt to install older vulnerable firmware.

**Mitigations:**
- Rollback protection enabled
- Version checking in bootloader
- Signed firmware only
- OTA update authentication

## Incident Response Plan

### Detection
1. Monitor for failed authentication attempts
2. Check for unusual network traffic
3. Alert on firmware tampering attempts
4. Track device disconnections

### Response
1. Identify affected devices
2. Isolate compromised devices
3. Revoke device credentials
4. Force password/key rotation
5. Update firmware if vulnerability found

### Recovery
1. Factory reset affected devices
2. Re-provision with new credentials
3. Verify system integrity
4. Document incident
5. Implement additional safeguards

### Post-Incident
1. Review logs for root cause
2. Update security procedures
3. Patch vulnerabilities
4. User notification if needed
5. Improve monitoring
