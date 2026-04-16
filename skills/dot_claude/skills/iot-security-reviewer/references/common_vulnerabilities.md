# Common IoT Vulnerabilities and OWASP IoT Top 10

## OWASP IoT Top 10 (2018)

### I1: Weak, Guessable, or Hardcoded Passwords

**Description:** Use of easily brute-forced, publicly available, or unchangeable credentials.

**Examples:**
- Default admin/admin credentials
- Hardcoded WiFi passwords in firmware
- API keys committed to source control
- Passwords in configuration files

**Mitigation:**
- Require strong, unique passwords
- Force password change on first use
- Use certificate-based authentication
- Store credentials in encrypted storage
- Implement account lockout policies

### I2: Insecure Network Services

**Description:** Unneeded or insecure network services running on the device.

**Examples:**
- Telnet server enabled
- Unencrypted HTTP API
- Debug services in production
- UPnP enabled unnecessarily
- Open MQTT broker without authentication

**Mitigation:**
- Disable unnecessary services
- Use TLS for all network communication
- Implement authentication for all services
- Regular port scanning audits
- Network segmentation

### I3: Insecure Ecosystem Interfaces

**Description:** Insecure web, backend API, cloud, or mobile interfaces outside the device.

**Examples:**
- Web dashboard without HTTPS
- API without rate limiting
- Missing input validation
- SQL injection vulnerabilities
- Insecure cloud API calls

**Mitigation:**
- Use HTTPS/TLS for all web interfaces
- Implement rate limiting and throttling
- Validate and sanitize all inputs
- Use parameterized queries
- API authentication and authorization

### I4: Lack of Secure Update Mechanism

**Description:** Lack of firmware validation, secure delivery, or anti-rollback mechanisms.

**Examples:**
- Unsigned firmware images
- OTA updates over HTTP
- No version checking
- Missing rollback protection
- Update server without authentication

**Mitigation:**
- Sign all firmware images
- Verify signatures before installation
- Use TLS for update downloads
- Implement anti-rollback protection
- Secure boot chain

### I5: Use of Insecure or Outdated Components

**Description:** Use of deprecated or insecure software components/libraries.

**Examples:**
- Old TLS libraries (SSLv3, TLS 1.0)
- Vulnerable third-party libraries
- Outdated RTOS versions
- Unpatched dependencies
- End-of-life components

**Mitigation:**
- Regular dependency audits
- Update libraries and components
- Use dependency scanning tools
- Subscribe to security advisories
- Implement patch management process

### I6: Insufficient Privacy Protection

**Description:** Personal information not properly protected or used inappropriately.

**Examples:**
- Unencrypted personal data
- Excessive data collection
- Unclear privacy policies
- Data shared without consent
- Location tracking without disclosure

**Mitigation:**
- Encrypt all personal data
- Follow data minimization principle
- Clear privacy policy and consent
- Anonymize data where possible
- Comply with privacy regulations (GDPR, CCPA)

### I7: Insecure Data Transfer and Storage

**Description:** Lack of encryption or access control of sensitive data.

**Examples:**
- Credentials sent over HTTP
- Unencrypted MQTT messages
- Plaintext passwords in flash
- API keys in cleartext
- Sensitive logs without encryption

**Mitigation:**
- Use TLS for all network transfers
- Encrypt data at rest
- Use encrypted flash partitions
- Secure key management
- Zero sensitive data from memory after use

### I8: Lack of Device Management

**Description:** Lack of security support on devices deployed in production.

**Examples:**
- No asset management
- Missing update mechanism
- No device decommissioning process
- Inability to remotely disable device
- No monitoring or logging

**Mitigation:**
- Device inventory and tracking
- Remote management capabilities
- OTA update mechanism
- Device lifecycle management
- Centralized logging and monitoring

### I9: Insecure Default Settings

**Description:** Devices shipped with insecure default settings or lack of configuration options.

**Examples:**
- Default admin credentials
- Debug mode enabled
- Unnecessary services running
- Permissive firewall rules
- Sample data/keys in production

**Mitigation:**
- Secure defaults out-of-box
- Force configuration on first boot
- Disable debug features in production
- Security hardening guide
- Configuration validation

### I10: Lack of Physical Hardening

**Description:** Lack of physical hardening measures allowing attackers to gain sensitive information.

**Examples:**
- Exposed debug ports (JTAG, UART)
- Unprotected flash memory
- No tamper detection
- Readable firmware via flash dump
- Test points on production boards

**Mitigation:**
- Disable debug interfaces in production
- Flash encryption and secure boot
- Tamper-evident enclosures
- Secure element for key storage
- PCB design without test points

## Additional Common Vulnerabilities

### Side-Channel Attacks

**Description:** Extracting secrets through timing, power analysis, or electromagnetic emissions.

**Examples:**
- Timing attacks on crypto operations
- Power analysis to extract keys
- Differential power analysis (DPA)
- Cache timing attacks

**Mitigation:**
- Constant-time crypto implementations
- Power analysis countermeasures
- Hardware security modules
- Noise injection techniques

### Buffer Overflow and Memory Corruption

**Description:** Writing data beyond buffer boundaries, leading to crashes or code execution.

**Examples:**
- Stack buffer overflow
- Heap corruption
- Use-after-free vulnerabilities
- Integer overflow leading to buffer overflow

**Mitigation:**
- Bounds checking on all inputs
- Use safe string functions (strncpy, snprintf)
- Enable stack canaries and ASLR
- Memory-safe languages where possible
- Static analysis tools

### Command Injection

**Description:** Executing arbitrary commands through unsanitized input.

**Examples:**
- Shell command injection
- SQL injection
- LDAP injection
- OS command injection via web interface

**Mitigation:**
- Input validation and sanitization
- Use parameterized queries
- Avoid system() calls with user input
- Principle of least privilege
- Whitelist allowed characters

### Replay Attacks

**Description:** Capturing and retransmitting valid messages to perform unauthorized actions.

**Examples:**
- Replaying authentication tokens
- Resending control commands
- Duplicating payment transactions
- Reusing old session tokens

**Mitigation:**
- Include timestamps in messages
- Use nonces (number used once)
- Sequence numbers for messages
- Short-lived tokens with expiration
- Challenge-response authentication

### Man-in-the-Middle (MITM) Attacks

**Description:** Intercepting communication between two parties.

**Examples:**
- WiFi packet sniffing
- ARP spoofing
- DNS hijacking
- SSL stripping attacks
- Rogue access points

**Mitigation:**
- TLS with certificate pinning
- Mutual TLS authentication
- End-to-end encryption
- Validate server certificates
- Use VPN for sensitive communication

### Denial of Service (DoS)

**Description:** Making the device unavailable through resource exhaustion.

**Examples:**
- Memory exhaustion attacks
- Connection flooding
- CPU-intensive operations
- Disk space filling
- Amplification attacks

**Mitigation:**
- Rate limiting and throttling
- Resource allocation limits
- Timeout mechanisms
- Input validation to prevent expensive operations
- Watchdog timer for recovery

## Vulnerability Assessment Tools

### Static Analysis
- **cppcheck**: C/C++ static analyzer
- **clang-tidy**: Linter for C/C++ code
- **SonarQube**: Multi-language code quality and security
- **Coverity**: Commercial static analysis tool

### Dynamic Analysis
- **Valgrind**: Memory leak and error detection
- **AddressSanitizer**: Fast memory error detector
- **Fuzzing tools**: AFL, libFuzzer for crash discovery

### Dependency Scanning
- **OWASP Dependency-Check**: Identifies known vulnerabilities in dependencies
- **Snyk**: Security scanning for dependencies
- **npm audit** / **pip-audit**: Language-specific dependency scanners

### Network Analysis
- **Wireshark**: Packet capture and analysis
- **nmap**: Network scanning and service detection
- **Burp Suite**: Web application security testing
- **OWASP ZAP**: Web application security scanner

### Penetration Testing
- **Metasploit**: Penetration testing framework
- **Aircrack-ng**: WiFi security testing
- **Hydra**: Password cracking and brute-force
- **Nikto**: Web server scanner
