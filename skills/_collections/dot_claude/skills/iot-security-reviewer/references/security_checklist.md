# IoT Security Review Checklist

This comprehensive checklist should be used as a guide when conducting security reviews of IoT devices and embedded systems.

## Confidentiality

### Data Encryption
- [ ] Sensitive data encrypted at rest using strong encryption (AES-256)
- [ ] TLS 1.2+ used for all network communication (MQTT, HTTP, WebSocket)
- [ ] WiFi credentials stored in encrypted NVS partition
- [ ] API keys and secrets never hardcoded in source code
- [ ] Private keys stored securely (hardware security module if available)
- [ ] Encryption keys rotated periodically

### Secure Storage
- [ ] Flash encryption enabled on ESP32 devices
- [ ] NVS partition encrypted for sensitive data
- [ ] Credentials stored using secure storage APIs
- [ ] Memory containing secrets zeroed after use
- [ ] Temporary files with sensitive data securely deleted

### Logging and Debugging
- [ ] Log files sanitized to prevent credential leakage
- [ ] Debug logs disabled in production builds
- [ ] Serial console output doesn't expose secrets
- [ ] Remote logging uses secure channels
- [ ] PII and sensitive data masked in logs

## Integrity

### Firmware Security
- [ ] Firmware images digitally signed
- [ ] Signature verification before flashing
- [ ] Secure boot enabled and configured
- [ ] Rollback protection implemented
- [ ] OTA updates require authentication
- [ ] Update server certificate validation

### Code Integrity
- [ ] Code signing for all executable code
- [ ] Bootloader protected from modification
- [ ] Critical configuration locked after boot
- [ ] Memory protection enabled (MPU/MMU)
- [ ] Stack canaries and ASLR where supported

### Message Integrity
- [ ] MQTT messages use TLS for integrity
- [ ] API requests include HMAC or signatures
- [ ] Replay attack prevention (nonces/timestamps)
- [ ] Message sequence validation
- [ ] Checksum verification for data packets

## Availability

### Resilience
- [ ] Watchdog timer configured and active
- [ ] Graceful handling of resource exhaustion
- [ ] Automatic recovery from crashes
- [ ] Connection retry with exponential backoff
- [ ] Task priority configuration prevents starvation

### DoS Protection
- [ ] Rate limiting on API endpoints
- [ ] Maximum connection limits enforced
- [ ] Timeout values configured appropriately
- [ ] Input validation prevents resource exhaustion
- [ ] Memory allocation limits enforced

### Monitoring
- [ ] Health check endpoints implemented
- [ ] System metrics logged periodically
- [ ] Error conditions reported
- [ ] Uptime tracking and reporting
- [ ] Diagnostic mode for troubleshooting

## Authentication

### Device Authentication
- [ ] Strong device identity (unique per device)
- [ ] Certificate-based authentication where possible
- [ ] No default credentials in production
- [ ] Password complexity requirements enforced
- [ ] Failed authentication attempts logged

### User Authentication
- [ ] Multi-factor authentication supported
- [ ] Session tokens with reasonable expiration
- [ ] Secure password storage (bcrypt/scrypt/Argon2)
- [ ] Password reset mechanism secure
- [ ] Account lockout after failed attempts

### Network Authentication
- [ ] MQTT broker requires authentication
- [ ] WiFi uses WPA2/WPA3 (no WEP/WPA)
- [ ] BLE pairing uses secure methods
- [ ] TLS client certificates for mutual auth
- [ ] API keys rotated periodically

## Authorization

### Access Control
- [ ] Least privilege principle enforced
- [ ] Role-based access control (RBAC) implemented
- [ ] Resource access validated before operations
- [ ] API endpoints check authorization
- [ ] Administrative functions properly protected

### Privilege Separation
- [ ] Different privilege levels for operations
- [ ] Critical functions require elevated permissions
- [ ] User cannot escalate privileges
- [ ] Service accounts have minimal permissions
- [ ] Isolation between components enforced

### Data Access
- [ ] Users can only access their own data
- [ ] Cross-device access controlled
- [ ] Sensitive operations require re-authentication
- [ ] Data sharing requires explicit permission
- [ ] Audit logs for privileged operations

## Network Security

### WiFi Security
- [ ] WPA2-PSK minimum (WPA3 preferred)
- [ ] Certificate pinning for critical connections
- [ ] SSID and password not hardcoded
- [ ] WiFi credentials configurable via secure method
- [ ] Support for enterprise WiFi (802.1X) if needed

### MQTT Security
- [ ] TLS enabled for MQTT connections
- [ ] Username/password authentication required
- [ ] Client certificates for mutual TLS
- [ ] Topic-based access control
- [ ] Quality of Service (QoS) configured appropriately

### Protocol Security
- [ ] No unencrypted protocols (HTTP, Telnet, FTP)
- [ ] TLS 1.2+ with strong cipher suites
- [ ] Certificate validation enabled
- [ ] Hostname verification in TLS
- [ ] Perfect forward secrecy supported

### Network Segmentation
- [ ] IoT devices on separate network/VLAN
- [ ] Firewall rules restrict device communication
- [ ] Only necessary ports exposed
- [ ] mDNS/UPnP disabled if not needed
- [ ] Network scanning protection

## Physical Security

### Device Hardening
- [ ] Debug interfaces disabled in production
- [ ] JTAG/SWD locked or disabled
- [ ] UART console disabled or password protected
- [ ] Boot mode pins secured
- [ ] Tamper detection where applicable

### Physical Access
- [ ] Enclosure prevents easy access to board
- [ ] Critical components protected from probing
- [ ] No test points on production boards
- [ ] Secure element for key storage if needed
- [ ] Anti-tamper mechanisms where required

## Compliance and Standards

### Industry Standards
- [ ] OWASP IoT Top 10 vulnerabilities addressed
- [ ] IoT Security Foundation guidelines followed
- [ ] Industry-specific standards met (if applicable)
- [ ] Security certifications obtained (if required)
- [ ] Penetration testing completed

### Privacy and Regulations
- [ ] GDPR compliance (if applicable)
- [ ] Data minimization principle followed
- [ ] Privacy policy available and clear
- [ ] User consent for data collection
- [ ] Data retention policies defined

### Documentation
- [ ] Security architecture documented
- [ ] Threat model created and reviewed
- [ ] Security testing results documented
- [ ] Incident response plan defined
- [ ] Security update process documented
