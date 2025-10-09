# EndpointSecurity Events Reference Guide
## CrowdStrike, Beyond Identity, Jamf, and Truu

Complete reference for ES events used in security monitoring, identity management, FIDO2/WebAuthn, biometrics, TouchID, SSO, PlatformSSO, and threat detection.

**Document Version:** 2.0  
**Last Updated:** 2024  
**Applicable to:** macOS 10.15+ (Catalina and later)  
**Framework:** EndpointSecurity.framework

---

## Table of Contents

1. [Process Execution & Lifecycle](#process-execution--lifecycle)
2. [File System Operations](#file-system-operations)
3. [Authentication & Biometric Events](#authentication--biometric-events)
4. [Single Sign-On (SSO) & Platform SSO](#single-sign-on-sso--platform-sso)
5. [Session & Login Monitoring](#session--login-monitoring)
6. [Authorization & Privilege Management](#authorization--privilege-management)
7. [Credential & Secret Access](#credential--secret-access)
8. [Man-in-the-Middle Attack Detection](#man-in-the-middle-attack-detection)
9. [Network & IPC Monitoring](#network--ipc-monitoring)
10. [Process Interaction](#process-interaction)
11. [Certificate & TLS Monitoring](#certificate--tls-monitoring)
12. [Device Attestation & Secure Enclave](#device-attestation--secure-enclave)
13. [Kernel Extensions & Drivers](#kernel-extensions--drivers)
14. [Configuration & Policy Management](#configuration--policy-management)
15. [Anti-Phishing & Browser Security](#anti-phishing--browser-security)
16. [Persistence Mechanisms](#persistence-mechanisms)
17. [OpenDirectory & Account Management](#opendirectory--account-management)
18. [File System Integrity](#file-system-integrity)
19. [Gatekeeper & Notarization](#gatekeeper--notarization)
20. [Malware Detection](#malware-detection)
21. [System Modifications](#system-modifications)
22. [Process Behavior Analysis](#process-behavior-analysis)
23. [Time & System Settings](#time--system-settings)
24. [Root Directory Changes](#root-directory-changes)
25. [Recommended Event Combinations](#recommended-event-combinations)
26. [Implementation Guide](#implementation-guide)
27. [Troubleshooting](#troubleshooting)

---

## Process Execution & Lifecycle

### ES_EVENT_TYPE_NOTIFY_EXEC
**Description:** Monitor all process executions with complete details

**Key Fields:**
- `target` - New process information after exec
- `dyld_exec_path` - Exec path before symlink resolution
- `script` - Script being executed (if shell script)
- `cwd` - Current working directory
- `last_fd` - Highest open file descriptor
- `image_cputype` - CPU architecture
- Arguments (use `es_exec_arg_count()` and `es_exec_arg()`)
- Environment (use `es_exec_env_count()` and `es_exec_env()`)
- File descriptors (use `es_exec_fd_count()` and `es_exec_fd()`)

**Use Cases:**
- Process execution tracking
- Command-line argument inspection for credentials
- Environment variable monitoring for tokens/keys
- Inherited file descriptor detection
- Shell script execution monitoring

**Cache Key:** (process executable, target executable)

---

### ES_EVENT_TYPE_AUTH_EXEC
**Description:** Authorization control over process execution

**Use Cases:**
- Block malicious executables
- Application whitelisting
- Enforce execution policies

**Supports:** Caching

---

### ES_EVENT_TYPE_NOTIFY_FORK
**Description:** Track process creation

**Key Fields:**
- `child` - New child process information

**Use Cases:**
- Process lineage tracking
- Process tree analysis
- Fork bomb detection

**Note:** Notify-only event

---

### ES_EVENT_TYPE_NOTIFY_EXIT
**Description:** Process termination

**Key Fields:**
- `stat` - Exit status (wait(2) format)

**Use Cases:**
- Process lifecycle completion
- Abnormal termination detection
- Exit code analysis

**Note:** Notify-only event

---

## File System Operations

### File Access & Modification

#### ES_EVENT_TYPE_NOTIFY_OPEN / ES_EVENT_TYPE_AUTH_OPEN
**Description:** File access monitoring

**Key Fields:**
- `fflag` - File flags (FREAD, FWRITE, etc.)
- `file` - File being opened

**Use Cases:**
- Keychain file access monitoring
- Certificate file access
- Configuration file access
- Sensitive document tracking

**Important:** Use FFLAG values (FREAD, FWRITE) not O_RDONLY, O_RDWR for AUTH responses

**Cache Key:** (process executable, file being opened)

---

#### ES_EVENT_TYPE_NOTIFY_CLOSE
**Description:** File closure with modification tracking

**Key Fields:**
- `modified` - File was modified via filesystem syscall
- `target` - File being closed
- `was_mapped_writable` - File was mapped writable during vnode lifetime

**Use Cases:**
- Detect file modifications
- Memory-mapped file tracking
- Credential file changes

**Note:** `was_mapped_writable` indicates possibility of modification, not guarantee

---

#### ES_EVENT_TYPE_NOTIFY_WRITE
**Description:** File write operations

**Key Fields:**
- `target` - File being written

**Critical Paths to Monitor:**
- `/etc/authorization`
- `/etc/pam.d/`
- `/var/db/dslocal/nodes/Default/users/`
- SSH `authorized_keys` files

**Note:** Notify-only event

---

### File Creation & Deletion

#### ES_EVENT_TYPE_NOTIFY_CREATE / ES_EVENT_TYPE_AUTH_CREATE
**Description:** File creation

**Key Fields:**
- `destination_type` - Existing file or new path
- `destination` - Union containing file or path info
- `acl` - ACL for new file (optional, version 2+)

**Use Cases:**
- New authentication configuration files
- Certificate installation
- Suspicious file creation

**Note:** Can fire multiple times per syscall

---

#### ES_EVENT_TYPE_NOTIFY_UNLINK / ES_EVENT_TYPE_AUTH_UNLINK
**Description:** File deletion

**Key Fields:**
- `target` - File being removed
- `parent_dir` - Parent directory

**Use Cases:**
- Authentication log deletion
- Certificate removal
- Evidence destruction

**Note:** Can fire multiple times per syscall

---

#### ES_EVENT_TYPE_NOTIFY_RENAME / ES_EVENT_TYPE_AUTH_RENAME
**Description:** File renaming/moving

**Key Fields:**
- `source` - Source file
- `destination_type` - Existing file or new path
- `destination` - Destination info

**Use Cases:**
- File replacement attacks
- Log file rotation monitoring

**Note:** Can fire multiple times per syscall

---

### File Attributes

#### ES_EVENT_TYPE_NOTIFY_SETEXTATTR / ES_EVENT_TYPE_AUTH_SETEXTATTR
**Description:** Set extended attributes

**Key Fields:**
- `target` - File receiving xattr
- `extattr` - Attribute name

**Use Cases:**
- Quarantine flag manipulation
- Certificate trust settings
- Custom metadata tracking

---

#### ES_EVENT_TYPE_NOTIFY_GETEXTATTR / ES_EVENT_TYPE_AUTH_GETEXTATTR
**Description:** Read extended attributes

**Cache Key:** (process executable, target file)

---

#### ES_EVENT_TYPE_NOTIFY_DELETEEXTATTR / ES_EVENT_TYPE_AUTH_DELETEEXTATTR
**Description:** Delete extended attributes

**Use Cases:**
- Remove quarantine flags
- Clear security metadata

---

#### ES_EVENT_TYPE_NOTIFY_LISTEXTATTR / ES_EVENT_TYPE_AUTH_LISTEXTATTR
**Description:** List extended attributes

**Use Cases:**
- Xattr discovery
- Reconnaissance activity

**Cache Key:** (process executable, target file)

---

### File Metadata

#### ES_EVENT_TYPE_NOTIFY_SETMODE / ES_EVENT_TYPE_AUTH_SETMODE
**Description:** Modify file permissions

**Key Fields:**
- `mode` - New mode value
- `target` - File being modified

**Cache Key:** (process executable, target file)

---

#### ES_EVENT_TYPE_NOTIFY_SETFLAGS / ES_EVENT_TYPE_AUTH_SETFLAGS
**Description:** Modify file flags

**Key Fields:**
- `flags` - New flags
- `target` - File being modified

**Cache Key:** (process executable, target file)

---

#### ES_EVENT_TYPE_NOTIFY_SETOWNER / ES_EVENT_TYPE_AUTH_SETOWNER
**Description:** Modify file ownership

**Key Fields:**
- `uid` - New UID
- `gid` - New GID
- `target` - File being modified

**Cache Key:** (process executable, target file)

---

#### ES_EVENT_TYPE_NOTIFY_UTIMES / ES_EVENT_TYPE_AUTH_UTIMES
**Description:** Change file access/modification times

**Key Fields:**
- `target` - File being modified
- `atime` - New access time
- `mtime` - New modification time

**Use Cases:**
- Timestamp manipulation detection
- Anti-forensics technique identification

**Cache Key:** (process executable, target file)

---

### Directory Operations

#### ES_EVENT_TYPE_NOTIFY_READDIR / ES_EVENT_TYPE_AUTH_READDIR
**Description:** Directory enumeration

**Key Fields:**
- `target` - Directory being read

**Use Cases:**
- Keychain directory listing
- Certificate store enumeration
- Configuration discovery

**Cache Key:** (process executable, target directory)

---

#### ES_EVENT_TYPE_NOTIFY_CHDIR / ES_EVENT_TYPE_AUTH_CHDIR
**Description:** Change working directory

**Key Fields:**
- `target` - New working directory

**Cache Key:** (process executable, target directory)

---

## Authentication & Biometric Events

### Overview
**ES_EVENT_TYPE_NOTIFY_AUTHENTICATION** is the primary event for all authentication methods on macOS.

**Event Structure:**
```c
struct es_event_authentication_t {
    bool success;                    // Auth result
    es_authentication_type_t type;   // Auth type
    union data;                      // Type-specific data
}
```

**Authentication Types:**
- `ES_AUTHENTICATION_TYPE_OD` - OpenDirectory
- `ES_AUTHENTICATION_TYPE_TOUCHID` - Touch ID
- `ES_AUTHENTICATION_TYPE_TOKEN` - Hardware tokens (FIDO2, U2F, YubiKey)
- `ES_AUTHENTICATION_TYPE_AUTO_UNLOCK` - Apple Watch

---

### TouchID & Biometric Authentication

**Type:** `ES_AUTHENTICATION_TYPE_TOUCHID`

**Event Data:**
```c
struct es_event_authentication_touchid_t {
    es_process_t* instigator;
    es_touchid_mode_t touchid_mode;
    bool has_uid;
    uid_t uid;  // when has_uid = true
    audit_token_t instigator_token;
}
```

**TouchID Modes:**
- `ES_TOUCHID_MODE_VERIFICATION` - Verify specific enrolled finger (screen unlock, sudo, app auth)
- `ES_TOUCHID_MODE_IDENTIFICATION` - Identify any enrolled finger (login screen, fast user switching)

**Key Fields:**
- `success` - Authentication result
- `touchid_mode` - Verification vs Identification
- `has_uid` - UID availability (typically true for verification on success)
- `uid` - User ID that was authenticated
- `instigator` - Process requesting authentication

**Use Cases:**
1. Screen unlock
2. Sudo with TouchID
3. Login screen identification
4. App authorization prompts

**Security Monitoring:**
- Failed attempt tracking (brute force detection)
- Unusual authentication times
- Unexpected requesting processes
- Repeated failures followed by success

**Related Events:**
- `ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN` - Touch ID sensor access
- `ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT` - Authorization decision
- `ES_EVENT_TYPE_NOTIFY_LW_SESSION_UNLOCK` - Screen unlock

---

### FIDO2 & WebAuthn

**Type:** `ES_AUTHENTICATION_TYPE_TOKEN`

**Event Data:**
```c
struct es_event_authentication_token_t {
    es_process_t* instigator;
    es_string_token_t pubkey_hash;      // Public key hash
    es_string_token_t token_id;         // Hardware token ID
    es_string_token_t kerberos_principal; // Optional Kerberos
    audit_token_t instigator_token;
}
```

**FIDO2/WebAuthn Authentication Flow:**

1. **Hardware Token Detection:**
   - `ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN` - Token connected/accessed

2. **Token Authentication:**
   - `ES_EVENT_TYPE_NOTIFY_AUTHENTICATION` (TOKEN type)
   - `pubkey_hash` - SHA-256 of public key credential
   - `token_id` - Unique hardware token identifier

3. **Authorization Decision:**
   - `ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT`

4. **SSO Session (if applicable):**
   - `ES_EVENT_TYPE_NOTIFY_XPC_CONNECT` - Platform SSO service

**Key Fields:**
- `pubkey_hash` - Identifies credential without exposing private key
- `token_id` - Hardware token identifier (YubiKey serial, AAGUID)
- `kerberos_principal` - For PKINIT (Public Key Initial Authentication)

**Supported Protocols:**
- FIDO U2F (legacy)
- FIDO2/WebAuthn
- CTAP2 (Client to Authenticator Protocol)
- Passwordless via resident keys

**Supported Hardware:**
- YubiKey (all FIDO2 models)
- Google Titan Security Key
- Feitian ePass FIDO
- SoloKeys
- Any CTAP2-compliant authenticator

**Security Monitoring:**

1. **Token Registration Tracking:**
   - New `token_id` values = new hardware keys
   - Track first-time credential use

2. **Credential Binding:**
   - Same `pubkey_hash` should always come from same `token_id`
   - Mismatch indicates cloned/compromised credential

3. **Impossible Travel:**
   - Same token_id from different locations rapidly

4. **Brute Force:**
   - Multiple failed token authentications

**Enterprise Integration:**
For Beyond Identity, Jamf, and similar:

```swift
// Monitor TOKEN authentication
if authEvent.type == ES_AUTHENTICATION_TYPE_TOKEN {
    if !isApprovedToken(authEvent.data.token.token_id) {
        alert("Unapproved hardware token used")
    }
    
    // Verify credential binding
    if !verifyBinding(authEvent.data.token.pubkey_hash, 
                      authEvent.data.token.token_id) {
        alert("Credential binding violation")
    }
}
```

**Kerberos Integration:**
When `kerberos_principal` present:
- Token used for Kerberos ticket acquisition (PKINIT)
- Smart card authentication to Active Directory
- Enables SSO across enterprise resources

---

### OpenDirectory Authentication

**Type:** `ES_AUTHENTICATION_TYPE_OD`

**Event Data:**
```c
struct es_event_authentication_od_t {
    es_process_t* instigator;
    es_string_token_t record_type;  // "Users", "Computer"
    es_string_token_t record_name;  // Username
    es_string_token_t node_name;    // OD node
    es_string_token_t db_path;      // Local DB path (optional)
    audit_token_t instigator_token;
}
```

**OpenDirectory Nodes:**

1. **Local Directory:**
   - `node_name`: `/Local/Default`
   - `db_path`: `/var/db/dslocal/nodes/Default`
   - Local user accounts

2. **LDAP Directory:**
   - `node_name`: `/LDAPv3/<server>`
   - Example: `/LDAPv3/ldap.company.com`

3. **Active Directory:**
   - `node_name`: `/Active Directory/<domain>`
   - Example: `/Active Directory/CORP.EXAMPLE.COM`

**Record Types:**
- `Users` - User account authentication (most common)
- `Computer` - Machine account authentication

**Example Events:**

**Local User Login:**
```
success: true
record_type: Users
record_name: johndoe
node_name: /Local/Default
db_path: /var/db/dslocal/nodes/Default
instigator: loginwindow
```

**Active Directory Domain User:**
```
success: true
record_type: Users
record_name: jane.smith
node_name: /Active Directory/CORP.EXAMPLE.COM
instigator: SecurityAgent
```

**Security Monitoring:**
- Brute force detection (multiple failed attempts)
- Account enumeration (systematic username probing)
- Privilege escalation (admin account auth)
- Lateral movement (domain account from unexpected systems)

---

### Apple Watch Auto Unlock

**Type:** `ES_AUTHENTICATION_TYPE_AUTO_UNLOCK`

**Event Data:**
```c
struct es_event_authentication_auto_unlock_t {
    es_string_token_t username;
    es_auto_unlock_type_t type;
}
```

**Auto Unlock Types:**
- `ES_AUTO_UNLOCK_MACHINE_UNLOCK` - Unlock Mac using Apple Watch proximity
- `ES_AUTO_UNLOCK_AUTH_PROMPT` - Approve auth prompt via Watch (double-click side button)

**Requirements:**
- Apple Watch Series 3+ (Series 4+ recommended)
- Same iCloud account on both devices
- Two-factor authentication enabled
- Watch passcode enabled
- Bluetooth LE and Wi-Fi enabled
- Proximity (~3 feet / 1 meter)

**Security Considerations:**
- Less secure than password/TouchID
- Vulnerable to relay attacks (rare)
- Many enterprises disable via MDM

**Example MDM Configuration:**
```xml
<key>allowAutoUnlock</key>
<false/>  <!-- Disable Auto Unlock -->
```

**Security Monitoring:**
```swift
func monitorAutoUnlock(_ auth: es_event_authentication_auto_unlock_t) {
    if isPrivilegedUser(auth.username) {
        alert("Privileged user used Auto Unlock - policy violation")
    }
    
    if auth.type == ES_AUTO_UNLOCK_MACHINE_UNLOCK {
        // Check time and location
        if isUnusualTime() || isUnusualLocation() {
            alert("Auto Unlock at unusual time/location")
        }
    }
}
```

---

## Single Sign-On (SSO) & Platform SSO

### Platform SSO (macOS 13+)

**Platform SSO** is Apple's native SSO framework enabling:
- Passwordless authentication using device identity
- Secure Enclave-backed credentials
- Kerberos ticket generation
- Token-based authentication for cloud services
- Identity provider integration (Beyond Identity, Okta, Azure AD)

**Architecture:**
```
User Authentication
    ↓
Platform SSO Extension (IdP: Beyond Identity, Okta, etc.)
    ↓
Device Attestation (Secure Enclave)
    ↓
Token Exchange (OAuth 2.0, OIDC)
    ↓
Service Access
```

**ES Events for Platform SSO:**

#### 1. Extension Process Execution
**ES_EVENT_TYPE_NOTIFY_EXEC**
```
executable: /System/Library/ExtensionKit/Extensions/[Provider].appex
Example: com.beyondidentity.platformsso.extension
```

#### 2. Authentication Event
**ES_EVENT_TYPE_NOTIFY_AUTHENTICATION**
```
Type: ES_AUTHENTICATION_TYPE_TOKEN
token_id: [device-certificate-id]
pubkey_hash: [SEP-backed-public-key]
success: true
```

#### 3. XPC Communication
**ES_EVENT_TYPE_NOTIFY_XPC_CONNECT**
```
service_name: com.apple.AuthenticationServices.SSO
service_domain_type: ES_XPC_DOMAIN_TYPE_SYSTEM
```

#### 4. Secure Enclave Operations
**ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN**
```
user_client_class: AppleSEPKeyStore
parent_path: Secure Enclave Processor
```

#### 5. Token Storage
**ES_EVENT_TYPE_NOTIFY_WRITE**
```
file: ~/Library/Keychains/login.keychain-db
```

#### 6. Kerberos Integration (Enterprise)
**ES_EVENT_TYPE_NOTIFY_EXEC**
```
executable: /usr/bin/kinit
arguments: ['-C', 'user@REALM']  # Certificate-based
```

#### 7. Profile Installation (MDM)
**ES_EVENT_TYPE_NOTIFY_PROFILE_ADD**
```
profile.identifier: com.apple.sso
install_source: ES_PROFILE_SOURCE_MANAGED
```

### Complete SSO Login Flow

```
1. Login initiated
   ES_EVENT_TYPE_NOTIFY_EXEC
   - loginwindow.app

2. SSO extension loaded
   ES_EVENT_TYPE_NOTIFY_EXEC
   - com.beyondidentity.sso.extension

3. Device attestation
   ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN
   - AppleSEPKeyStore

4. Certificate-based auth
   ES_EVENT_TYPE_NOTIFY_AUTHENTICATION
   - TYPE: TOKEN
   - success: true

5. XPC to SSO service
   ES_EVENT_TYPE_NOTIFY_XPC_CONNECT
   - com.apple.AuthenticationServices.SSO

6. Token storage
   ES_EVENT_TYPE_NOTIFY_WRITE
   - login.keychain-db

7. Authorization granted
   ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT
   - right: system.login.console
   - granted: true

8. Session created
   ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGIN
   - username: user@company.com
   - graphical_session_id: 12345
```

### Traditional Kerberos SSO

**Ticket Acquisition:**
```
ES_EVENT_TYPE_NOTIFY_EXEC
executable: /usr/bin/kinit
arguments: ['user@REALM']
environment: ['KRB5CCNAME=/tmp/krb5cc_501']
```

**Configuration Access:**
```
ES_EVENT_TYPE_NOTIFY_OPEN
file: /etc/krb5.conf

ES_EVENT_TYPE_NOTIFY_READDIR
target: /etc/krb5.conf.d/
```

**Ticket Cache:**
```
ES_EVENT_TYPE_NOTIFY_CREATE
file: /tmp/krb5cc_501

ES_EVENT_TYPE_NOTIFY_WRITE
file: /tmp/krb5cc_501
```

### SSO Security Monitoring

#### Token Theft Detection
```swift
func detectTokenTheft(_ event: es_message_t) {
    if event.event_type == ES_EVENT_TYPE_NOTIFY_OPEN {
        let file = String(cString: event.event.open.file.pointee.path.data)
        
        if file.contains("oauth") || file.contains("sso") {
            let process = event.process.pointee.executable.pointee.path
            
            if !isAuthorizedProcess(process) {
                alert("Unauthorized SSO token access")
            }
        }
    }
}
```

#### Session Hijacking Detection
```swift
struct SSOSession {
    var username: String
    var sessionId: String
    var establishedAt: Date
    var lastActivity: Date
    var sourceIP: String?
}

// Alert on:
// - Session use from different IPs
// - Outside normal hours
// - Rapid session creation/destruction
// - Multiple concurrent sessions
```

#### Impossible Travel
```swift
func detectImpossibleTravel(_ login: SSOLoginEvent) {
    if let lastLogin = getLastLogin(login.username) {
        let distance = calculateDistance(lastLogin.location, login.location)
        let timeDelta = login.timestamp - lastLogin.timestamp
        
        if distance / timeDelta > maxHumanTravelSpeed {
            alert("Impossible travel detected")
        }
    }
}
```

### Beyond Identity Integration

**Device Registration:**
```
ES_EVENT_TYPE_NOTIFY_PROFILE_ADD
profile.identifier: com.beyondidentity.device
```

**Passwordless Authentication:**
```
ES_EVENT_TYPE_NOTIFY_AUTHENTICATION
Type: ES_AUTHENTICATION_TYPE_TOKEN
token_id: [device-identity-certificate]
pubkey_hash: [SEP-backed-public-key]

ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN
user_client_class: AppleSEPKeyStore
```

**Continuous Authentication:**
```
ES_EVENT_TYPE_NOTIFY_EXEC
executable: /Library/Application Support/BeyondIdentity/agent

ES_EVENT_TYPE_NOTIFY_XPC_CONNECT
service: com.beyondidentity.auth
```

### Jamf SSO Integration

**Jamf Connect Login:**
```
ES_EVENT_TYPE_NOTIFY_EXEC
executable: /usr/local/bin/jamf
arguments: ['connect', 'login']
```

**Azure AD / Okta Integration:**
```
ES_EVENT_TYPE_NOTIFY_OPEN
file: ~/Library/Application Support/JamfConnect/oauth_tokens

ES_EVENT_TYPE_NOTIFY_XPC_CONNECT
service: com.jamf.connect.auth
```

---

## Session & Login Monitoring

### LoginWindow Sessions

#### ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGIN
**Description:** User login via LoginWindow

**Key Fields:**
- `username` - Short username
- `graphical_session_id` - Session identifier

**Use Cases:**
- Track user session starts
- Correlate with authentication events
- Session duration analysis

---

#### ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGOUT
**Description:** User logout from LoginWindow

**Key Fields:**
- `username`
- `graphical_session_id`

**Use Cases:**
- Session termination tracking
- Session duration calculation

---

#### ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOCK
**Description:** Screen locked

**Key Fields:**
- `username`
- `graphical_session_id`

**Triggers:**
- Cmd+Ctrl+Q
- "Lock Screen" menu option
- Screen saver with password
- Apple Watch out of range

---

#### ES_EVENT_TYPE_NOTIFY_LW_SESSION_UNLOCK
**Description:** Screen unlocked after authentication

**Key Fields:**
- `username`
- `graphical_session_id`

**Unlock Methods:**
- Password
- Touch ID
- Apple Watch Auto Unlock
- Token-based auth

**Event Correlation:**
```
1. ES_EVENT_TYPE_NOTIFY_AUTHENTICATION
2. ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT
3. ES_EVENT_TYPE_NOTIFY_LW_SESSION_UNLOCK
```

---

### Session Security Monitoring

**Rapid Lock/Unlock Cycles:**
```swift
if lockUnlockCount > 5 && timeWindow < 60.seconds {
    alert("Rapid lock/unlock pattern - possible bypass attempt")
}
```

**Long Session Duration:**
```swift
let sessionDuration = Date() - session.loginTime
if sessionDuration > 24.hours && lockCount == 0 {
    alert("Suspicious long-running unlocked session")
}
```

**Unusual Unlock Times:**
```swift
if unlockTime.hour >= 2 && unlockTime.hour <= 5 {
    alert("Session unlocked during unusual hours")
}
```

---

### Console Login

#### ES_EVENT_TYPE_NOTIFY_LOGIN_LOGIN
**Description:** Authentication via /usr/bin/login

**Key Fields:**
- `success` - Authentication result
- `failure_message` - Reason for failure (if unsuccessful)
- `username`
- `has_uid`
- `uid` - User ID (when successful and has_uid = true)

**Use Cases:**
- SSH logins (when configured)
- Console login
- Custom authentication scripts

**Success Example:**
```
success: true
username: johndoe
has_uid: true
uid: 501
```

**Failure Example:**
```
success: false
failure_message: "Login incorrect"
username: attacker
has_uid: false
```

**Security Monitoring:**
```swift
var failedLogins: [String: Int] = [:]

func monitorLoginAttempts(_ event: es_event_login_login_t) {
    if !event.success {
        failedLogins[event.username, default: 0] += 1
        
        if failedLogins[event.username]! >= 5 {
            alert("Multiple failed login attempts", event.username)
        }
    }
}
```

---

#### ES_EVENT_TYPE_NOTIFY_LOGIN_LOGOUT
**Description:** Logout from /usr/bin/login session

**Key Fields:**
- `username`
- `uid`

---

### Remote Access Monitoring

#### Screen Sharing

**ES_EVENT_TYPE_NOTIFY_SCREENSHARING_ATTACH**
**Description:** Screen Sharing connection established

**Key Fields:**
- `success` - Connection succeeded
- `source_address_type` - IPV4, IPV6, NAMED_SOCKET, NONE
- `source_address` - IP or socket path (optional)
- `viewer_appleid` - Apple ID of viewer (if via Messages/FaceTime)
- `authentication_type` - How viewer authenticated
- `authentication_username` - Username for auth
- `session_username` - Session owner (optional)
- `existing_session` - Session existed before connection
- `graphical_session_id` - Session ID

**Example - Successful:**
```
success: true
source_address_type: ES_ADDRESS_TYPE_IPV4
source_address: 192.168.1.100
viewer_appleid: viewer@icloud.com
authentication_type: "VNC"
authentication_username: johndoe
existing_session: true
graphical_session_id: 12345
```

**Security Monitoring:**
```swift
func monitorScreenSharing(_ event: es_event_screensharing_attach_t) {
    if event.success {
        alert("Screen sharing established", 
              source: event.source_address)
        
        if !isAuthorizedRemoteAccess(event.source_address) {
            criticalAlert("Unauthorized screen sharing")
        }
        
        if !event.existing_session {
            alert("Screen sharing created new session")
        }
    }
}
```

**Note:** Not emitted when source = destination (loopback)

---

**ES_EVENT_TYPE_NOTIFY_SCREENSHARING_DETACH**
**Description:** Screen Sharing disconnected

**Key Fields:**
- `source_address_type`
- `source_address`
- `viewer_appleid`
- `graphical_session_id`

---

#### SSH Access

**ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGIN**
**Description:** SSH login attempt (connection-level)

**Key Fields:**
- `success`
- `result_type` - Result type (see below)
- `source_address_type`
- `source_address`
- `username`
- `has_uid`
- `uid` - (when successful)

**Result Types:**
- `ES_OPENSSH_LOGIN_EXCEED_MAXTRIES` - Too many attempts
- `ES_OPENSSH_LOGIN_ROOT_DENIED` - Root login denied
- `ES_OPENSSH_AUTH_SUCCESS` - Success
- `ES_OPENSSH_AUTH_FAIL_NONE` - "none" method failed
- `ES_OPENSSH_AUTH_FAIL_PASSWD` - Password failed
- `ES_OPENSSH_AUTH_FAIL_KBDINT` - Keyboard-interactive failed
- `ES_OPENSSH_AUTH_FAIL_PUBKEY` - Public key failed
- `ES_OPENSSH_AUTH_FAIL_HOSTBASED` - Host-based failed
- `ES_OPENSSH_AUTH_FAIL_GSSAPI` - GSSAPI failed
- `ES_OPENSSH_INVALID_USER` - User doesn't exist

**Example - Success:**
```
success: true
result_type: ES_OPENSSH_AUTH_SUCCESS
source_address: 203.0.113.25
username: johndoe
has_uid: true
uid: 501
```

**Example - Failed Password:**
```
success: false
result_type: ES_OPENSSH_AUTH_FAIL_PASSWD
source_address: 198.51.100.42
username: admin
```

**Security Monitoring:**
```swift
struct SSHAttempt {
    var sourceIP: String
    var username: String
    var failureCount: Int
    var lastAttempt: Date
}

var sshAttempts: [String: SSHAttempt] = [:]

func monitorSSH(_ event: es_event_openssh_login_t) {
    let key = "\(event.source_address)-\(event.username)"
    
    if !event.success {
        sshAttempts[key, default: SSHAttempt(...)].failureCount += 1
        
        if sshAttempts[key]!.failureCount >= 5 {
            alert("SSH brute force", source: event.source_address)
            blockIP(event.source_address)
        }
        
        if event.result_type == ES_OPENSSH_INVALID_USER {
            alert("SSH user enumeration", event.source_address)
        }
    } else {
        if !isAuthorizedSSHSource(event.source_address) {
            criticalAlert("SSH from unexpected source")
        }
    }
}
```

---

**ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGOUT**
**Description:** SSH connection closed

**Key Fields:**
- `source_address_type`
- `source_address`
- `username`
- `uid`

**Session Duration Tracking:**
```swift
func trackSSHDuration(login: LoginEvent, logout: LogoutEvent) {
    let duration = logout.timestamp - login.timestamp
    
    if duration > 8.hours {
        alert("Long SSH session", duration: duration)
    }
    
    if duration < 5.seconds {
        alert("Suspiciously short SSH session")
    }
}
```

---

## Authorization & Privilege Management

### Authorization Framework

#### ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_PETITION
**Description:** Authorization rights requested

**Key Fields:**
- `instigator` - Process that submitted petition (XPC caller)
- `petitioner` - Process that created petition
- `flags` - Petition flags
- `right_count` - Number of rights
- `rights` - Array of right names
- `instigator_token` - Audit token
- `petitioner_token` - Audit token

**Common Rights:**
- `system.login.console`
- `system.preferences`
- `system.privilege.admin`
- `system.services.systemconfiguration.network`

---

#### ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT
**Description:** Authorization decision made

**Key Fields:**
- `instigator`
- `petitioner`
- `return_code` - Overall result (0 = success)
- `result_count` - Number of results
- `results` - Array of per-right results
  - `right_name`
  - `rule_class` - user, rule, mechanism, allow, deny, unknown, invalid
  - `granted` - Boolean

**Example:**
```
return_code: 0
results[0]:
  right_name: "system.privilege.admin"
  rule_class: ES_AUTHORIZATION_RULE_CLASS_USER
  granted: true
```

---

### Privilege Escalation Detection

#### ES_EVENT_TYPE_NOTIFY_SETUID
**Description:** Process changes UID

**Key Fields:**
- `uid` - Target UID

**Use Cases:**
- Privilege escalation detection
- UID transition tracking

---

#### ES_EVENT_TYPE_NOTIFY_SETGID
**Description:** Process changes GID

**Key Fields:**
- `gid` - Target GID

---

#### ES_EVENT_TYPE_NOTIFY_SETEUID
**Description:** Process changes effective UID

**Key Fields:**
- `euid` - Target effective UID

---

#### ES_EVENT_TYPE_NOTIFY_SETEGID
**Description:** Process changes effective GID

**Key Fields:**
- `egid` - Target effective GID

---

#### ES_EVENT_TYPE_NOTIFY_SETREUID
**Description:** Process changes real and effective UID

**Key Fields:**
- `ruid` - Real UID
- `euid` - Effective UID

---

#### ES_EVENT_TYPE_NOTIFY_SETREGID
**Description:** Process changes real and effective GID

**Key Fields:**
- `rgid` - Real GID
- `egid` - Effective GID

---

### Sudo & Su Operations

#### ES_EVENT_TYPE_NOTIFY_SUDO
**Description:** Sudo command execution

**Key Fields:**
- `success`
- `reject_info` - If failed:
  - `plugin_name`
  - `plugin_type` - unknown, front-end, policy, I/O, audit, approval
  - `failure_message`
- `has_from_uid` / `from_uid` / `from_username`
- `has_to_uid` / `to_uid` / `to_username`
- `command`

**Example:**
```
success: true
from_username: "johndoe"
to_username: "root"
command: "apt-get update"
```

---

#### ES_EVENT_TYPE_NOTIFY_SU
**Description:** Su command execution

**Key Fields:**
- `success`
- `failure_message` - If failed
- `from_uid` / `from_username`
- `has_to_uid` / `to_uid` / `to_username`
- `shell`
- `argc` / `argv` - Arguments
- `env_count` / `env` - Environment variables

**Note:** Only emits on security-relevant events, not all failures

---

## Credential & Secret Access

### Keychain Monitoring

**Monitor Paths:**
```
/Library/Keychains/
~/Library/Keychains/
~/Library/Keychains/login.keychain-db
```

**Events:**
- `ES_EVENT_TYPE_NOTIFY_OPEN` / `AUTH_OPEN` - Keychain file access
- `ES_EVENT_TYPE_NOTIFY_READDIR` / `AUTH_READDIR` - Directory enumeration
- `ES_EVENT_TYPE_NOTIFY_WRITE` - Keychain modifications

---

### Password Modification

#### ES_EVENT_TYPE_NOTIFY_OD_MODIFY_PASSWORD
**Description:** OpenDirectory password changed

**Key Fields:**
- `instigator`
- `error_code` - 0 = success
- `account_type` - user, computer
- `account_name`
- `node_name` - Local/LDAP/AD
- `db_path`
- `instigator_token`

---

### Process Memory Access (Credential Dumping)

#### ES_EVENT_TYPE_NOTIFY_GET_TASK / ES_EVENT_TYPE_AUTH_GET_TASK
**Description:** Task control port access (can read process memory)

**Key Fields:**
- `target` - Target process
- `type` - task_for_pid, expose_task, identity_token

**Security Implications:**
- Can extract credentials from memory
- Critical for detecting credential dumping tools
- Used by debuggers and security tools

**Cache Key:** (process executable, target executable)

---

#### ES_EVENT_TYPE_NOTIFY_GET_TASK_READ / ES_EVENT_TYPE_AUTH_GET_TASK_READ
**Description:** Task read port (read-only access)

**Cache Key:** (process executable, target executable)

---

#### ES_EVENT_TYPE_NOTIFY_GET_TASK_INSPECT
**Description:** Task inspect port (limited inspection)

---

#### ES_EVENT_TYPE_NOTIFY_GET_TASK_NAME
**Description:** Task name port (minimal info)

---

## Man-in-the-Middle Attack Detection

### Process Injection & Code Manipulation

#### ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE
**Description:** Thread injection into another process

**Key Fields:**
- `target` - Process receiving new thread
- `thread_state` - Thread state (for thread_create_running, NULL for thread_create)

**Security Implications:**
- Common MitM/hooking technique
- Critical for detecting credential interception
- Used for API hooking

---

#### ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED
**Description:** Code signature invalidation

**Fires When:**
- CS_VALID bit removed from process
- First invalid page paged in
- Explicit invalidation via csops(CS_OPS_MARKINVALID)

**Security Implications:**
- Runtime code modification detected
- Potential hooking or tampering
- Does NOT fire if CS_HARD set

---

### Library Injection & Interposition

**Monitor EXEC for:**
- `DYLD_INSERT_LIBRARIES`
- `DYLD_LIBRARY_PATH`
- Other DYLD_* variables

#### ES_EVENT_TYPE_NOTIFY_MMAP / ES_EVENT_TYPE_AUTH_MMAP
**Description:** Memory mapping

**Key Fields:**
- `protection` - Protection flags
- `max_protection`
- `flags` - Mapping flags
- `file_pos` - Offset into file
- `source` - File being mapped

**Security Implications:**
- Detect suspicious library loading
- Monitor shared memory regions

**Cache Key:** (process executable, source file)

---

#### ES_EVENT_TYPE_NOTIFY_MPROTECT / ES_EVENT_TYPE_AUTH_MPROTECT
**Description:** Memory protection changes

**Key Fields:**
- `protection` - New protection value
- `address` - Base address
- `size` - Memory region size

**Security Implications:**
- Runtime code modification
- Self-modifying code detection

---

### Process Debugging & Manipulation

#### ES_EVENT_TYPE_NOTIFY_TRACE
**Description:** Process attachment (ptrace)

**Key Fields:**
- `target` - Process being attached

**Security Implications:**
- Debugger attachment attempts
- Can intercept credentials in memory
- Used for process inspection

**Note:** Can fire multiple times per trace attempt

---

#### ES_EVENT_TYPE_NOTIFY_PROC_SUSPEND_RESUME
**Description:** Process suspension/resume

**Key Fields:**
- `target` - Process being suspended/resumed
- `type` - suspend, resume, shutdown_sockets

**Security Implications:**
- Potential manipulation during suspension
- Can pause authentication flows

---

## Network & IPC Monitoring

### Unix Domain Sockets

#### ES_EVENT_TYPE_NOTIFY_UIPC_BIND / ES_EVENT_TYPE_AUTH_UIPC_BIND
**Description:** Unix socket creation

**Key Fields:**
- `dir` - Directory for socket file
- `filename` - Socket filename
- `mode` - Socket file mode

**Use Cases:**
- Monitor authentication service sockets

---

#### ES_EVENT_TYPE_NOTIFY_UIPC_CONNECT / ES_EVENT_TYPE_AUTH_UIPC_CONNECT
**Description:** Unix socket connection

**Key Fields:**
- `file` - Socket file
- `domain` - Communications domain
- `type` - Socket type
- `protocol`

**Use Cases:**
- IPC to authentication services
- Potential credential interception points

**Cache Key:** (process executable, socket file)

---

### XPC Service Connections

#### ES_EVENT_TYPE_NOTIFY_XPC_CONNECT
**Description:** XPC service connection

**Key Fields:**
- `service_name`
- `service_domain_type` - system, user, user login, session, PID, manager, port, GUI

**Use Cases:**
- Monitor authentication-related services
- Detect unauthorized access to identity services

---

## Process Interaction

### Inter-Process Signals

#### ES_EVENT_TYPE_NOTIFY_SIGNAL / ES_EVENT_TYPE_AUTH_SIGNAL
**Description:** Process signal delivery

**Key Fields:**
- `sig` - Signal number
- `target` - Process receiving signal
- `instigator` - Process sending signal (optional)

**Note:** Does not fire for self-signaling

---

### Process Control

#### ES_EVENT_TYPE_NOTIFY_PROC_CHECK / ES_EVENT_TYPE_AUTH_PROC_CHECK
**Description:** Process information retrieval access control

**Key Fields:**
- `target` - Process being queried (optional)
- `type` - listpids, pidinfo, pidfdinfo, setcontrol, pidfileportinfo, dirtycontrol, pidrusage
- `flavor`

**Use Cases:**
- Process enumeration detection

**Cache Key:** (process executable, target process executable, type)

---

## Certificate & TLS Monitoring

### Certificate File Access

**Monitor Paths:**
```
/System/Library/Keychains/
/Library/Keychains/
Custom certificate stores
```

**Events:**
- `ES_EVENT_TYPE_NOTIFY_OPEN` / `AUTH_OPEN`
- `ES_EVENT_TYPE_NOTIFY_CREATE` / `AUTH_CREATE` - New certificate installation
- `ES_EVENT_TYPE_NOTIFY_UNLINK` / `AUTH_UNLINK` - Certificate removal
- `ES_EVENT_TYPE_NOTIFY_WRITE` - Trust database modifications

---

### Certificate Metadata

**Events:**
- `ES_EVENT_TYPE_NOTIFY_SETEXTATTR` / `AUTH_SETEXTATTR` - Quarantine flags, trust settings

---

## Device Attestation & Secure Enclave

### IOKit Device Access

#### ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN / ES_EVENT_TYPE_AUTH_IOKIT_OPEN
**Description:** IOKit service connection

**Key Fields:**
- `user_client_type`
- `user_client_class` - Meta class name
- `parent_registry_id`
- `parent_path` - IOKit device tree path

**Use Cases:**
- Secure Enclave Processor (SEP) access
- Touch ID sensor access
- Hardware token/FIDO2 device access

**Note:** Does NOT correspond to device attachment

---

### File Provider & Cloud Storage

#### ES_EVENT_TYPE_NOTIFY_FILE_PROVIDER_MATERIALIZE
**Description:** File materialization from cloud

**Key Fields:**
- `instigator`
- `source` - Staged file
- `target` - Destination
- `instigator_token`

**Use Cases:**
- Cloud credential files
- Synced keychain items

---

#### ES_EVENT_TYPE_NOTIFY_FILE_PROVIDER_UPDATE
**Description:** File updates via FileProvider

**Key Fields:**
- `source` - Staged file with updates
- `target_path` - Destination

---

## Kernel Extensions & Drivers

#### ES_EVENT_TYPE_NOTIFY_KEXTLOAD / ES_EVENT_TYPE_AUTH_KEXTLOAD
**Description:** Kernel extension loading

**Key Fields:**
- `identifier` - Signing identifier

**Security Implications:**
- System-level persistence
- Potential kernel-level credential interception

**Note:** Not all AUTH events can be delivered (rare cases)

---

#### ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD
**Description:** Kernel extension unloading

**Key Fields:**
- `identifier`

---

## Configuration & Policy Management

### MDM Profile Installation

#### ES_EVENT_TYPE_NOTIFY_PROFILE_ADD
**Description:** Configuration profile installation

**Key Fields:**
- `instigator`
- `is_update` - Update vs new install
- `profile`:
  - `identifier`
  - `uuid`
  - `install_source` - managed vs install
  - `organization`
  - `display_name`
  - `scope`
- `instigator_token`

**Use Cases:**
- Track identity/authentication policy changes

---

#### ES_EVENT_TYPE_NOTIFY_PROFILE_REMOVE
**Description:** Profile removal

---

### TCC (Transparency, Consent & Control)

#### ES_EVENT_TYPE_NOTIFY_TCC_MODIFY
**Description:** TCC permission changes

**Key Fields:**
- `service` - Service name
- `identity` - Application
- `identity_type` - bundle ID, path, policy ID, file provider domain ID
- `update_type` - create, modify, delete
- `instigator_token` / `instigator`
- `responsible_token` / `responsible`
- `right` - denied, unknown, allowed, limited, etc.
- `reason` - user consent, user set, system set, policy, etc.

**Use Cases:**
- Monitor access to authentication services

---

### Access Control Lists

#### ES_EVENT_TYPE_NOTIFY_SETACL / ES_EVENT_TYPE_AUTH_SETACL
**Description:** Set file ACL

**Key Fields:**
- `target`
- `set_or_clear` - Set or clear operation
- `acl` - ACL structure (if setting)

---

## Anti-Phishing & Browser Security

### Browser Extension Monitoring

**Monitor:**
- `ES_EVENT_TYPE_NOTIFY_EXEC` - Browser launches
- `ES_EVENT_TYPE_NOTIFY_OPEN` - Extension manifests

**Paths:**
```
~/Library/Application Support/[Browser]/Extensions/
Extension manifest files
Preference files with extension lists
```

---

### Clipboard Monitoring

**Events:**
- `ES_EVENT_TYPE_NOTIFY_OPEN` - Pasteboard access
- Detect credential harvesting from clipboard

---

## Persistence Mechanisms

### Launch Items & Auto-Start

#### ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD
**Description:** Launch agent/daemon registration

**Key Fields:**
- `instigator`
- `app`
- `item`:
  - `item_type` - user item, app, login item, agent, daemon
  - `legacy` - Legacy plist
  - `managed` - MDM managed
  - `uid`
  - `item_url`
  - `app_url`
- `executable_path` - Optional
- `instigator_token` / `app_token`

**Note:** Can emit for previously seen items

---

#### ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_REMOVE
**Description:** Launch item removal

---

### Mount Operations

#### ES_EVENT_TYPE_NOTIFY_MOUNT / ES_EVENT_TYPE_AUTH_MOUNT
**Description:** File system mount

**Key Fields:**
- `statfs` - File system stats
- `disposition` - external, internal, network, virtual, nullfs, unknown

**Cache Key:** (process executable, mount point)

---

#### ES_EVENT_TYPE_NOTIFY_UNMOUNT
**Description:** File system unmount

---

#### ES_EVENT_TYPE_NOTIFY_REMOUNT / ES_EVENT_TYPE_AUTH_REMOUNT
**Description:** File system remount

**Key Fields:**
- `statfs`
- `remount_flags`
- `disposition`

---

## OpenDirectory & Account Management

### User Account Operations

#### ES_EVENT_TYPE_NOTIFY_OD_CREATE_USER
**Description:** User account creation

**Key Fields:**
- `instigator`
- `error_code` - 0 = success
- `user_name`
- `node_name`
- `db_path`
- `instigator_token`

---

#### ES_EVENT_TYPE_NOTIFY_OD_DELETE_USER
**Description:** User account deletion

---

#### ES_EVENT_TYPE_NOTIFY_OD_DISABLE_USER
**Description:** User account disabled

---

#### ES_EVENT_TYPE_NOTIFY_OD_ENABLE_USER
**Description:** User account enabled

---

### Group Management

#### ES_EVENT_TYPE_NOTIFY_OD_CREATE_GROUP
**Description:** Group creation

---

#### ES_EVENT_TYPE_NOTIFY_OD_DELETE_GROUP
**Description:** Group deletion

---

#### ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD
**Description:** Member added to group

**Key Fields:**
- `instigator`
- `error_code`
- `group_name`
- `member` - Identity (UUID or name)
- `member_type` - user name, user UUID, group UUID
- `node_name`
- `db_path`
- `instigator_token`

**Note:** Doesn't guarantee member was actually added

---

#### ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE
**Description:** Member removed from group

**Note:** Doesn't guarantee member was actually removed

---

#### ES_EVENT_TYPE_NOTIFY_OD_GROUP_SET
**Description:** Group membership replaced

**Key Fields:**
- `members` - Array (can be empty)
- `member_count`

---

### Attribute Modification

#### ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_VALUE_ADD
**Description:** Attribute value added

**Key Fields:**
- `record_type` - user, group
- `record_name`
- `attribute_name`
- `attribute_value`

---

#### ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_VALUE_REMOVE
**Description:** Attribute value removed

---

#### ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_SET
**Description:** Attribute set/replaced

**Key Fields:**
- `attribute_value_count`
- `attribute_values` - Array (can be empty)

---

## File System Integrity

### File Control Operations

#### ES_EVENT_TYPE_NOTIFY_FCNTL / ES_EVENT_TYPE_AUTH_FCNTL
**Description:** File control

**Key Fields:**
- `target`
- `cmd` - fcntl(2) command

---

## Gatekeeper & Notarization

#### ES_EVENT_TYPE_NOTIFY_GATEKEEPER_USER_OVERRIDE
**Description:** Gatekeeper bypass

**Key Fields:**
- `file_type` - path string vs es_file_t
- `file` - Path or file structure
- `sha256` - Hash (optional, if file < 100MB)
- `signing_info` - Optional:
  - `cdhash`
  - `signing_id`
  - `team_id`

**Security Implications:**
- User explicitly allowed unsigned/untrusted software
- Potential social engineering indicator

**Note:** Hashes calculated in usermode by Gatekeeper

---

## Malware Detection

### XProtect Integration

#### ES_EVENT_TYPE_NOTIFY_XP_MALWARE_DETECTED
**Description:** XProtect malware detection

**Key Fields:**
- `signature_version`
- `malware_identifier`
- `incident_identifier` - Links detect/remediate events
- `detected_path` - Not necessarily malicious binary
- `detected_executable` - Malicious binary path

**Note:** Can have multiple events per incident

---

#### ES_EVENT_TYPE_NOTIFY_XP_MALWARE_REMEDIATED
**Description:** XProtect remediation

**Key Fields:**
- `signature_version`
- `malware_identifier`
- `incident_identifier`
- `action_type` - e.g., "path_delete"
- `success`
- `result_description`
- `remediated_path` - Optional
- `remediated_process_audit_token` - Optional

---

## System Modifications

See [Authorization & Privilege Management](#authorization--privilege-management) for SETUID, SETGID, etc.

---

## Process Behavior Analysis

### PTY Operations

#### ES_EVENT_TYPE_NOTIFY_PTY_GRANT
**Description:** Pseudoterminal granted

**Key Fields:**
- `dev` - Device (major/minor numbers)

---

#### ES_EVENT_TYPE_NOTIFY_PTY_CLOSE
**Description:** Pseudoterminal closed

**Key Fields:**
- `dev`

---

## Time & System Settings

#### ES_EVENT_TYPE_NOTIFY_SETTIME / ES_EVENT_TYPE_AUTH_SETTIME
**Description:** System time modification

**Security Implications:**
- Can affect certificate validation
- Can impact session timeouts
- Potential replay attack enabler

**Note:** Not fired if process has `com.apple.private.settime` entitlement

---

## Root Directory Changes

#### ES_EVENT_TYPE_NOTIFY_CHROOT / ES_EVENT_TYPE_AUTH_CHROOT
**Description:** Change root directory

**Key Fields:**
- `target` - New root directory

**Security Implications:**
- Can hide files/processes
- Sandbox escape attempts
- Container/jail creation

**Cache Key:** (process executable, target directory)

---

## Recommended Event Combinations

### FIDO2/WebAuthn Flow
```
1. ES_EVENT_TYPE_NOTIFY_AUTHENTICATION (TOKEN)
2. ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN (hardware token)
3. ES_EVENT_TYPE_NOTIFY_XPC_CONNECT (auth service)
4. ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT
```

### TouchID Authentication Flow
```
1. ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN (Touch ID sensor)
2. ES_EVENT_TYPE_NOTIFY_AUTHENTICATION (TOUCHID)
3. ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT
4. ES_EVENT_TYPE_NOTIFY_LW_SESSION_UNLOCK
```

### Credential Theft Detection
```
1. ES_EVENT_TYPE_NOTIFY_GET_TASK (memory access)
2. ES_EVENT_TYPE_NOTIFY_OPEN (keychain files)
3. ES_EVENT_TYPE_NOTIFY_READDIR (enumeration)
4. ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE (injection)
5. ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED (tampering)
```

### Man-in-the-Middle Detection
```
1. ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE (hooking)
2. ES_EVENT_TYPE_NOTIFY_MMAP (library injection)
3. ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED (code modification)
4. ES_EVENT_TYPE_NOTIFY_TRACE (debugger attachment)
5. ES_EVENT_TYPE_NOTIFY_CREATE (certificate installation)
```

### Session Hijacking Detection
```
1. ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGIN
2. ES_EVENT_TYPE_NOTIFY_GET_TASK
3. ES_EVENT_TYPE_NOTIFY_SCREENSHARING_ATTACH
4. ES_EVENT_TYPE_NOTIFY_AUTHENTICATION
5. ES_EVENT_TYPE_NOTIFY_SETUID
```

### Phishing & Social Engineering
```
1. ES_EVENT_TYPE_NOTIFY_GATEKEEPER_USER_OVERRIDE
2. ES_EVENT_TYPE_NOTIFY_EXEC
3. ES_EVENT_TYPE_NOTIFY_OPEN (credential files)
4. ES_EVENT_TYPE_NOTIFY_XPC_CONNECT
```

---

## Implementation Guide

### Critical Events for Identity Security

**High Priority:**
1. ES_EVENT_TYPE_NOTIFY_AUTHENTICATION - All auth types
2. ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT
3. ES_EVENT_TYPE_NOTIFY_GET_TASK (all variants)
4. ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE
5. ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED
6. ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN
7. ES_EVENT_TYPE_NOTIFY_XPC_CONNECT

**Medium-High Priority:**
8. ES_EVENT_TYPE_NOTIFY_OPEN
9. ES_EVENT_TYPE_NOTIFY_WRITE
10. ES_EVENT_TYPE_NOTIFY_CREATE
11. ES_EVENT_TYPE_NOTIFY_CLOSE

**Medium Priority:**
12. ES_EVENT_TYPE_NOTIFY_EXEC
13. ES_EVENT_TYPE_NOTIFY_LW_SESSION_* (all session events)
14. ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGIN/LOGOUT
15. ES_EVENT_TYPE_NOTIFY_SCREENSHARING_ATTACH/DETACH

**Lower Priority:**
16. ES_EVENT_TYPE_NOTIFY_SETUID/SETGID (all variants)
17. ES_EVENT_TYPE_NOTIFY_SUDO/SU
18. ES_EVENT_TYPE_NOTIFY_GATEKEEPER_USER_OVERRIDE
19. ES_EVENT_TYPE_NOTIFY_XP_MALWARE_*

### Performance Optimization

#### Path-Based Muting
```swift
// Mute non-critical system paths
es_mute_path(client, "/System/Library/CoreServices", ES_MUTE_PATH_TYPE_PREFIX)
es_mute_path(client, "/usr/libexec", ES_MUTE_PATH_TYPE_PREFIX)

// Mute for specific events only
let events: [es_event_type_t] = [
    ES_EVENT_TYPE_NOTIFY_OPEN, 
    ES_EVENT_TYPE_NOTIFY_STAT
]
es_mute_path_events(client, "/Applications", ES_MUTE_PATH_TYPE_PREFIX, events, events.count)
```

#### Process-Based Muting
```swift
// Mute trusted system processes
es_mute_process(client, &auditToken)

// Mute specific events for a process
es_mute_process_events(client, &auditToken, events, eventCount)
```

#### Target Path Muting (Inverted)
```swift
// Only monitor specific sensitive paths
es_invert_muting(client, ES_MUTE_INVERSION_TYPE_PATH)

// Mute everything except:
es_mute_path(client, "/Library/Keychains", ES_MUTE_PATH_TYPE_TARGET_PREFIX)
es_mute_path(client, "/etc/authorization", ES_MUTE_PATH_TYPE_TARGET_LITERAL)
```

### Caching Strategies
```swift
// Cache AUTH decisions for performance
es_respond_auth_result(client, message, ES_AUTH_RESULT_ALLOW, true) // cache = true
```

---

## Troubleshooting

### ES Client Creation Fails

**ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED**
- Missing `com.apple.developer.endpoint-security.client` entitlement

**ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED**
- App not approved in Full Disk Access (TCC)
- Direct user to: `x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles` (macOS 13+)
- Or: `x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles` (macOS 12-)

**ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED**
- Not running as root

**ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS**
- Too many ES clients already connected

### No Events Received

- Check subscriptions: `es_subscriptions()`
- Check muted processes: `es_muted_processes_events()`
- Check muted paths: `es_muted_paths_events()`
- Check mute inversion: `es_muting_inverted()`
- Verify event supported on OS version

### Client Killed

- Not responding to AUTH events within deadline
- Check `message.deadline` and respond faster
- Implement timeout handling
- Consider muting non-critical paths

### Dropped Events

- `seq_num` gaps indicate dropped events
- Reduce event volume via muting
- Optimize event handler performance
- Process events asynchronously

---

## Resources

### Official Documentation
- [EndpointSecurity Framework](https://developer.apple.com/documentation/endpointsecurity)
- [Apple Platform Security Guide](https://support.apple.com/guide/security/welcome/web)

### Standards
- [FIDO2/WebAuthn Specifications](https://fidoalliance.org/specifications/)
- [NIST SP 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [CIS Benchmarks for macOS](https://www.cisecurity.org/benchmark/apple_os)

### Useful Commands
```bash
# List ES clients
sudo eslogger list

# Monitor ES events
sudo eslogger exec open | jq

# Check entitlements
codesign -d --entitlements - /path/to/app

# Check TCC database
sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access"
```

---

**End of Document**
