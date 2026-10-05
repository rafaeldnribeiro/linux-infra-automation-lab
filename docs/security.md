# Security & Operational Hardening Baseline

This document outlines the security architecture and defensive engineering principles applied across the **Linux Infrastructure Automation Lab**.

---

## 1. Zero Trust Ingress & Perimeter Defense

- **No Inbound Public Ports**: The host does not expose SSH (port 22) or web services directly to public IPv4/IPv6 addresses.
- **Mesh VPN Overlay**: Administrative and programmatic interactions take place exclusively over an authenticated mesh network (WireGuard-based overlay).
- **Host Firewall (UFW / iptables)**:
  - Default Incoming: `DENY`
  - Default Outgoing: `ALLOW`
  - Explicit rule definitions apply strictly to authorized VPN interfaces.

---

## 2. Secrets Management & Credential Hygiene

- **Zero Hardcoded Secrets**: No passwords, API keys, tokens, or private certificates are stored in source code.
- **Git Hygiene**: An active `.gitignore` prevents inadvertent commits of `.env` files, SSH private keys (`id_*`), certificate bundles, and local log artifacts.
- **Secret Scanning Pre-Commit**: Automation scripts and repositories undergo periodic scanning for entropy and high-risk token patterns before public synchronization.

---

## 3. Principle of Least Privilege (PoLP)

- **Dedicated Service Accounts**: Background tasks run under dedicated system users (`infra-service`) with no interactive login shell (`/usr/sbin/nologin`).
- **systemd Sandboxing**:
  - `NoNewPrivileges=yes`: Disallows processes from acquiring new privileges via `setuid`/`setgid` binaries.
  - `ProtectSystem=strict`: Mounts `/usr`, `/boot`, and `/etc` read-only for service processes.
  - `ProtectHome=true`: Restricts access to user home directories.
  - `PrivateTmp=true`: Allocates isolated, ephemeral `/tmp` namespaces.

---

## 4. SSH & Remote Access Hardening

- **Key-Based Authentication Only**: Password authentication is disabled on administrative endpoints (`PasswordAuthentication no`).
- **Modern Cryptography**: Deprecated cipher suites and weak RSA key sizes are eliminated in favor of modern `ed25519` elliptic-curve algorithms.
- **Root Login Disabled**: Direct root access via SSH is strictly forbidden (`PermitRootLogin no`).

---

## 5. Telemetry, Audit Trails & Patch Management

- **Immutable Timestamping**: Automation and monitor routines produce structured UTC logs.
- **Automated Security Updates**: Essential security patches are evaluated and applied routinely via `unattended-upgrades` to mitigate zero-day vulnerabilities.
- **Resource Limits**: systemd cgroups restrict maximum memory and task ceilings (`TasksMax`, `MemoryMax`) to shield core system availability from Denial-of-Service (DoS) conditions.
