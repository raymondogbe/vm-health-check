#!/bin/bash
#
# vm-healthcheck.sh
# Checks CPU, memory, and disk usage on an Ubuntu VM and reports
# whether the machine is Healthy or Unhealthy based on a 60% threshold
# applied to each metric.
#
# Usage:
#   ./vm-healthcheck.sh            -> prints "Healthy" or "Unhealthy"
#   ./vm-healthcheck.sh explain    -> prints the metric breakdown, then status

set -euo pipefail

THRESHOLD=60

# ---------------------------------------------------------------------------
# Metric collection
# ---------------------------------------------------------------------------

get_cpu_usage() {
    # Average CPU usage (%) over a 1-second sample window, using /proc/stat.
    # Reading /proc/stat twice, 1 second apart, avoids needing extra tools
    # like 'mpstat' or 'top' that may not be installed by default.
    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    prev_idle=$((idle + iowait))
    prev_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

    sleep 1

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat
    curr_idle=$((idle + iowait))
    curr_total=$((user + nice + system + idle + iowait + irq + softirq + steal))

    diff_idle=$((curr_idle - prev_idle))
    diff_total=$((curr_total - prev_total))
    diff_used=$((diff_total - diff_idle))

    if [ "$diff_total" -eq 0 ]; then
        echo 0
    else
        echo $(( (diff_used * 100) / diff_total ))
    fi
}

get_memory_usage() {
    # Memory usage (%) = (total - available) / total * 100
    # 'available' (from /proc/meminfo) is used instead of 'free' because it
    # accounts for reclaimable cache/buffers, giving a realistic picture of
    # what's actually usable.
    local mem_total mem_available
    mem_total=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    mem_available=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

    if [ "$mem_total" -eq 0 ]; then
        echo 0
    else
        echo $(( (mem_total - mem_available) * 100 / mem_total ))
    fi
}

get_disk_usage() {
    # Disk usage (%) of the root filesystem.
    df -h / | awk 'NR==2 {gsub("%","",$5); print $5}'
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    local mode="${1:-}"

    local cpu_usage mem_usage disk_usage
    cpu_usage=$(get_cpu_usage)
    mem_usage=$(get_memory_usage)
    disk_usage=$(get_disk_usage)

    local status="Healthy"
    if [ "$cpu_usage" -ge "$THRESHOLD" ] || [ "$mem_usage" -ge "$THRESHOLD" ] || [ "$disk_usage" -ge "$THRESHOLD" ]; then
        status="Unhealthy"
    fi

    if [ "$mode" = "explain" ]; then
        echo "VM Health Check Report"
        echo "-----------------------"
        printf "%-15s %5s%%  (threshold: %s%%)\n" "CPU Usage:" "$cpu_usage" "$THRESHOLD"
        printf "%-15s %5s%%  (threshold: %s%%)\n" "Memory Usage:" "$mem_usage" "$THRESHOLD"
        printf "%-15s %5s%%  (threshold: %s%%)\n" "Disk Usage:" "$disk_usage" "$THRESHOLD"
        echo "-----------------------"
        echo "Status: $status"
    else
        echo "$status"
    fi
}

main "$@"
