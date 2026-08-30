#!/bin/bash

# Configuration & Directories
LOCK_DIR="$HOME/.cipherlock"
KEY_DIR="$LOCK_DIR/keys"
LOG_FILE="$LOCK_DIR/operations.log"

# ANSI Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

init_env() {
    mkdir -p "$LOCK_DIR" "$KEY_DIR"
    chmod 700 "$LOCK_DIR" "$KEY_DIR"
    touch "$LOG_FILE"
}

log_event() {
    local status="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$status] $message" >> "$LOG_FILE"
}

get_passphrase() {
    local confirm="$1"
    pass1=""
    pass2=""

    while true; do
        read -rs -p "Enter Passphrase: " pass1
        echo ""
        if [ "$confirm" == "true" ]; then
            read -rs -p "Confirm Passphrase: " pass2
            echo ""
            if [ "$pass1" != "$pass2" ]; then
                echo -e "[${RED}ERROR${RESET}] Passphrases do not match. Try again."
                continue
            fi
        fi

        if [ -z "$pass1" ]; then
            echo -e "[${RED}ERROR${RESET}] Passphrase cannot be empty."
            continue
        fi

        break
    done
}

select_cipher() {
    echo -e "\n${BOLD}Select Cipher Algorithm:${RESET}"
    echo "1. AES-256-CBC (Default)"
    echo "2. ChaCha20 (Fast Stream Cipher)"
    echo "3. Camellia-256-CBC"
    read -p "Selection [1-3, default 1]: " c_choice

    case "$c_choice" in
        2) CIPHER_ALG="chacha20" ;;
        3) CIPHER_ALG="camellia-256-cbc" ;;
        *) CIPHER_ALG="aes-256-cbc" ;;
    esac

    echo -e "${BOLD}Select PBKDF2 Iteration Count:${RESET}"
    echo "1. 100,000 iterations"
    echo "2. 250,000 iterations (Recommended)"
    echo "3. 500,000 iterations"
    read -p "Selection [1-3, default 2]: " iter_choice

    case "$iter_choice" in
        1) ITER_COUNT=100000 ;;
        3) ITER_COUNT=500000 ;;
        *) ITER_COUNT=250000 ;;
    esac
}

encrypt_symmetric() {
    echo -e "\n${BOLD}--- Symmetric Encryption ---${RESET}"
    read -e -p "Enter path of file to encrypt: " input_file

    if [ ! -f "$input_file" ]; then
        echo -e "[${RED}ERROR${RESET}] File not found."
        return
    fi

    select_cipher
    get_passphrase "true"

    echo -e "\n${YELLOW}Output Format:${RESET}"
    echo "1. Binary Encrypted File (.enc)"
    echo "2. Base64 Text-Armored Output (.enc.b64)"
    read -p "Select format [1-2, default 1]: " armor_choice

    local output_file="${input_file}.enc"
    local armor_cmd=()
    if [ "$armor_choice" -eq 2 ]; then
        output_file="${input_file}.enc.b64"
        armor_cmd=("-a")
    fi

    echo -e "\n${CYAN}Encrypting payload...${RESET}"

    openssl enc -"$CIPHER_ALG" -pbkdf2 -iter "$ITER_COUNT" "${armor_cmd[@]}" \
        -pass pass:"$pass1" -in "$input_file" -out "$output_file"

    if [ $? -eq 0 ]; then
        local checksum=$(sha256sum "$output_file" | awk '{print $1}')
        echo -e "\n[${GREEN}SUCCESS${RESET}] File encrypted successfully!"
        echo -e "  Output File: ${BOLD}$output_file${RESET}"
        echo -e "  SHA-256    : ${CYAN}$checksum${RESET}"

        log_event "ENCRYPT" "Encrypted '$input_file' -> '$output_file'"
    else
        echo -e "\n[${RED}FAIL${RESET}] Encryption failed."
    fi
}

decrypt_symmetric() {
    echo -e "\n${BOLD}--- Symmetric Decryption ---${RESET}"
    read -e -p "Enter path of file to decrypt: " input_file

    if [ ! -f "$input_file" ]; then
        echo -e "[${RED}ERROR${RESET}] File not found."
        return
    fi

    select_cipher
    get_passphrase "false"

    local default_out="${input_file%.b64}"
    default_out="${default_out%.enc}"
    [ "$default_out" == "$input_file" ] && default_out="${input_file}.dec"

    read -e -p "Enter output file path [$default_out]: " output_file
    output_file=${output_file:-$default_out}

    local armor_cmd=()
    [[ "$input_file" == *.b64 ]] && armor_cmd=("-a")

    echo -e "\n${CYAN}Decrypting payload...${RESET}"

    openssl enc -d -"$CIPHER_ALG" -pbkdf2 -iter "$ITER_COUNT" "${armor_cmd[@]}" \
        -pass pass:"$pass1" -in "$input_file" -out "$output_file"

    if [ $? -eq 0 ]; then
        echo -e "\n[${GREEN}SUCCESS${RESET}] File decrypted to ${BOLD}$output_file${RESET}"
        log_event "DECRYPT" "Decrypted '$input_file' -> '$output_file'"
    else
        echo -e "\n[${RED}FAIL${RESET}] Decryption failed. Wrong passphrase or wrong algorithm settings."
        rm -f "$output_file" 2>/dev/null
    fi
}

main_menu() {
    init_env
    while true; do
        echo ""
        echo -e "${BOLD}CipherLock v3 Utility${RESET}"
        echo "----------------------"
        echo "1. Symmetric Encryption"
        echo "2. Symmetric Decryption"
        echo "3. View Operations Log"
        echo "4. Exit"
        read -p "Select option [1-4]: " choice

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