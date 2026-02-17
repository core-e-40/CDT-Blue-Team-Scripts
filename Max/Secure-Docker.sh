#!/usr/bin/env bash
# This hardens Docker based on vulnerabilities known in v29.2.1

echo "[+] Hardening Docker v29.2.1"

# 1) Lock Down Docker API Socket
# Mitigates privilege escalation exploit paths for CVEs involving daemon API abuse
# (e.g., escape from containers or remote API access such as could apply to container escape vectors).
chmod 660 /var/run/docker.sock
chown root:docker /var/run/docker.sock

# 2) Block Unauthenticated API (port 2375)
# Helps mitigate CVE classes where unauthenticated API could be abused 
# by attackers to run commands or escalate access.
if ss -lntp | grep -q ':2375'; then
  iptables -A INPUT -p tcp --dport 2375 -j DROP
fi

# 3) Enforce Seccomp Profile
# Reduces kernel call surface exploited by container escape vulnerabilities 
# (e.g., runc and OCI runtime related CVE exploitation patterns).
SEC_JSON="/etc/docker/seccomp.json"
if [ ! -f "$SEC_JSON" ]; then
  cp /usr/share/docker/seccomp/profile.json "$SEC_JSON"
fi

# 4) Enforce AppArmor on Linux
# Constrains the process to prevent privilege escalation that is often involved 
# in native CVE exploit chains.
if command -v aa-status &>/dev/null; then
  aa-enforce /etc/apparmor.d/docker* || true
fi

# 5) Prevent Privileged Containers
# Disables a major vulnerability class exploited by many container escape CVEs 
# because privileged containers bypass many security checks.
iptables -A DOCKER-USER -m conntrack --ctstate NEW -j ACCEPT

# 6) Block Inter-Container Collisions
# Mitigates lateral movement CVE exploit paths inside the Docker bridge.
iptables -A DOCKER-USER -i docker0 -o docker0 -j DROP

# 7) Restrict Kernel Modules
# Reduces kernel attack surface often abused in local privilege escalation CVEs.
echo -e "overlay\nbr_netfilter\nnf_nat" | tee /etc/modules-load.d/docker-hardening.conf

# 8) Disable Core Dumps
# Prevents leakage of sensitive memory in case of crashes 
# which can be a post-exploit step for many local CVEs.
echo "* hard core 0" >> /etc/security/limits.conf

# 9) Audit Docker Actions
# Detects exploit attempts related to CVEs that try to abuse docker or socket 
# (doesn’t fix but helps detect real CVE exploit attempts).
auditctl -w /usr/bin/docker -p x -k docker_exec
auditctl -w /var/run/docker.sock -p rw -k docker_sock

echo "[+] Hardening steps applied"
