#!/bin/bash

# Log file targets (handles both Debian/Ubuntu and RHEL/CentOS formats)
LOG_FILE="/var/log/auth.log"
[ ! -f "$LOG_FILE" ] && LOG_FILE="/var/log/secure"

# Output Report
REPORT_FILE="./security_report.txt"

# Threshold for flagging an IP as brute-forcing
ATTEMPT_THRESHOLD=5

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BOLD="\e[1m"
RESET="\e[0m"

check_log_access() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "[${RED}ERROR${RESET}] Log file not found. Generating dummy log file for testing..."
        LOG_FILE="./dummy_auth.log"
        cat << 'EOF' > "$LOG_FILE"
Aug 29 10:01:12 server sshd[1234]: Failed password for root from 192.168.1.105 port 45122 ssh2
Aug 29 10:01:15 server sshd[1235]: Failed password for root from 192.168.1.105 port 45124 ssh2
Aug 29 10:01:18 server sshd[1236]: Failed password for admin from 192.168.1.105 port 45126 ssh2
Aug 29 10:01:20 server sshd[1237]: Failed password for invalid user user1 from 192.168.1.105 port 45128 ssh2
Aug 29 10:01:22 server sshd[1238]: Failed password for root from 192.168.1.105 port 45130 ssh2
Aug 29 10:01:25 server sshd[1239]: Failed password for root from 10.0.0.45 port 51112 ssh2
Aug 29 10:02:01 server sshd[1240]: Accepted password for deploy from 172.16.0.12 port 38910 ssh2
Aug 29 10:03:45 server sshd[1241]: Failed password for root from 192.168.1.105 port 45132 ssh2
EOF
        echo "Created '$LOG_FILE' with sample failure data."
    fi
}

analyze_failed_logins() {
    echo -e "\n${BOLD}======================================================${RESET}"
    echo -e "${BOLD}       SECURITY AUDIT: FAILED LOGIN ANALYSIS         ${RESET}"
    echo -e "${BOLD}======================================================${RESET}"
    echo -e "Target Log: ${LOG_FILE}"
    echo -e "Brute-force Threshold: ${ATTEMPT_THRESHOLD} failed attempts\n"

    # Extract IP addresses of failed password attempts
    local failed_ips
    failed_ips=$(grep "Failed password" "$LOG_FILE" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr)

    if [ -z "$failed_ips" ]; then
        echo -e "[${GREEN}CLEAN${RESET}] No failed SSH login attempts detected."
        return
    fi

    printf "${YELLOW}%-10s %-20s %-15s${RESET}\n" "ATTEMPTS" "IP ADDRESS" "STATUS"
    echo "------------------------------------------------------"

    echo "$failed_ips" | while read -r count ip; do
        if [ "$count" -ge "$ATTEMPT_THRESHOLD" ]; then
            printf "%-10s %-20s [${RED}SUSPICIOUS / HIGH RISK${RESET}]\n" "$count" "$ip"
        else
            printf "%-10s %-20s [${GREEN}LOW RISK${RESET}]\n" "$count" "$ip"
        fi
    done
}

analyze_targeted_usernames() {
    echo -e "\n${BOLD}Top Targeted Usernames:${RESET}"
    echo "------------------------------------------------------"
    grep "Failed password" "$LOG_FILE" | awk '{
        for(i=1;i<=NF;i++) {
            if($i=="for") {
                if($(i+1)=="invalid" && $(i+2)=="user") print $(i+3);
                else print $(i+1);
            }
        }
    }' | sort | uniq -c | sort -nr | head -n 5 | while read -r count user; do
        printf "  - Username: %-15s | Failed Attempts: %s\n" "$user" "$count"
    done
}

export_report() {
    {
        echo "======================================================"
        echo "         SSH SECURITY ANALYSIS REPORT                 "
        echo "         Generated: $(date '+%Y-%m-%d %H:%M:%S')      "
        echo "======================================================"
        echo ""
        echo "--- High Risk IP Addresses (Failed >= $ATTEMPT_THRESHOLD) ---"
        grep "Failed password" "$LOG_FILE" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort | uniq -c | sort -nr | awk -v thresh="$ATTEMPT_THRESHOLD" '$1 >= thresh {print $2 " - " $1 " attempts"}'
        echo ""
        echo "--- Top Targeted Usernames ---"
        grep "Failed password" "$LOG_FILE" | awk '{for(i=1;i<=NF;i++) if($i=="for") print $(i+1)}' | sort | uniq -c | sort -nr | head -n 5
    } > "$REPORT_FILE"

    echo -e "\n[${GREEN}OK${RESET}] Summary report saved to '${BOLD}$REPORT_FILE${RESET}'."
}

main() {
    check_log_access
    analyze_failed_logins
    analyze_targeted_usernames
    export_report
}

main