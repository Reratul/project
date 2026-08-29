#!/bin/bash

# Configuration Thresholds (%)
CPU_THRESHOLD=80
MEM_THRESHOLD=85
DISK_THRESHOLD=90

# Default refresh interval in seconds
REFRESH_INTERVAL=3

# Services to monitor
CRITICAL_SERVICES=("ssh" "nginx" "cron")

# Terminal color definitions
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

# Trap CTRL+C or 'q' exit to clear screen and restore terminal
cleanup() {
    clear
    echo "Exiting Server Dashboard."
    exit 0
}
trap cleanup SIGINT SIGTERM

get_cpu_usage() {
    local idle
    idle=$(top -bn1 | grep "Cpu(s)" | awk -F',' '{print $4}' | awk '{print $1}')
    awk "BEGIN {print 100 - ${idle:-0}}"
}

get_mem_usage() {
    free | awk '/Mem:/ {printf "%.2f", $3/$2 * 100}'
}

get_disk_usage() {
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

render_dashboard() {
    # Move cursor to top-left to eliminate flicker instead of full screen clear
    tput cup 0 0

    echo -e "${BOLD}=====================================================================${RESET}\e[K"
    echo -e "${BOLD}            SERVER MONITORING DASHBOARD (Auto-Refresh)              ${RESET}\e[K"
    echo -e "${BOLD}=====================================================================${RESET}\e[K"
    echo -e "Last Updated: $(date '+%Y-%m-%d %H:%M:%S')  |  Interval: ${REFRESH_INTERVAL}s\e[K"
    echo -e "---------------------------------------------------------------------\e[K"

    # --- CPU SECTION ---
    local cpu_usage=$(get_cpu_usage)
    local cpu_int=${cpu_usage%.*}
    if [ "$cpu_int" -ge "$CPU_THRESHOLD" ]; then
        echo -e "CPU Usage:    [${RED}${cpu_usage}%${RESET}] ${RED}WARNING: High Load!${RESET}\e[K"
    else
        echo -e "CPU Usage:    [${GREEN}${cpu_usage}%${RESET}] ${GREEN}OK${RESET}\e[K"
    fi

    # --- MEMORY SECTION ---
    local mem_usage=$(get_mem_usage)
    local mem_int=${mem_usage%.*}
    if [ "$mem_int" -ge "$MEM_THRESHOLD" ]; then
        echo -e "Memory Usage: [${RED}${mem_usage}%${RESET}] ${RED}WARNING: High Memory!${RESET}\e[K"
    else
        echo -e "Memory Usage: [${GREEN}${mem_usage}%${RESET}] ${GREEN}OK${RESET}\e[K"
    fi

    # --- DISK SECTION ---
    local disk_usage=$(get_disk_usage)
    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        echo -e "Disk Usage (/):[${RED}${disk_usage}%${RESET}] ${RED}WARNING: Low Disk Space!${RESET}\e[K"
    else
        echo -e "Disk Usage (/):[${GREEN}${disk_usage}%${RESET}] ${GREEN}OK${RESET}\e[K"
    fi

    echo -e "---------------------------------------------------------------------\e[K"
    echo -e "${BOLD}Critical Services Status:${RESET}\e[K"

    # --- SERVICES SECTION ---
    for service in "${CRITICAL_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  - %-12s [${GREEN}RUNNING${RESET}]\e[K" "$service"
        else
            echo -e "  - %-12s [${RED}STOPPED${RESET}]\e[K" "$service"
        fi
    done

    echo -e "---------------------------------------------------------------------\e[K"
    
    # --- TOP 5 CPU PROCESSES ---
    echo -e "${BOLD}Top 5 CPU-Consuming Processes:${RESET}\e[K"
    printf "  ${YELLOW}%-8s %-8s %-10s %-25s${RESET}\n\e[K" "PID" "%CPU" "%MEM" "COMMAND"
    ps -eo pid,%cpu,%mem,comm --sort=-%cpu | sed -n '2,6p' | while read -r pid cpu mem comm; do
        printf "  %-8s %-8s %-10s %-25s\n\e[K" "$pid" "$cpu" "$mem" "$comm"
    done

    echo -e "---------------------------------------------------------------------\e[K"

    # --- TOP 5 MEMORY PROCESSES ---
    echo -e "${BOLD}Top 5 Memory-Consuming Processes:${RESET}\e[K"
    printf "  ${YELLOW}%-8s %-8s %-10s %-25s${RESET}\n\e[K" "PID" "%MEM" "%CPU" "COMMAND"
    ps -eo pid,%mem,%cpu,comm --sort=-%mem | sed -n '2,6p' | while read -r pid mem cpu comm; do
        printf "  %-8s %-8s %-10s %-25s\n\e[K" "$pid" "$mem" "$cpu" "$comm"
    done

    echo -e "---------------------------------------------------------------------\e[K"
    echo -e "${BOLD}Controls:${RESET} [r] Change Refresh Rate  |  [q] Quit\e[K"
    echo -e "${BOLD}=====================================================================${RESET}\e[K"
}

# Clear terminal once before entering main loop
clear

while true; do
    render_dashboard

    # Non-blocking key press detection via read timeout
    read -t "$REFRESH_INTERVAL" -n 1 input
    case $input in
        r|R)
            tput cup 30 0
            read -p "Enter new refresh interval in seconds: " new_int
            if [[ "$new_int" =~ ^[0-9]+$ ]] && [ "$new_int" -gt 0 ]; then
                REFRESH_INTERVAL=$new_int
            fi
            clear
            ;;
        q|Q)
            cleanup
            ;;
    esac
done