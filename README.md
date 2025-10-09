# EndpointSecurity Events Reference Guide
## CrowdStrike, Beyond Identity, Jamf, and Truu

Complete reference for ES events used in security monitoring, identity management, FIDO2/WebAuthn, biometrics, and threat detection.

---

## Table of Contents

1. [Process Execution & Lifecycle](#process-execution--lifecycle)
2. [File System Operations](#file-system-operations)
3. [Authentication & Biometric Events](#authentication--biometric-events)
4. [Session & Login Monitoring](#session--login-monitoring)
5. [Authorization & Privilege Management](#authorization--privilege-management)
6. [Credential & Secret Access](#credential--secret-access)
7. [Man-in-the-Middle Attack Detection](#man-in-the-middle-attack-detection)
8. [Network & IPC Monitoring](#network--ipc-monitoring)
9. [Process Interaction](#process-interaction)
10. [Certificate & TLS Monitoring](#certificate--tls-monitoring)
11. [Device Attestation & Secure Enclave](#device-attestation--secure-enclave)
12. [Kernel Extensions & Drivers](#kernel-extensions--drivers)
13. [Configuration & Policy Management](#configuration--policy-management)
14. [Anti-Phishing & Browser Security](#anti-phishing--browser-security)
15. [Persistence Mechanisms](#persistence-mechanisms)
16. [OpenDirectory & Account Management](#opendirectory--account-management)
17. [File System Integrity](#file-system-integrity)
18. [Gatekeeper & Notarization](#gatekeeper--notarization)
19. [Malware Detection](#malware-detection)
20. [System Modifications](#system-modifications)
21. [Process Behavior Analysis](#process-behavior-analysis)
22. [Time & System Settings](#time--system-settings)
23. [Root Directory Changes](#root-directory-changes)
24. [Recommended Event Combinations](#recommended-event-combinations)

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

### TouchID & Biometric Authentication
- **ES_EVENT_TYPE_NOTIFY_AUTHENTICATION** - All authentication events
  - **TouchID Authentication:**
    - Type: `ES_AUTHENTICATION_TYPE_TOUCHID`
    - `touchid_mode`: Verification vs Identification
    - Contains `uid` of authenticated user
    - Success/failure status
    - Instigator process information
  
  - **Token-based Authentication (FIDO2/U2F/YubiKey):**
    - Type: `ES_AUTHENTICATION_TYPE_TOKEN`
    - `pubkey_hash`: Hash of the public key
    - `token_id`: Hardware token identifier
    - `kerberos_principal`: For Kerberos integration
    - Instigator process information
  
  - **OpenDirectory Authentication:**
    - Type: `ES_AUTHENTICATION_TYPE_OD`
    - Username, record type, record name
    - Node name (Local/LDAP/Active Directory)
    - Database path (for local nodes)
    - Instigator process information
  
  - **Apple Watch Auto Unlock:**
    - Type: `ES_AUTHENTICATION_TYPE_AUTO_UNLOCK`
    - Username being authenticated
    - Auto unlock type (machine unlock vs auth prompt)

---

## Session & Login Monitoring

### LoginWindow Sessions
- **ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGIN** - LoginWindow user login
  - Username (short name)
  - Graphical session ID
  - Session correlation identifier

- **ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGOUT** - LoginWindow user logout
  - Username
  - Graphical session ID
  - Session end tracking

- **ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOCK** - Screen lock events
  - Username
  - Graphical session ID
  - Lock timestamp

- **ES_EVENT_TYPE_NOTIFY_LW_SESSION_UNLOCK** - Screen unlock events
  - Username
  - Graphical session ID
  - Unlock method correlation

### Console Login
- **ES_EVENT_TYPE_NOTIFY_LOGIN_LOGIN** - `/usr/bin/login` authentication
  - Success/failure status
  - Failure message (if failed)
  - Username
  - UID (if successful)

- **ES_EVENT_TYPE_NOTIFY_LOGIN_LOGOUT** - Login logout events
  - Username
  - UID

### Remote Access Monitoring

#### Screen Sharing
- **ES_EVENT_TYPE_NOTIFY_SCREENSHARING_ATTACH** - Screen sharing connection established
  - Success/failure indicator
  - Source address type and address
  - Viewer Apple ID (if applicable)
  - Authentication type used
  - Authentication username
  - Session username
  - Existing session flag
  - Graphical session ID
  - **Critical for detecting remote takeover attempts**

- **ES_EVENT_TYPE_NOTIFY_SCREENSHARING_DETACH** - Screen sharing disconnection
  - Source address type and address
  - Viewer Apple ID (if applicable)
  - Graphical session ID

#### SSH Access
- **ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGIN** - SSH login attempts
  - Success/failure status
  - Result type (`es_openssh_login_result_type_t`):
    - Exceeded max tries
    - Root denied
    - Auth success
    - Auth failures (none, password, keyboard-interactive, public key, host-based, GSSAPI)
    - Invalid user
  - Source address type and address
  - Username
  - UID (if successful)
  - Connection-level event

- **ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGOUT** - SSH session termination
  - Source address type and address
  - Username
  - UID

---

## Authorization & Privilege Management

### Authorization Framework
- **ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_PETITION** - Authorization right requests
  - Instigator process (XPC caller)
  - Petitioner process (created petition)
  - Flags associated with petition
  - Array of rights being requested
  - Instigator and petitioner audit tokens

- **ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT** - Authorization decisions
  - Instigator process
  - Petitioner process
  - Return code (0 = success)
  - Array of results per right:
    - Right name
    - Rule class (user, rule, mechanism, allow, deny, unknown, invalid)
    - Granted flag
  - Instigator and petitioner audit tokens

### Privilege Escalation Detection
- **ES_EVENT_TYPE_NOTIFY_SETUID** - Process changes UID
  - Target UID
  - Privilege escalation indicator

- **ES_EVENT_TYPE_NOTIFY_SETGID** - Process changes GID
  - Target GID
  - Group privilege changes

- **ES_EVENT_TYPE_NOTIFY_SETEUID** - Process changes effective UID
  - Target effective UID
  - Temporary privilege elevation

- **ES_EVENT_TYPE_NOTIFY_SETEGID** - Process changes effective GID
  - Target effective GID
  - Temporary group privilege elevation

- **ES_EVENT_TYPE_NOTIFY_SETREUID** - Process changes real and effective UID
  - Real UID (ruid)
  - Effective UID (euid)
  - Complete UID transition

- **ES_EVENT_TYPE_NOTIFY_SETREGID** - Process changes real and effective GID
  - Real GID (rgid)
  - Effective GID (egid)
  - Complete GID transition

### Sudo & Su Operations
- **ES_EVENT_TYPE_NOTIFY_SUDO** - Sudo command execution
  - Success/failure indicator
  - Rejection info (if failed):
    - Plugin name
    - Plugin type (unknown, front-end, policy, I/O, audit, approval)
    - Failure message
  - From UID and username (optional)
  - To UID and username (optional)
  - Command being executed

- **ES_EVENT_TYPE_NOTIFY_SU** - Su command execution
  - Success/failure indicator
  - Failure message (if failed)
  - From UID and username
  - To UID and username (if successful)
  - Shell path
  - Argument count and array
  - Environment variable count and array
  - **Note:** Only emits on security-relevant events

---

## Credential & Secret Access

### Keychain Monitoring
- **ES_EVENT_TYPE_NOTIFY_OPEN** / **ES_EVENT_TYPE_AUTH_OPEN** - Keychain file access
  - Monitor paths:
    - `/Library/Keychains/`
    - `~/Library/Keychains/`
    - `~/Library/Keychains/login.keychain-db`
  - File flags (read/write)

- **ES_EVENT_TYPE_NOTIFY_READDIR** / **ES_EVENT_TYPE_AUTH_READDIR** - Keychain directory enumeration
  - Directory being read
  - Credential discovery attempts

### Password & Secret Modification
- **ES_EVENT_TYPE_NOTIFY_OD_MODIFY_PASSWORD** - OpenDirectory password changes
  - Instigator process
  - Error code (0 = success)
  - Account type (user, computer)
  - Account name
  - Node name (Local/LDAP/AD)
  - Database path

### Process Memory Access (Credential Dumping)
- **ES_EVENT_TYPE_NOTIFY_GET_TASK** / **ES_EVENT_TYPE_AUTH_GET_TASK** - Task control port access
  - Target process
  - Type (task_for_pid, expose_task, identity_token)
  - **Can read process memory and extract credentials**
  - Critical for detecting credential dumping tools

- **ES_EVENT_TYPE_NOTIFY_GET_TASK_READ** / **ES_EVENT_TYPE_AUTH_GET_TASK_READ** - Task read port
  - Target process
  - Type indicator
  - Read-only process access

- **ES_EVENT_TYPE_NOTIFY_GET_TASK_INSPECT** - Task inspect port
  - Target process
  - Type indicator
  - Limited inspection access

- **ES_EVENT_TYPE_NOTIFY_GET_TASK_NAME** - Task name port
  - Target process
  - Type indicator
  - Minimal process information

---

## Man-in-the-Middle Attack Detection

### Process Injection & Code Manipulation
- **ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE** - Thread injection attacks
  - Target process
  - Thread state (for thread_create_running, NULL for thread_create)
  - **Common MitM/hooking technique**
  - **Critical for detecting credential interception**

- **ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED** - Code signature invalidation
  - Fires when CS_VALID bit removed
  - First invalid page paged in
  - Explicit invalidation via csops(CS_OPS_MARKINVALID)
  - **Indicates runtime code modification**
  - **Potential hooking or tampering**
  - Does not fire if CS_HARD set

### Library Injection & Interposition
- **ES_EVENT_TYPE_NOTIFY_EXEC** - Monitor process execution for injection
  - Check environment variables:
    - `DYLD_INSERT_LIBRARIES`
    - `DYLD_LIBRARY_PATH`
    - Other DYLD_* variables
  - Inspect loaded libraries
  - Detect dylib injection

- **ES_EVENT_TYPE_NOTIFY_MMAP** / **ES_EVENT_TYPE_AUTH_MMAP** - Memory mapping
  - Protection flags
  - Max protection value
  - Mapping flags
  - File position
  - Source file being mapped
  - **Detect suspicious library loading**
  - **Monitor shared memory regions**

- **ES_EVENT_TYPE_NOTIFY_MPROTECT** / **ES_EVENT_TYPE_AUTH_MPROTECT** - Memory protection changes
  - New protection value
  - Base address
  - Size of memory region
  - **Runtime code modification**
  - **Self-modifying code detection**

### Process Debugging & Manipulation
- **ES_EVENT_TYPE_NOTIFY_TRACE** - Process attachment (ptrace)
  - Target process being attached
  - **Debugger attachment attempts**
  - **Can intercept credentials in memory**
  - **Used for process inspection**

- **ES_EVENT_TYPE_NOTIFY_PROC_SUSPEND_RESUME** - Process suspension/resume
  - Target process
  - Type (suspend, resume, shutdown_sockets)
  - **Potential for manipulation during suspension**
  - **Can pause authentication flows**

---

## Network & IPC Monitoring

### Unix Domain Sockets
- **ES_EVENT_TYPE_NOTIFY_UIPC_BIND** / **ES_EVENT_TYPE_AUTH_UIPC_BIND** - Socket creation
  - Directory for socket file
  - Filename of socket
  - Mode of socket file
  - **Monitor authentication service sockets**

- **ES_EVENT_TYPE_NOTIFY_UIPC_CONNECT** / **ES_EVENT_TYPE_AUTH_UIPC_CONNECT** - Socket connections
  - Socket file being connected to
  - Communications domain
  - Socket type
  - Protocol
  - **IPC to authentication services**
  - **Potential credential interception points**

### XPC Service Connections
- **ES_EVENT_TYPE_NOTIFY_XPC_CONNECT** - XPC service connections
  - Service name
  - Service domain type (system, user, user login, session, PID, manager, port, GUI)
  - **Monitor authentication-related services**
  - **Detect unauthorized access to identity services**

---

## Process Interaction

### Inter-Process Signals
- **ES_EVENT_TYPE_NOTIFY_SIGNAL** / **ES_EVENT_TYPE_AUTH_SIGNAL** - Process signal delivery
  - Signal number
  - Target process receiving signal
  - Instigator process (if applicable)
  - **Does not fire for self-signaling**
  - **Detect process termination attempts**

### Process Control
- **ES_EVENT_TYPE_NOTIFY_PROC_CHECK** / **ES_EVENT_TYPE_AUTH_PROC_CHECK** - Process information retrieval access control
  - Target process (optional)
  - Check type (listpids, pidinfo, pidfdinfo, setcontrol, pidfileportinfo, dirtycontrol, pidrusage)
  - Flavor parameter
  - **Process enumeration detection**

---

## Certificate & TLS Monitoring

### Certificate File Access
- **ES_EVENT_TYPE_NOTIFY_OPEN** / **ES_EVENT_TYPE_AUTH_OPEN** - Certificate file access
  - Monitor paths:
    - `/System/Library/Keychains/`
    - `/Library/Keychains/`
    - Custom certificate stores
  - File flags

### Certificate Trust Store Modifications
- **ES_EVENT_TYPE_NOTIFY_CREATE** / **ES_EVENT_TYPE_AUTH_CREATE** - New certificate installation
  - Certificate file path
  - Destination information

- **ES_EVENT_TYPE_NOTIFY_UNLINK** / **ES_EVENT_TYPE_AUTH_UNLINK** - Certificate removal
  - Certificate file being removed

- **ES_EVENT_TYPE_NOTIFY_WRITE** - Certificate trust database writes
  - Target file modifications

### Certificate Metadata
- **ES_EVENT_TYPE_NOTIFY_SETEXTATTR** / **ES_EVENT_TYPE_AUTH_SETEXTATTR** - Extended attributes
  - Quarantine flags on certificates
  - Trust settings modifications
  - Custom certificate metadata

---

## Device Attestation & Secure Enclave

### IOKit Device Access
- **ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN** / **ES_EVENT_TYPE_AUTH_IOKIT_OPEN** - IOKit service connection
  - User client type
  - User client class (meta class name)
  - Parent registry ID
  - Parent path in IOKit device tree
  - **Secure Enclave Processor (SEP) access**
  - **Touch ID sensor access**
  - **Hardware token/FIDO2 device access**
  - **Does not correspond to device attachment**

### File Provider & Cloud Storage
- **ES_EVENT_TYPE_NOTIFY_FILE_PROVIDER_MATERIALIZE** - File materialization from cloud
  - Instigator process
  - Source (staged file)
  - Target (destination)
  - Instigator audit token
  - **Cloud credential files**
  - **Synced keychain items**

- **ES_EVENT_TYPE_NOTIFY_FILE_PROVIDER_UPDATE** - File updates via FileProvider
  - Source (staged file with updated contents)
  - Target path (destination)
  - **Monitor credential file synchronization**

---

## Kernel Extensions & Drivers

### Kernel Extension Loading
- **ES_EVENT_TYPE_NOTIFY_KEXTLOAD** / **ES_EVENT_TYPE_AUTH_KEXTLOAD** - Kernel extension loading
  - Signing identifier of kext
  - **System-level persistence**
  - **Potential for credential interception at kernel level**
  - **Not all AUTH events can be delivered**

- **ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD** - Kernel extension unloading
  - Signing identifier of kext being unloaded

---

## Configuration & Policy Management

### MDM Profile Installation
- **ES_EVENT_TYPE_NOTIFY_PROFILE_ADD** - Configuration profile installation
  - Instigator process
  - Is update flag
  - Profile information:
    - Identifier
    - UUID
    - Install source (managed vs install)
    - Organization
    - Display name
    - Scope
  - Instigator audit token
  - **Track identity/authentication policy changes**

- **ES_EVENT_TYPE_NOTIFY_PROFILE_REMOVE** - Profile removal
  - Instigator process
  - Profile information
  - Instigator audit token

### TCC (Transparency, Consent & Control)
- **ES_EVENT_TYPE_NOTIFY_TCC_MODIFY** - TCC permission changes
  - Service name
  - Identity (application)
  - Identity type (bundle ID, executable path, policy ID, file provider domain ID)
  - Update type (create, modify, delete)
  - Instigator audit token and process
  - Responsible audit token and process
  - Authorization right (denied, unknown, allowed, limited, etc.)
  - Reason (user consent, user set, system set, policy, etc.)
  - **Monitor access to authentication services**

### Access Control Lists
- **ES_EVENT_TYPE_NOTIFY_SETACL** / **ES_EVENT_TYPE_AUTH_SETACL** - Set file ACL
  - Target file
  - Set or clear operation
  - ACL structure (if setting)
  - **Monitor authentication file ACL changes**

---

## Anti-Phishing & Browser Security

### Browser Extension Monitoring
- **ES_EVENT_TYPE_NOTIFY_EXEC** - Browser process launches
  - Process arguments
  - Environment variables
  - **Detect suspicious browser profiles**
  - **Monitor for unauthorized extensions**

- **ES_EVENT_TYPE_NOTIFY_OPEN** / **ES_EVENT_TYPE_AUTH_OPEN** - Browser extension access
  - Monitor paths:
    - `~/Library/Application Support/[Browser]/Extensions/`
    - Extension manifest files
    - Preference files with extension lists

### Clipboard Monitoring
- **ES_EVENT_TYPE_NOTIFY_OPEN** / **ES_EVENT_TYPE_AUTH_OPEN** - Pasteboard access
  - Monitor access patterns
  - **Detect credential harvesting from clipboard**

---

## Persistence Mechanisms

### Launch Items & Auto-Start
- **ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD** - Launch agent/daemon registration
  - Instigator process
  - App process
  - BTM launch item:
    - Item type (user item, app, login item, agent, daemon)
    - Legacy flag
    - Managed flag (MDM)
    - UID
    - Item URL
    - App URL
  - Executable path (optional)
  - Instigator and app audit tokens
  - **Can emit for previously seen items**

- **ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_REMOVE** - Launch item removal
  - Instigator process
  - App process
  - BTM launch item
  - Instigator and app audit tokens

### Mount Operations
- **ES_EVENT_TYPE_NOTIFY_MOUNT** / **ES_EVENT_TYPE_AUTH_MOUNT** - File system mount
  - statfs structure
  - Device disposition (external, internal, network, virtual, nullfs, unknown)
  - **Monitor suspicious volume mounting**

- **ES_EVENT_TYPE_NOTIFY_UNMOUNT** - File system unmount
  - statfs structure

- **ES_EVENT_TYPE_NOTIFY_REMOUNT** / **ES_EVENT_TYPE_AUTH_REMOUNT** - File system remount
  - statfs structure
  - Remount flags
  - Device disposition

---

## OpenDirectory & Account Management

### User Account Operations
- **ES_EVENT_TYPE_NOTIFY_OD_CREATE_USER** - User account creation
  - Instigator process
  - Error code
  - User name
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_DELETE_USER** - User account deletion
  - Instigator process
  - Error code
  - User name
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_DISABLE_USER** - User account disabled
  - Instigator process
  - Error code
  - User name
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_ENABLE_USER** - User account enabled
  - Instigator process
  - Error code
  - User name
  - Node name
  - Database path
  - Instigator audit token

### Group Management
- **ES_EVENT_TYPE_NOTIFY_OD_CREATE_GROUP** - Group creation
  - Instigator process
  - Error code
  - Group name
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_DELETE_GROUP** - Group deletion
  - Instigator process
  - Error code
  - Group name
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD** - Member added to group
  - Instigator process
  - Error code
  - Group name
  - Member identity (UUID or name)
  - Member type (user name, user UUID, group UUID)
  - Node name
  - Database path
  - Instigator audit token
  - **Does not guarantee member was actually added**

- **ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE** - Member removed from group
  - Instigator process
  - Error code
  - Group name
  - Member identity
  - Member type
  - Node name
  - Database path
  - Instigator audit token
  - **Does not guarantee member was actually removed**

- **ES_EVENT_TYPE_NOTIFY_OD_GROUP_SET** - Group membership replaced
  - Instigator process
  - Error code
  - Group name
  - Members array (can be empty)
  - Member type
  - Member count
  - Node name
  - Database path
  - Instigator audit token

### Attribute Modification
- **ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_VALUE_ADD** - Attribute value added
  - Instigator process
  - Error code
  - Record type (user, group)
  - Record name
  - Attribute name
  - Attribute value
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_VALUE_REMOVE** - Attribute value removed
  - Instigator process
  - Error code
  - Record type
  - Record name
  - Attribute name
  - Attribute value
  - Node name
  - Database path
  - Instigator audit token

- **ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_SET** - Attribute set/replaced
  - Instigator process
  - Error code
  - Record type
  - Record name
  - Attribute name
  - Attribute value count and array (can be empty)
  - Node name
  - Database path
  - Instigator audit token

---

## File System Integrity

### File Control Operations
- **ES_EVENT_TYPE_NOTIFY_FCNTL** / **ES_EVENT_TYPE_AUTH_FCNTL** - File control
  - Target file
  - Command (`cmd` argument to fcntl(2))
  - **Monitor file descriptor manipulation**

---

## Gatekeeper & Notarization

### User Override Events
- **ES_EVENT_TYPE_NOTIFY_GATEKEEPER_USER_OVERRIDE** - Gatekeeper bypass
  - File type (path string vs es_file_t)
  - File (path or file structure)
  - SHA256 hash (optional, if file < 100MB)
  - Signing info (optional):
    - CDHash
    - Signing ID
    - Team ID
  - **User explicitly allowed unsigned/untrusted software**
  - **Potential indicator of social engineering**
  - **Hashes calculated in usermode by Gatekeeper**

---

## Malware Detection

### XProtect Integration
- **ES_EVENT_TYPE_NOTIFY_XP_MALWARE_DETECTED** - XProtect malware detection
  - Signature version
  - Malware identifier
  - Incident identifier (links detect/remediate events)
  - Detected path (not necessarily malicious binary)
  - Detected executable (malicious binary path)
  - **Can have multiple detected/remediated events per incident**

- **ES_EVENT_TYPE_NOTIFY_XP_MALWARE_REMEDIATED** - XProtect remediation
  - Signature version
  - Malware identifier
  - Incident identifier
  - Action type (e.g., "path_delete")
  - Success indicator
  - Result description
  - Remediated path (optional)
  - Remediated process audit token (optional)

### Code Signature Validation
- **ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED** - Code signature invalidation
  - **Indicates process code modified at runtime**
  - **Does not fire if CS_HARD set**

---

## System Modifications

### Privilege Changes
- All `SETUID`, `SETGID`, `SETEUID`, `SETEGID`, `SETREUID`, `SETREGID` events (covered in [Authorization & Privilege Management](#authorization--privilege-management))

---

## Process Behavior Analysis

### Process Execution Details
- **ES_EVENT_TYPE_NOTIFY_EXEC** - Comprehensive execution information
  - Target process (new process after exec)
  - Dyld exec path
  - Script path (if shell script)
  - Current working directory
  - Last file descriptor number
  - Image CPU type and subtype
  - Arguments (use `es_exec_arg_count()` and `es_exec_arg()`)
  - Environment variables (use `es_exec_env_count()` and `es_exec_env()`)
  - File descriptors (use `es_exec_fd_count()` and `es_exec_fd()`)
  - **Check for credential parameters in arguments**
  - **Check for tokens/keys in environment variables**
  - **Check for inherited sensitive file descriptors**

- **ES_EVENT_TYPE_NOTIFY_FORK** - Process creation
  - Child process information
  - **Track process lineage**
  - **Detect suspicious process trees**

### PTY Operations
- **ES_EVENT_TYPE_NOTIFY_PTY_GRANT** - Pseudoterminal granted
  - Device (major and minor numbers)

- **ES_EVENT_TYPE_NOTIFY_PTY_CLOSE** - Pseudoterminal closed
  - Device (major and minor numbers)

---

## Time & System Settings

### System Clock Manipulation
- **ES_EVENT_TYPE_NOTIFY_SETTIME** / **ES_EVENT_TYPE_AUTH_SETTIME** - System time modification
  - **Can affect certificate validation**
  - **Can impact session timeouts**
  - **Potential replay attack enabler**
  - **Not fired if process has `com.apple.private.settime` entitlement**
  - **May fail even if AUTH allowed**

---

## Root Directory Changes

### Chroot Detection
- **ES_EVENT_TYPE_NOTIFY_CHROOT** / **ES_EVENT_TYPE_AUTH_CHROOT** - Change root directory
  - Target directory (new root)
  - **Can hide files/processes**
  - **Sandbox escape attempts**
  - **Container/jail creation**

---

## Recommended Event Combinations

### FIDO2/WebAuthn Flow Monitoring
