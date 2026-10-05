# N2 Support & Infrastructure Troubleshooting Playbook

This document details structured diagnostic playbooks for common Tier 2 (N2) enterprise Linux infrastructure incidents. Each playbook adheres to the standard ITIL Incident Management lifecycle: **Symptom → Diagnosis → Commands → Root Cause → Resolution → Verification**.

---

## Scenario 1: Critical systemd Service Failure / Crash Loop

### 1. Symptom
Users report an internal management service or application is completely unresponsive. The service fails to maintain an active status and reports `failed` or `degraded`.

### 2. Diagnosis
1. Inspect the service lifecycle status using `systemctl status <service_name>`.
2. Inspect unit exit codes and restart counters.
3. Review recent standard error and journal logs using `journalctl`.

### 3. Diagnostic Commands
```bash
# Check unit status, active state, and last exit code
systemctl status example-service.service --no-pager

# Review recent logs with priority filtering (err, warning)
journalctl -u example-service.service -n 50 --no-pager

# Check for resource exhaustion or cgroup limits
systemctl show example-service.service -p MainPID,SubState,ActiveState,Result
```

### 4. Probable Causes
- Configuration file syntax error or missing mandatory environment variable.
- File permission mismatch on socket or log directory (`Permission denied`).
- Port collision (another process already listening on the configured socket).

### 5. Resolution
```bash
# Verify configuration syntax
/usr/local/bin/example-app --config-test

# If port collision, identify offending process
sudo ss -tulpn | grep :<port>

# Fix permissions on runtime directories
sudo chown -R infra-service:infra-service /var/log/infra-lab
sudo chmod 750 /var/log/infra-lab

# Reload systemd configuration and restart
sudo systemctl daemon-reload
sudo systemctl restart example-service.service
```

### 6. Verification
```bash
# Confirm active running state
systemctl is-active example-service.service

# Verify watchdog passes audit
./scripts/service-watchdog.sh example-service.service
```

---

## Scenario 2: DNS Name Resolution & Network Routing Degradation

### 1. Symptom
Internal routines and automation jobs fail with errors such as `Temporary failure in name resolution` or `No route to host`. Direct IP connectivity may be partially functional.

### 2. Diagnosis
1. Verify host network interface status and default gateway assignment.
2. Check local DNS stub resolver state (`systemd-resolved` or `/etc/resolv.conf`).
3. Differentiate between Layer 3 (routing/gateway) and Layer 7 (DNS resolution) issues.

### 3. Diagnostic Commands
```bash
# Verify IP address and link state
ip -br addr show

# Verify default gateway routing table
ip route show

# Test gateway reachability
ping -c 3 $(ip route show default | awk '{print $3}')

# Check DNS resolver status and active nameservers
resolvectl status || cat /etc/resolv.conf

# Test resolution against multiple endpoints
getent ahosts one.one.one.one
```

### 4. Probable Causes
- Default gateway dropped or overwritten by DHCP lease renewal.
- Upstream DNS resolver unreachable or local resolver service (`systemd-resolved`) crashed.
- Firewall rule or MTU misconfiguration dropping fragmented packets.

### 5. Resolution
```bash
# Restart DNS stub resolver if unresponsive
sudo systemctl restart systemd-resolved.service

# If routing table dropped default gateway, restore lease
sudo ip route add default via <gateway_ip> dev <interface_name>

# Flush DNS caches
sudo resolvectl flush-caches
```

### 6. Verification
```bash
# Execute network verification script
./scripts/network-check.sh one.one.one.one dns.google "53,80,443"
```

---

## Scenario 3: CPU & Memory Exhaustion from Orphaned Processes

### 1. Symptom
System alerts trigger on CPU load exceeding 90% or RAM depletion causing sluggish response times and risking invocation of the Linux Out-of-Memory (OOM) killer.

### 2. Diagnosis
1. Identify high-consumption processes by CPU and Resident Memory (RES).
2. Differentiate between legitimate load spikes and runaway/leaked processes.
3. Check systemd slice resource allocation and OOM killer invocation logs.

### 3. Diagnostic Commands
```bash
# Check top processes sorted by CPU utilization
ps aux --sort=-%cpu | head -n 10

# Check top processes sorted by memory utilization
ps aux --sort=-%mem | head -n 10

# Check if OOM killer has terminated tasks recently
dmesg -T | grep -i -E "oom|killed process" || journalctl -k -g oom

# Inspect system load averages and memory availability
free -h
uptime
```

### 4. Probable Causes
- Memory leak in background worker or headless daemon.
- Orphaned process spawned during interrupted background job.
- Thread starvation or infinite loop in automation task.

### 5. Resolution
```bash
# Gracefully terminate the runaway process
kill -15 <PID>

# Verify process exit; if unresponsive after timeout, issue SIGKILL
sleep 3
kill -9 <PID> 2>/dev/null || true

# If service-managed, enforce memory limits via systemd drop-in
# Example: MemoryMax=2G in /etc/systemd/system/example.service.d/limits.conf
```

### 6. Verification
```bash
# Execute system health audit script
./scripts/system-health.sh
```
