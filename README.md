# EndpointSecurity Events Reference Guide
## CrowdStrike, Beyond Identity, Jamf, and Truu

Complete reference for ES events used in security monitoring, identity management, FIDO2/WebAuthn, biometrics, TouchID, SSO, PlatformSSO, and threat detection.

---

## Table of Contents

1. [Process Execution & Lifecycle](#process-execution--lifecycle)
2. [File System Operations](#file-system-operations)
3. [Authentication & Biometric Events](#authentication--biometric-events)
   - [TouchID & Biometric Authentication](#touchid--biometric-authentication)
   - [FIDO2 & WebAuthn](#fido2--webauthn)
   - [Token-Based Authentication](#token-based-authentication)
   - [OpenDirectory Authentication](#opendirectory-authentication)
   - [Apple Watch Auto Unlock](#apple-watch-auto-unlock)
4. [Single Sign-On (SSO) & Platform SSO](#single-sign-on-sso--platform-sso)
5. [Session & Login Monitoring](#session--login-monitoring)
   - [LoginWindow Sessions](#loginwindow-sessions)
   - [Console Login](#console-login)
   - [Remote Access](#remote-access)
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

---

## Process Execution & Lifecycle

### Basic Process Events
- **ES_EVENT_TYPE_NOTIFY_EXEC** - Monitor all process executions
  - Complete execution details with arguments
  - Environment variables (tokens/keys detection)
  - File descriptors (inherited sensitive FDs)
  - Script path (shell script execution)
  - Current working directory
  - CPU type and subtype information
  
- **ES_EVENT_TYPE_AUTH_EXEC** - Authorization control over process execution
  - Block malicious executables
  - Enforce application whitelisting
  - Supports caching for performance

- **ES_EVENT_TYPE_NOTIFY_FORK** - Track process creation
  - Child process information
  - Process lineage tracking
  - Detect suspicious process trees

- **ES_EVENT_TYPE_NOTIFY_EXIT** - Process termination
  - Exit status information
  - Process cleanup monitoring

---

## File System Operations

### File Access & Modification
- **ES_EVENT_TYPE_NOTIFY_OPEN** / **ES_EVENT_TYPE_AUTH_OPEN** - File access monitoring
  - File flags (read/write/execute)
  - Monitor keychain access
  - Certificate file access
  - Configuration file access

- **ES_EVENT_TYPE_NOTIFY_CLOSE** - File closure with modification tracking
  - `modified` flag indicates if file was changed
  - `was_mapped_writable` flag for memory-mapped modifications
  - Critical for detecting credential file changes

- **ES_EVENT_TYPE_NOTIFY_WRITE** - File write operations
  - Monitor writes to sensitive files:
    - `/etc/authorization`
    - `/etc/pam.d/`
    - `/var/db/dslocal/nodes/Default/users/`
    - SSH `authorized_keys` files

### File Creation & Deletion
- **ES_EVENT_TYPE_NOTIFY_CREATE** / **ES_EVENT_TYPE_AUTH_CREATE** - File creation
  - New authentication configuration files
  - Certificate installation detection
  - Destination type (existing file vs new path)
  - Optional ACL information

- **ES_EVENT_TYPE_NOTIFY_UNLINK** / **ES_EVENT_TYPE_AUTH_UNLINK** - File deletion
  - Authentication log deletion
  - Certificate removal
  - Parent directory information

- **ES_EVENT_TYPE_NOTIFY_RENAME** / **ES_EVENT_TYPE_AUTH_RENAME** - File renaming/moving
  - Source and destination paths
  - Destination type (existing file vs new path)
  - Can fire multiple times for single syscall

### File Copying & Cloning
- **ES_EVENT_TYPE_NOTIFY_CLONE** / **ES_EVENT_TYPE_AUTH_CLONE** - File cloning
  - Source file
  - Target directory and name
  - APFS clone operations

- **ES_EVENT_TYPE_NOTIFY_COPYFILE** / **ES_EVENT_TYPE_AUTH_COPYFILE** - Copy file operations
  - Source and target file
  - Mode and flags
  - Not the same as `copyfile(3)`

### File Attributes & Extended Attributes
- **ES_EVENT_TYPE_NOTIFY_SETEXTATTR** / **ES_EVENT_TYPE_AUTH_SETEXTATTR** - Set extended attributes
  - Certificate quarantine flags
  - Trust settings modifications
  - Custom metadata

- **ES_EVENT_TYPE_NOTIFY_GETEXTATTR** / **ES_EVENT_TYPE_AUTH_GETEXTATTR** - Read extended attributes
  - Monitor xattr enumeration
  - Security attribute access

- **ES_EVENT_TYPE_NOTIFY_DELETEEXTATTR** / **ES_EVENT_TYPE_AUTH_DELETEEXTATTR** - Delete extended attributes
  - Remove quarantine flags
  - Clear security metadata

- **ES_EVENT_TYPE_NOTIFY_LISTEXTATTR** / **ES_EVENT_TYPE_AUTH_LISTEXTATTR** - List extended attributes
  - Xattr discovery/enumeration
  - Reconnaissance activity

### File Metadata Operations
- **ES_EVENT_TYPE_NOTIFY_SETMODE** / **ES_EVENT_TYPE_AUTH_SETMODE** - Modify file mode/permissions
  - Permission changes on sensitive files
  - Privilege escalation attempts

- **ES_EVENT_TYPE_NOTIFY_SETFLAGS** / **ES_EVENT_TYPE_AUTH_SETFLAGS** - Modify file flags
  - Immutable flag changes
  - Hidden file flag modifications

- **ES_EVENT_TYPE_NOTIFY_SETOWNER** / **ES_EVENT_TYPE_AUTH_SETOWNER** - Modify file ownership
  - UID and GID changes
  - Ownership of authentication files

- **ES_EVENT_TYPE_NOTIFY_SETATTRLIST** / **ES_EVENT_TYPE_AUTH_SETATTRLIST** - Set file system attributes
  - Bulk attribute modifications
  - attrlist structure provided

- **ES_EVENT_TYPE_NOTIFY_GETATTRLIST** / **ES_EVENT_TYPE_AUTH_GETATTRLIST** - Retrieve file system attributes
  - Attribute list queries
  - File system metadata access

- **ES_EVENT_TYPE_NOTIFY_UTIMES** / **ES_EVENT_TYPE_AUTH_UTIMES** - Change file access/modification times
  - Timestamp manipulation
  - Anti-forensics technique

### File Linking
- **ES_EVENT_TYPE_NOTIFY_LINK** / **ES_EVENT_TYPE_AUTH_LINK** - Hard link creation
  - Source and target directory
  - Target filename
  - Can enable privilege escalation

- **ES_EVENT_TYPE_NOTIFY_READLINK** / **ES_EVENT_TYPE_AUTH_READLINK** - Symbolic link resolution
  - Symlink target discovery
  - Path traversal detection

### File Truncation
- **ES_EVENT_TYPE_NOTIFY_TRUNCATE** / **ES_EVENT_TYPE_AUTH_TRUNCATE** - File truncation
  - Log file clearing
  - Evidence destruction

### Directory Operations
- **ES_EVENT_TYPE_NOTIFY_READDIR** / **ES_EVENT_TYPE_AUTH_READDIR** - Directory enumeration
  - Keychain directory listing
  - Certificate store enumeration
  - Configuration discovery

- **ES_EVENT_TYPE_NOTIFY_CHDIR** / **ES_EVENT_TYPE_AUTH_CHDIR** - Change working directory
  - Process navigation patterns
  - Target directory information

### File Lookup
- **ES_EVENT_TYPE_NOTIFY_LOOKUP** - File system object lookup
  - Source directory
  - Relative target path
  - Path may contain untrusted user input

### File Statistics
- **ES_EVENT_TYPE_NOTIFY_STAT** - View stat information
  - File metadata queries
  - Reconnaissance activity

- **ES_EVENT_TYPE_NOTIFY_ACCESS** - Test file access permissions
  - Access permission checks
  - Mode parameter provided

### Other File Operations
- **ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA** / **ES_EVENT_TYPE_AUTH_EXCHANGEDATA** - Atomic data exchange between files
  - File1 and file2 swap
  - Atomic file replacement

- **ES_EVENT_TYPE_NOTIFY_FSGETPATH** / **ES_EVENT_TYPE_AUTH_FSGETPATH** - Retrieve file system path from FSID
  - Path resolution
  - File system queries

- **ES_EVENT_TYPE_NOTIFY_DUP** - File descriptor duplication
  - FD inheritance tracking
  - Sensitive descriptor propagation

### File Search
- **ES_EVENT_TYPE_NOTIFY_SEARCHFS** / **ES_EVENT_TYPE_AUTH_SEARCHFS** - Search volume/filesystem
  - Attribute list for search
  - Volume being searched
  - Bulk file discovery

---

## Authentication & Biometric Events

### Overview
The **ES_EVENT_TYPE_NOTIFY_AUTHENTICATION** event is the primary event for monitoring all authentication methods on macOS. This single event type encompasses multiple authentication mechanisms through the `es_authentication_type_t` enum.

**Event Structure:**
```c
struct es_event_authentication_t {
    bool success;                    // Authentication result
    es_authentication_type_t type;   // Type of authentication
    union data;                      // Type-specific data
}
