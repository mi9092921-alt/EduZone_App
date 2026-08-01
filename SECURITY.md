# SECURITY.md — EduZone Student App Security & Certificate Pinning

This document describes the security model, network protections, and Certificate Pinning implementation for **EduZone Student App**.

---

## 1. Certificate Pinning (SEC-001)

### 1.1 Threat Model & Objective
Standard TLS relies on the host device's OS Certificate Store, which trusts over 100+ public Certificate Authorities (CAs). On compromised devices, public Wi-Fi access points, or networks with custom CA root injection, an attacker can intercept HTTPS traffic, inspect signed video URLs, and steal authentication tokens via Man-In-The-Middle (MITM) attacks.

**Certificate Pinning** ensures the application ONLY trusts pre-approved TLS certificates presented by EduZone servers and Supabase infrastructure, rejecting all other certificates—even if signed by a standard public CA.

---

## 2. Architecture & Implementation

The implementation is located in [`lib/core/network/certificate_pinning.dart`](file:///d:/projects/EduZone/flutter_projects/EduZone_App/lib/core/network/certificate_pinning.dart) using Dart's native `dart:io` `SecurityContext`.

### 2.1 Core Components
1. **`SecurityContext(withTrustedRoots: false)`**:
   - Disables trust in the device's system CAs.
   - Trust is explicitly built using `setTrustedCertificatesBytes()`.
2. **`applyCertificatePinning(Dio dio, ...)`**:
   - Configures `IOHttpClientAdapter` on `Dio` instances to enforce TLS certificate pinning.
   - Applied directly in [`DownloadManager`](file:///d:/projects/EduZone/flutter_projects/EduZone_App/lib/features/downloads/data/services/download_manager.dart#L419-L425) for secure video and media downloads.
3. **`createPinnedHttpClient(...)`**:
   - Generates a pinned `dart:io` `HttpClient` for use with standard Dart HTTP requests and `package:http`.
   - Applied in [`SupabaseService.initialize()`](file:///d:/projects/EduZone/flutter_projects/EduZone_App/lib/core/network/supabase_client.dart#L17-L24) via `IOClient`.

---

## 3. Pinned Certificate Registry

| File | Subject | Issuer | Type | Valid Until | Purpose |
|---|---|---|---|---|---|
| `assets/certs/supabase.pem` | `CN=supabase.com` | `Let's Encrypt YR1` | **Leaf** | 2026-10-09 | Primary pin for `supabase.com` |
| `assets/certs/backup_ca.pem` | `CN=ISRG Root YR` | `Internet Security Research Group` | **Root CA** | 2032-09-02 | Backup pin — root CA for **all** Let's Encrypt Gen Y intermediates (`YR1`, `YR2`, `YR3`) |

> [!IMPORTANT]
> `backup_ca.pem` is the **Let's Encrypt ISRG Root YR root CA** — not a single intermediate or leaf certificate.
> Because Let's Encrypt distributes issuance across siblings (`YR1`, `YR2`, `YR3`), pinning `ISRG Root YR` directly ensures:
> - Connections to `*.supabase.co` are trusted regardless of which sibling CA (`YR1`/`YR2`/`YR3`) issues the cert upon auto-renewal.
> - Maximum stability (valid until 2032) without risk of app lockouts when Supabase rotates intermediate issuers.

---

## 4. How to Update Certificates

### 4.1 Refreshing `supabase.pem` (leaf — renews ~annually)

```bash
# Extract fresh leaf cert from supabase.com
openssl s_client -connect supabase.com:443 \
  -servername supabase.com </dev/null 2>/dev/null \
  | openssl x509 -outform PEM > assets/certs/supabase.pem
```

### 4.2 Refreshing `backup_ca.pem` (ISRG Root YR — valid until 2032)

`ISRG Root YR` is available directly via AIA issuer URL `http://yr.i.lencr.org/`:

```bash
curl -o assets/certs/backup_ca.pem http://yr.i.lencr.org/
# Convert DER to PEM format if fetched in DER format:
openssl x509 -inform DER -in assets/certs/backup_ca.pem -outform PEM -out assets/certs/backup_ca.pem
```

### 4.3 Rotation Strategy

- **Leaf renewal** (`supabase.pem`): Update before expiry. `ISRG Root YR` pin ensures no downtime during the window between renewal and app update.
- **Root CA renewal** (`backup_ca.pem`): Root CAs remain valid for 10-20 years. Ship new root CA PEMs years in advance of any scheduled deprecation.

---

## 5. Verification & Testing via mitmproxy / Charles

### 5.1 Verification Procedure
1. Install and start [mitmproxy](https://mitmproxy.org/) or Charles Proxy on your development machine.
2. Configure the mobile device or emulator proxy to point to mitmproxy.
3. Install the mitmproxy CA certificate on the device.
4. Launch EduZone Student App and attempt to download a video or perform API operations.

### 5.2 Expected Behavior
- **With Pinning Enabled**: The TLS handshake fails immediately with a `HandshakeException` or `TlsException` because mitmproxy's certificate is not in the pinned certificate set. No sensitive data or video segments are transmitted over the proxy.
- **Without Pinning (Unprotected)**: The device trusts the installed proxy CA certificate and allows interception (demonstrating why SEC-001 is critical).

---

## 6. Client Pinning Matrix & SDK Capabilities

| Network Client | Target Traffic | Pinning Status | Mechanism / Notes |
|---|---|---|---|
| **Dio (`DownloadManager`)** | Video streams, encrypted segments, parallel chunk downloads | **Enforced** | `applyCertificatePinning` via `IOHttpClientAdapter` |
| **Supabase REST / Auth Client** | Auth tokens, database queries, RPCs, Storage downloads | **Enforced** | `IOClient(createPinnedHttpClient(...))` passed to `Supabase.initialize(httpClient: ...)` |
| **Supabase Realtime (WebSockets)** | Real-time channels & notifications | Native WebSocket | WebSockets in Flutter use `WebSocket.connect` from `dart:io`. Handled through native platform sockets. |

---

## 7. Architectural Clarification — External CDN Downloads (SEC-001 Scope)

### 7.1 Video Download Source
The `DownloadManager._downloadWithDio()` method fetches video segments from **external Google CDN hosts** (`googlevideo.com`, `rr*.sn-*.googlevideo.com`, etc.) — confirmed by `User-Agent` and `Referer: https://www.youtube.com/` headers in [download_manager.dart L178-L184](file:///d:/projects/EduZone/flutter_projects/EduZone_App/lib/features/downloads/data/services/download_manager.dart#L178-L184).

Google's CDN uses **dynamically rotating leaf certificates** across hundreds of edge nodes. Pinning a static leaf or even a single intermediate CA to these endpoints is architecturally infeasible and would break downloads on every CDN rotation.

### 7.2 Domain-Scoped Pinning Decision

| Traffic Type | Host Pattern | Pinning Applied | Rationale |
|---|---|---|---|
| **Supabase API / Storage / Auth** | `*.supabase.co`, `*.supabase.com` | ✅ **YES — SEC-001** | Static infrastructure, stable certs. |
| **Video CDN downloads** | `*.googlevideo.com`, `rr*.sn-*` | ❌ **Exempt** — Standard TLS | Dynamic rotating certs; pinning infeasible. Standard TLS validation applies. |

`isSupabaseHost(url)` is called before every `Dio` instantiation. Pinning is applied **only** when the URL resolves to a Supabase host. CDN URLs fall through to standard OS-trust TLS.

### 7.3 `package:http` as Direct Dependency

`package:http` was previously a transitive dependency (pulled in by `supabase_flutter`). Since `SupabaseService.initialize()` now directly imports and uses `http.IOClient`, it has been promoted to a **direct** dependency in `pubspec.yaml`. This prevents silent breakage if `supabase_flutter` ever drops its own `http` dependency in a future upgrade.

---

- [x] `applyCertificatePinning` invoked at real Dio instantiation points (`DownloadManager`).
- [x] `Supabase.initialize` configured with custom pinned `IOClient`.
- [x] Multi-certificate rotation supported via primary and backup PEM assets.
- [x] Unit tests in `test/core/network/certificate_pinning_test.dart`.
- [x] Security documentation and mitmproxy verification instructions present in `SECURITY.md`.
