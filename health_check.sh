#!/usr/bin/env bash
# vm-healthcheck.sh
# Usage:
#   ./vm-healthcheck.sh          # prints Healthy or Unhealthy
#   ./vm-healthcheck.sh explain  # prints metrics details then Healthy/Unhealthy
#
# Note: This checks the root filesystem (/) for disk usage.
# Behavior: "Healthy" is printed only if ALL three metrics (CPU, memory, disk) are < 60%.

set -u

THRESHOLD=60
EXPLAIN=false
if [[ "${1:-}" == "explain" ]]; then
  EXPLAIN=true
fi

# CPU usage over 1 second (percentage, rounded)
get_cpu_usage() {
  # read counters from /proc/stat
  read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 guest1 < /proc/stat
  total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
  sleep 1
  read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 guest2 < /proc/stat
  total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
  total_delta=$((total2 - total1))
  idle_delta=$((idle2 - idle1))
  if [[ $total_delta -le 0 ]]; then
    echo 0
    return
  fi
  # compute usage = (1 - idle_delta/total_delta) * 100, rounded
  cpu_pct=$(awk -v td="$total_delta" -v id="$idle_delta" 'BEGIN { printf "%.0f", (1 - id/td) * 100 }')
  echo "$cpu_pct"
}

# Memory usage percentage (uses "available" if present)
get_mem_usage() {
  # Use bytes for precision
  if ! free_out=$(free -b 2>/dev/null); then
    echo "0"
    return
  fi
  # parse total and available (free's "available" is best estimate of unused memory)
  mem_total=$(awk '/^Mem:/ {print $2}' <<<"$free_out")
  # On some very old systems, "available" may not exist; fall back to total - free - buff/cache if needed
  mem_available=$(awk '/^Mem:/ {print $7}' <<<"$free_out")
  if [[ -z "$mem_available" || "$mem_available" == "0" ]]; then
    # compute available = free + buff/cache (fields: total, used, free, shared, buff/cache, available)
    # If $7 not present fallback: free + buff/cache (fields differ on older free)
    mem_free=$(awk '/^Mem:/ {print $4}' <<<"$free_out")
    mem_buffcache=$(awk '/^Mem:/ {print $6}' <<<"$free_out")
    mem_available=$((mem_free + mem_buffcache))
  fi
  if [[ -z "$mem_total" || "$mem_total" -le 0 ]]; then
    echo "0"
    return
  fi
  mem_used=$((mem_total - mem_available))
  mem_pct=$(awk -v used="$mem_used" -v tot="$mem_total" 'BEGIN { printf "%.0f", used / tot * 100 }')
  echo "$mem_pct"
}

# Disk usage percentage for root filesystem (/)
get_disk_usage() {
  # Use df to get percent used for /
  # df output percent may include % sign, extract digits
  if ! df_out=$(df --output=pcent,target / 2>/dev/null | tail -n +2); then
    echo "0"
    return
  fi
  # Example df_out: " 12% /"
  disk_pct=$(awk '{gsub(/%/,"",$1); print $1}' <<<"$df_out")
  # ensure numeric
  if ! [[ "$disk_pct" =~ ^[0-9]+$ ]]; then
    echo "0"
    return
  fi
  echo "$disk_pct"
}

cpu=$(get_cpu_usage)
mem=$(get_mem_usage)
disk=$(get_disk_usage)

is_healthy=true
if (( cpu >= THRESHOLD )) || (( mem >= THRESHOLD )) || (( disk >= THRESHOLD )); then
  is_healthy=false
fi

if $EXPLAIN; then
  # human-readable memory and disk details
  # Memory: print used/total in MiB
  if free_out=$(free -m 2>/dev/null); then
    mem_total_mb=$(awk '/^Mem:/ {print $2}' <<<"$free_out")
    mem_available_mb=$(awk '/^Mem:/ {print $7}' <<<"$free_out")
    if [[ -z "$mem_available_mb" || "$mem_available_mb" == "0" ]]; then
      mem_free_mb=$(awk '/^Mem:/ {print $4}' <<<"$free_out")
      mem_buffcache_mb=$(awk '/^Mem:/ {print $6}' <<<"$free_out")
      mem_available_mb=$((mem_free_mb + mem_buffcache_mb))
    fi
    mem_used_mb=$((mem_total_mb - mem_available_mb))
  else
    mem_total_mb=0; mem_used_mb=0
  fi

  if df_details=$(df -h / --output=source,size,used,avail,pcent,target 2>/dev/null | tail -n1); then
    disk_line="$df_details"
  else
    disk_line="(df not available)"
  fi

  echo "CPU usage:    ${cpu}%"
  echo "Memory usage: ${mem}%  (${mem_used_mb}MiB used / ${mem_total_mb}MiB total)"
  echo "Disk usage:   ${disk}%  [root fs]  ${disk_line}"
fi

if $is_healthy; then
  echo "Healthy"
  exit 0
else
  echo "Unhealthy"
  exit 1
fi
