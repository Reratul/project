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
MAGENTA="\e[35m"
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

select_cipher() {
    echo -e "\n${BOLD}Select Symmetric Cipher Algorithm:${RESET}"
    echo "1. AES-256-CBC (Industry Standard)"
    echo "2. ChaCha20-Poly1305 (Fast & Secure Stream Cipher)"
    echo "3. Camellia-256-CBC (High-Security Alternative)"
    read -p "Selection [1-3, default 1]: " c_choice

    case "$c_choice" in
        2) CIPHER_OPT="-chacha20" ;;
        3) CIPHER_OPT="-camellia-256-cbc" ;;
        *) CIPHER_OPT="-aes-256-cbc" ;;
    esac

    echo -e "${BOLD}Select PBKDF2 Iteration Count (Passphrase Hardening):${RESET}"
    echo "1. 100,000 iterations (Fast)"
    echo "2. 250,000 iterations (Recommended)"
    echo "3. 500,000 iterations (Maximum Security)"
    read -p "Selection [1-3, default 2]: " iter_choice

    case "$iter_choice" in
        1) ITER_COUNT=100000 ;;
        3) ITER_COUNT=500000 ;;
        *) ITER_COUNT=250000 ;;
    esac
}

encrypt_symmetric() {
    echo -e "\n${BOLD}--- Symmetric Encryption (Passphrase Protected) ---${RESET}"
    read -e -p "Enter path of file to encrypt: " input_file

    if [ ! -f "$input_file" ]; then
        echo -e "[${RED}ERROR${RESET}] File not found."
        return
    fi

    select_cipher

    echo -e "\n${YELLOW}Output Format:${RESET}"
    echo "1. Binary Encrypted File (.enc)"
    echo "2. Base64 Text-Armored Output (.enc.b64)"
    read -p "Select format [1-2, default 1]: " armor_choice

    local output_file="${input_file}.enc"
    local armor_flag=""
    if [ "$armor_choice" -eq 2 ]; then
        output_file="${input_file}.enc.b64"
        armor_flag="-a"
    fi

    echo -e "\n${CYAN}Encrypting using $CIPHER_OPT ($ITER_COUNT PBKDF2 iterations)...${RESET}"

    openssl enc $CIPHER_OPT -pbkdf2 -iter "$ITER_COUNT" $armor_flag -in "$input_file" -out "$output_file"

    if [ $? -eq 0 ]; then
        local checksum=$(sha256sum "$output_file" | awk '{print $1}')
        echo -e "\n[${GREEN}SUCCESS${RESET}] File encrypted successfully!"
        echo -e "  Cipher Output : ${BOLD}$output_file${RESET}"
        echo -e "  SHA-256 Hash  : ${CYAN}$checksum${RESET}"

        log_event "ENCRYPT" "Symmetric ($CIPHER_OPT) '$input_file' -> '$output_file'"
    else
        echo -e "\n[${RED}FAIL${RESET}] Encryption failed."
        log_event "FAIL" "Encryption error for '$input_file'"
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

    local default_out="${input_file%.b64}"
    default_out="${default_out%.enc}"
    [ "$default_out" == "$input_file" ] && default_out="${input_file}.dec"

    read -e -p "Enter output file path [$default_out]: " output_file
    output_file=${output_file:-$default_out}

    local armor_flag=""
    [[ "$input_file" == *.b64 ]] && armor_flag="-a"

    echo -e "\n${CYAN}Decrypting payload...${RESET}"

    openssl enc -d $CIPHER_OPT -pbkdf2 -iter "$ITER_COUNT" $armor_flag -in "$input_file" -out "$output_file"

    if [ $? -eq 0 ]; then
        echo -e "\n[${GREEN}SUCCESS${RESET}] File decrypted successfully to ${BOLD}$output_file${RESET}"
        log_event "DECRYPT" "Decrypted '$input_file' -> '$output_file'"
    else
        echo -e "\n[${RED}FAIL${RESET}] Decryption failed. Incorrect passphrase or wrong cipher selection."
        rm -f "$output_file" 2>/dev/null
    fi
}

generate_rsa_keys() {
    echo -e "\n${BOLD}--- Generate RSA 4096-bit Asymmetric Key Pair ---${RESET}"
    read -p "Enter key pair name identifier (e.g., john_key): " key_name
    [ -z "$key_name" ] && key_name="rsa_key"

    local priv_key="$KEY_DIR/${key_name}_priv.pem"
    local pub_key="$KEY_DIR/${key_name}_pub.pem"

    if [ -f "$priv_key" ]; then
        echo -e "[${RED}ERROR${RESET}] Key pair with name '$key_name' already exists!"
        return
    fi

    echo -e "${CYAN}Generating 4096-bit RSA Private Key...${RESET}"
    openssl genpkey -algorithm RSA -out "$priv_key" -pkeyopt rsa_keygen_bits:4096
    chmod 600 "$priv_key"

    echo -e "${CYAN}Extracting RSA Public Key...${RESET}"
    openssl rsa -pubout -in "$priv_key" -out "$pub_key"
    chmod 644 "$pub_key"

    echo -e "\n[${GREEN}SUCCESS${RESET}] RSA Keypair generated:"
    echo -e "  Private Key : ${BOLD}$priv_key${RESET} (Keep Private!)"
    echo -e "  Public Key  : ${BOLD}$pub_key${RESET} (Shareable)"
    log_event "KEYGEN" "Generated RSA keypair '$key_name'"
}

encrypt_rsa() {
    echo -e "\n${BOLD}--- Asymmetric Public Key Encryption (RSA-OAEP) ---${RESET}"
    read -e -p "Enter path of file to encrypt: " input_file
    read -e -p "Enter Recipient's Public Key Path (.pem): " pub_key

    if [ ! -f "$input_file" ] || [ ! -f "$pub_key" ]; then
        echo -e "[${RED}ERROR${RESET}] File or Public Key path invalid."
        return
    fi

    local output_file="${input_file}.rsa.enc"
    openssl pkeyutl -encrypt -pubin -inkey "$pub_key" -in "$input_file" -out "$output_file" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256

    if [ $? -eq 0 ]; then
        echo -e "\n[${GREEN}SUCCESS${RESET}] File encrypted using RSA Public Key!"
        echo -e "  Output File: ${BOLD}$output_file${RESET}"
        log_event "RSA_ENCRYPT" "Encrypted '$input_file' using '$pub_key'"
    else
        echo -e "\n[${RED}FAIL${RESET}] RSA Encryption failed."
    fi
}

decrypt_rsa() {
    echo -e "\n${BOLD}--- Asymmetric Private Key Decryption (RSA-OAEP) ---${RESET}"
    read -e -p "Enter path of file to decrypt (.rsa.enc): " input_file
    read -e -p "Enter Your Private Key Path (.pem): " priv_key

    if [ ! -f "$input_file" ] || [ ! -f "$priv_key" ]; then
        echo -e "[${RED}ERROR${RESET}] File or Private Key path invalid."
        return
    fi

    local output_file="${input_file%.rsa.enc}.dec"
    openssl pkeyutl -decrypt -inkey "$priv_key" -in "$input_file" -out "$output_file" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256

    if [ $? -eq 0 ]; then
        echo -e "\n[${GREEN}SUCCESS${RESET}] File decrypted using RSA Private Key!"
        echo -e "  Restored File: ${BOLD}$output_file${RESET}"
        log_event "RSA_DECRYPT" "Decrypted '$input_file' using '$priv_key'"
    else
        echo -e "\n[${RED}FAIL${RESET}] RSA Decryption failed."
    fi
}

sign_and_verify() {
    echo -e "\n${BOLD}--- Digital Signature & Verification (SHA-512) ---${RESET}"
    echo "1. Sign a File with Private Key"
    echo "2. Verify a File Signature with Public Key"
    read -p "Select choice [1-2]: " sig_choice

    if [ "$sig_choice" -eq 1 ]; then
        read -e -p "Enter file to sign: " input_file
        read -e -p "Enter Private Key path (.pem): " priv_key
        local sig_file="${input_file}.sig"

        openssl dgst -sha512 -sign "$priv_key" -out "$sig_file" "$input_file"
        if [ $? -eq 0 ]; then
            echo -e "\n[${GREEN}SUCCESS${RESET}] Signature generated: ${BOLD}$sig_file${RESET}"
            log_event "SIGN" "Signed '$input_file'"
        fi
    elif [ "$sig_choice" -eq 2 ]; then
        read -e -p "Enter original file path: " input_file
        read -e -p "Enter signature file path (.sig): " sig_file
        read -e -p "Enter Sender's Public Key path (.pem): " pub_key

        openssl dgst -sha512 -verify "$pub_key" -signature "$sig_file" "$input_file"
        if [ $? -eq 0 ]; then
            echo -e "\n[${GREEN}VERIFIED${RESET}] Signature is authentic and valid!"
        else
            echo -e "\n[${RED}INVALID${RESET}] Signature verification failed! File may be altered."
        fi
    fi
}

main_menu() {
    init_env
    while true; do
        echo ""
        echo -e "${BOLD}CipherLock v2 - Cryptographic Suite${RESET}"
        echo "-------------------------------------"
        echo "1. Symmetric Encryption (AES-256 / ChaCha20 / Camellia)"
        echo "2. Symmetric Decryption"
        echo "3. Generate RSA 4096-bit Keypair"
        echo "4. Asymmetric RSA Encryption (Public Key)"
        echo "5. Asymmetric RSA Decryption (Private Key)"
        echo "6. Digital Signature & Verification (SHA-512)"
        echo "7. View Audit Logs"
        echo "8. Exit"
        read -p "Select option [1-8]: " choice

        case $choice in
            1) encrypt_symmetric ;;
            2) decrypt_symmetric ;;
            3) generate_rsa_keys ;;
            4) encrypt_rsa ;;
            5) decrypt_rsa ;;
            6) sign_and_verify ;;
            7) cat "$LOG_FILE" || echo "No logs." ;;
            8) echo "Exiting CipherLock."; exit 0 ;;
            *) echo "Invalid option." ;;
        esac
    done
}

main_menu