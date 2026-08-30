#!/bin/bash

# Configuration & Hardcoded Master Passphrase
LOCK_DIR="$HOME/.cipherlock"
LOG_FILE="$LOCK_DIR/operations.log"

# Set your default passphrase here:
DEFAULT_PASSPHRASE="MySuperSecretDefaultPassphrase123!"

# ANSI Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

init_env() {
    mkdir -p "$LOCK_DIR"
    chmod 700 "$LOCK_DIR"
    touch "$LOG_FILE"
}

log_event() {
    local status="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $message" >> "$LOG_FILE"
}

encrypt_symmetric() {
    echo -e "\n${BOLD}--- Symmetric File Encryption ---${RESET}"
    read -r -e -p "Enter path of file to encrypt: " input_file

    if [ ! -f "$input_file" ]; then
        echo -e "[${RED}ERROR${RESET}] File '$input_file' not found."
        return
    fi

    echo -e "\n${YELLOW}Output Format:${RESET}"
    echo "1. Binary Encrypted File (.enc)"
    echo "2. Base64 Text-Armored Output (.enc.b64)"
    read -r -p "Select format [1-2, default 1]: " armor_choice

    local output_file="${input_file}.enc"
    local is_armored=false

    if [ "$armor_choice" -eq 2 ]; then
        output_file="${input_file}.enc.b64"
        is_armored=true
    fi

    echo -e "\n${CYAN}Encrypting payload using hardcoded passphrase...${RESET}"

    # Feed passphrase via memory pipe (FD 3) using AES-256-CBC with PBKDF2
    exec 3<<< "$DEFAULT_PASSPHRASE"
    if [ "$is_armored" = true ]; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -a -pass fd:3 -in "$input_file" -out "$output_file" 2>/dev/null
    else
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -pass fd:3 -in "$input_file" -out "$output_file" 2>/dev/null
    fi
    local status=$?
    exec 3>&- # Close descriptor 3

    if [ $status -eq 0 ]; then
        local checksum
        checksum=$(sha256sum "$output_file" | awk '{print $1}')
        echo -e "\n[${GREEN}SUCCESS${RESET}] File encrypted successfully!"
        echo -e "  Output File: ${BOLD}$output_file${RESET}"
        echo -e "  SHA-256    : ${CYAN}$checksum${RESET}"

        log_event "ENCRYPT" "Encrypted '$input_file' -> '$output_file'"
    else
        echo -e "\n[${RED}FAIL${RESET}] Encryption failed. Verify OpenSSL is installed."
        rm -f "$output_file" 2>/dev/null
    fi
}

decrypt_symmetric() {
    echo -e "\n${BOLD}--- Symmetric File Decryption ---${RESET}"
    read -r -e -p "Enter path of file to decrypt: " input_file

    if [ ! -f "$input_file" ]; then
        echo -e "[${RED}ERROR${RESET}] File '$input_file' not found."
        return
    fi

    local default_out="${input_file%.b64}"
    default_out="${default_out%.enc}"
    [ "$default_out" == "$input_file" ] && default_out="${input_file}.dec"

    read -r -e -p "Enter output file path [$default_out]: " output_file
    output_file=${output_file:-$default_out}

    echo -e "\n${CYAN}Decrypting payload using hardcoded passphrase...${RESET}"

    # Feed passphrase via memory pipe (FD 3)
    exec 3<<< "$DEFAULT_PASSPHRASE"
    if [[ "$input_file" == *.b64 ]]; then
        openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -a -pass fd:3 -in "$input_file" -out "$output_file" 2>/dev/null
    else
        openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -pass fd:3 -in "$input_file" -out "$output_file" 2>/dev/null
    fi
    local status=$?
    exec 3>&- # Close descriptor 3

    if [ $status -eq 0 ]; then
        echo -e "\n[${GREEN}SUCCESS${RESET}] File decrypted successfully!"
        echo -e "  Restored File: ${BOLD}$output_file${RESET}"
        log_event "DECRYPT" "Decrypted '$input_file' -> '$output_file'"
    else
        echo -e "\n[${RED}FAIL${RESET}] Decryption failed. File may be corrupted or encrypted with a different passphrase/cipher."
        rm -f "$output_file" 2>/dev/null
    fi
}

main_menu() {
    init_env
    while true; do
        echo ""
        echo -e "${BOLD}CipherLock v5 (Automated Hardcoded Passphrase)${RESET}"
        echo "----------------------------------------------"
        echo "1. Symmetric Encryption"
        echo "2. Symmetric Decryption"
        echo "3. View Operations Log"
        echo "4. Exit"
        read -r -p "Select option [1-4]: " choice

        case $choice in
            1) encrypt_symmetric ;;
            2) decrypt_symmetric ;;
            3) cat "$LOG_FILE" || echo "No logs found." ;;
            4) echo "Exiting CipherLock."; exit 0 ;;
            *) echo "Invalid option." ;;
        esac
    done
}

main_menu