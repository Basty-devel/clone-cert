#!/bin/bash
# Adrian Vollmer, SySS GmbH 2017-2019 & Sebastian Friedrich Nestler 2025
# Enhanced UI/UX version with additional functionality
#
# MIT License
#
# Copyright (c) 2017-2019 Adrian Vollmer, SySS GmbH
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

set -e

# Configuration
VERSION="2.0.0"
DIR="/tmp/cert-clones"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEBUG=false
COLORS=true

# Color codes
if [[ "$COLORS" = true ]] && [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; BOLD=''; NC=''
fi

function print_banner() {
    cat <<EOF
${BOLD}${CYAN}
╔════════════════════════════════════════════════════════════════╗
║                     Certificate Cloner v${VERSION}                   ║
║          Clone X.509 certificates for security testing         ║
╚════════════════════════════════════════════════════════════════╝
${NC}
EOF
}

function usage(){
    print_banner
    cat <<EOF
${BOLD}Usage:${NC} $0 [options] [<sni>@]<host>:<port>|<pem-file>

${BOLD}Description:${NC}
Clone X.509 certificates for security testing and demonstration purposes.
The cloned certificate and corresponding key will be saved in the output directory.

${BOLD}Arguments:${NC}
  <host>:<port>          Target server and port (e.g., example.com:443)
  <sni>@<host>:<port>    Specify SNI for virtual hosts
  <pem-file>             Path to existing certificate file

${BOLD}Options:${NC}
  -d, --directory DIR    Output directory (default: /tmp/cert-clones)
  -o, --output NAME      Custom output filename prefix
  -r, --reuse-keys       Reuse previously generated keys for better performance
  -c, --cert CERT        Certificate to use for signing (PEM format)
  -k, --key KEY          Private key matching the signing certificate
  --keep-issuer-name     Do not alter the issuer name
  --keep-serial          Do not alter the serial number
  --no-colors           Disable colored output
  --verify              Verify the cloned certificate after creation
  --compare             Show comparison between original and cloned cert
  --chain               Clone entire certificate chain
  --quiet               Suppress non-essential output
  --debug               Enable debug messages
  -h, --help            Show this help message
  -v, --version         Show version information

${BOLD}Examples:${NC}
  $0 example.com:443
  $0 --output my-clone --verify www.example.com:443
  $0 --chain --compare api.example.com:443
  $0 --cert my-ca.crt --key my-ca.key example.com:443

${BOLD}Author:${NC} Adrian Vollmer, SySS GmbH 2017-2019
EOF
}

function die() {
    echo -e "${RED}${BOLD}Error:${NC} $1" >&2
    exit 1
}

function warn() {
    echo -e "${YELLOW}${BOLD}Warning:${NC} $1" >&2
}

function info() {
    if [[ "$QUIET" != true ]]; then
        echo -e "${BLUE}${BOLD}Info:${NC} $1" >&2
    fi
}

function success() {
    if [[ "$QUIET" != true ]]; then
        echo -e "${GREEN}${BOLD}Success:${NC} $1" >&2
    fi
}

function debug() {
    if [[ $DEBUG = true ]]; then
        echo -e "${MAGENTA}${BOLD}Debug:${NC} $1" >&2
    fi
}

function check_dependencies() {
    local deps=("openssl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            die "$dep is required but not installed"
        fi
    done
    
    # Check OpenSSL version
    local openssl_version=$(openssl version | awk '{print $2}')
    if [[ $(echo "$openssl_version" | awk -F. '{print $1$2}') -lt 11 ]]; then
        warn "OpenSSL version $openssl_version may not support all features. Recommended: 1.1.1 or newer."
    fi
}

function parse_arguments() {
    ISSUER_CERT=""
    ISSUER_KEY=""
    REUSE_KEYS=false
    KEEP_ISSUER_NAME=false
    KEEP_SERIAL=false
    VERIFY=false
    COMPARE=false
    CLONE_CHAIN=false
    QUIET=false
    OUTPUT_PREFIX=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--directory)
                DIR="$2"
                shift 2
                ;;
            -d=*|--directory=*)
                DIR="${1#*=}"
                shift
                ;;
            -o|--output)
                OUTPUT_PREFIX="$2"
                shift 2
                ;;
            -o=*|--output=*)
                OUTPUT_PREFIX="${1#*=}"
                shift
                ;;
            -c|--cert)
                ISSUER_CERT="$2"
                shift 2
                ;;
            -c=*|--cert=*)
                ISSUER_CERT="${1#*=}"
                shift
                ;;
            -k|--key)
                ISSUER_KEY="$2"
                shift 2
                ;;
            -k=*|--key=*)
                ISSUER_KEY="${1#*=}"
                shift
                ;;
            -r|--reuse-keys)
                REUSE_KEYS=true
                shift
                ;;
            --keep-issuer-name)
                KEEP_ISSUER_NAME=true
                shift
                ;;
            --keep-serial)
                KEEP_SERIAL=true
                shift
                ;;
            --verify)
                VERIFY=true
                shift
                ;;
            --compare)
                COMPARE=true
                shift
                ;;
            --chain)
                CLONE_CHAIN=true
                shift
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --no-colors)
                COLORS=false
                shift
                ;;
            --debug)
                DEBUG=true
                set -x
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                echo "clone-cert.sh version $VERSION"
                exit 0
                ;;
            -*)
                die "Unknown option: $1"
                ;;
            *)
                HOST="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$HOST" ]]; then
        usage
        exit 1
    fi
}

function setup_environment() {
    mkdir -p "$DIR"
    
    if [[ -f "$HOST" ]]; then
        CERTNAME="$(basename "$HOST" .pem)"
        CERTNAME="$(basename "$CERTNAME" .crt)"
        CERTNAME="$(basename "$CERTNAME" .cert)"
    else
        if [[ "$HOST" != *:* ]]; then
            die "Specifying a port is mandatory (e.g., example.com:443)"
        fi
        CERTNAME="${HOST//:/_}"
        CERTNAME="${CERTNAME//\@/_}"
        SNI="${HOST%%@*}"
        if [[ "$SNI" != "$HOST" ]]; then
            HOST="${HOST##*@}"
        fi
    fi
    
    if [[ -n "$OUTPUT_PREFIX" ]]; then
        CERTNAME="$OUTPUT_PREFIX"
    fi
}

function print_cert_info() {
    local cert_file="$1"
    local title="$2"
    
    echo -e "\n${BOLD}${CYAN}=== $title ===${NC}"
    openssl x509 -in "$cert_file" -noout -text | \
        grep -E "(Subject:|Issuer:|Not Before:|Not After :|Serial Number:|Signature Algorithm:)" | \
        head -10
}

function compare_certificates() {
    local original="$1"
    local cloned="$2"
    
    echo -e "\n${BOLD}${YELLOW}=== Certificate Comparison ===${NC}"
    
    echo -e "\n${BOLD}Differences:${NC}"
    diff -u <(openssl x509 -in "$original" -noout -text) \
            <(openssl x509 -in "$cloned" -noout -text) | \
        grep -E "^[-+][^-+]" | head -20 || true
    
    echo -e "\n${BOLD}Fingerprints:${NC}"
    echo "Original: $(openssl x509 -in "$original" -noout -fingerprint | cut -d= -f2)"
    echo "Cloned:   $(openssl x509 -in "$cloned" -noout -fingerprint | cut -d= -f2)"
}

function verify_certificate() {
    local cert_file="$1"
    local key_file="$2"
    
    echo -e "\n${BOLD}${CYAN}=== Certificate Verification ===${NC}"
    
    # Check if key matches certificate
    if diff -q <(openssl x509 -in "$cert_file" -pubkey -noout 2>/dev/null) \
               <(openssl rsa -in "$key_file" -pubout 2>/dev/null 2>/dev/null || \
                 openssl ec -in "$key_file" -pubout 2>/dev/null) >/dev/null; then
        success "Key and certificate match"
    else
        die "Key and certificate do not match"
    fi
    
    # Basic certificate validation
    if openssl x509 -in "$cert_file" -noout >/dev/null 2>&1; then
        success "Certificate is valid X.509"
    else
        die "Invalid X.509 certificate"
    fi
}

# Original functional code from the script
EC_PARAMS=$(cat <<'END_HEREDOC'
-----BEGIN EC PARAMETERS-----
MIIBogIBATBMBgcqhkjOPQEBAkEAqt2duNvpxIs/1OauM8n8B8swjbOzydIO1mOc
ynAzCHF9TZsAm8ZoQq7NoSrmo4DmKIH/Ly2CxoUoqmBWWDpI8zCBhARAqt2duNvp
xIs/1OauM8n8B8swjbOzydIO1mOcynAzCHF9TZsAm8ZoQq7NoSrmo4DmKIH/Ly2C
xoUoqmBWWDpI8ARAfLu8+UQc+rduGJDkaITq4yH3DAvLSYFSeJdQS+w+NqYrzfoj
BJdlQPZFAIXy2uFFwiVTtGV2NokYDqJXGGdCPgSBgQRkDs5cEniHF7nBugbLwqb+
uoWEJFjFbd6dsXWNOcAxPYK6UXNc2z6kmap3p9aUOmT3o/Jf4m8GtRuqJpb6kDXa
W1NL1ZX1rw+iyJI3bISs4btOMBm3FjTAETEVnK4DzunZkyGEvu8ha9cd8trfhqYn
MG7P+W27i6zhmLYeAPizMgJBAKrdnbjb6cSLP9TmrjPJ/AfLMI2zs8nSDtZjnMpw
MwhwVT5cQUypJhlBhmEZf6wQRx2x04EIXdrdtYeWgpypAGkCAQE=
-----END EC PARAMETERS-----
END_HEREDOC
)

function generate_rsa_key () {
    local KEY_LEN="$1"
    local MY_PRIV_KEY="$2"
    local NEW_MODULUS=""

    if [[ $REUSE_KEYS = true ]] && [[ -f "$DIR/RSA_$KEY_LEN" ]] ; then
        debug "Reusing RSA key"
        cp "$DIR/RSA_$KEY_LEN" "$MY_PRIV_KEY"
    else
        debug "Generating RSA key"
        openssl genrsa -out "$MY_PRIV_KEY" "$KEY_LEN" 2> /dev/null
        cp "$MY_PRIV_KEY" "$DIR/RSA_$KEY_LEN"
    fi

    NEW_MODULUS="$(openssl rsa -in "$MY_PRIV_KEY" -pubout 2> /dev/null \
        | openssl rsa -pubin -noout -modulus \
        | sed 's/Modulus=//' | tr "[:upper:]" "[:lower:]" )"
    printf "%s" "$NEW_MODULUS"
}

function generate_ec_key () {
    local EC_PARAM_NAME="$1"
    local MY_PRIV_KEY="$2"

    if [[ $REUSE_KEYS = true ]] && [[ -f "$DIR/EC" ]] ; then
        debug "Reusing EC key"
        cp "$DIR/EC" "$MY_PRIV_KEY"
    else
        debug "Generating EC key"
        openssl ecparam -name "$EC_PARAM_NAME" -genkey -out "$MY_PRIV_KEY" 2> /dev/null
        cp "$MY_PRIV_KEY" "$DIR/EC"
    fi

    offset="$(openssl ec -in "$MY_PRIV_KEY" 2> /dev/null \
        | openssl asn1parse \
        | tail -n1 |sed 's/ \+\([0-9]\+\):.*/\1/')"
    NEW_MODULUS="$(openssl ec -in "$MY_PRIV_KEY" 2> /dev/null \
        | openssl asn1parse -offset "$offset" -noout \
            -out >(dd bs=1 skip=2 2> /dev/null | hexlify))"

    printf "%s" "$NEW_MODULUS"
}

function parse_certs () {
    nl=$'\n'
    state=begin
    counter=0
    while IFS= read -r line ; do
        case "$state;$line" in
          "begin;-----BEGIN CERTIFICATE-----" )
            state=reading
            current_cert="$line"
            ;;

          "reading;-----END CERTIFICATE-----" )
            current_cert+="${current_cert:+$nl}$line"
            if [[ -n "$current_cert" ]] ; then
                printf "%s" "$current_cert" > "$DIR/${CERTNAME}_$counter"
            else
                die "Error while parsing certificate"
            fi
            counter=$((counter+=1))
            state=begin
            current_cert=""
            ;;

          "reading;"* )
            current_cert+="$nl$line"
            ;;
        esac
    done
}

function oid() {
    case "$1" in
        "300b06092a864886f70d01010b") echo sha256 ;;
        "300b06092a864886f70d010105") echo sha1 ;;
        "300d06092a864886f70d01010c0500") echo sha384 ;;
        "300a06082a8648ce3d040303") echo sha384 ;;
        "300a06082a8648ce3d040302") echo sha256 ;;
        "300d06092a864886f70d0101040500") echo md5 ;;
        "300d06092a864886f70d01010d0500") echo sha512 ;;
        "300d06092a864886f70d01010b0500") echo sha256 ;;
        "300d06092a864886f70d0101050500") echo sha1 ;;
        *) die "Unknown Hash Algorithm OID: $1" ;;
    esac
}

function hexlify(){
    xxd -p | tr -d '\n'
}

function unhexlify(){
    xxd -p -r
}

function asn1-bitstring(){
    data=$1
    len=$((${#data}/2+1))
    if [[ "$len" -le 127 ]] ; then
        len=$(printf "%02x" $len)
    else
        if [[ "$len" -lt 256 ]] ; then
            len=$(printf "81%02x" "$len")
        else
            len=$(printf "82%04x" "$len")
        fi
    fi
    printf "03%s00%s" "$len" "$data"
}

function extract-values () {
    SUBJECT="$(openssl x509 -in "$CERT" -noout -subject \
        | sed 's/.* CN = //g')"
    ISSUER="$(openssl x509 -in "$CERT" -noout -issuer \
        | sed 's/.* CN = //g')"
    ISSUER_DN="$(openssl x509 -in "$CERT" -noout -issuer -nameopt compat \
        | sed 's/^issuer=//')"
    SUBJECT_DN="$(openssl x509 -in "$CERT" -noout -subject -nameopt compat \
        | sed 's/^subject=//')"

    if [[ ! $ISSUER_DN =~ ^/ ]] ; then
        debug "Fixing DNs because OpenSSL version is under 1.1.1"
        ISSUER_DN="$(echo "/$ISSUER_DN" | sed 's/, /\//g')"
        SUBJECT_DN="$(echo "/$SUBJECT_DN" | sed 's/, /\//g')"
    fi

    SELF_SIGNED=false
    [[ $ISSUER_DN = "$SUBJECT_DN" ]] && SELF_SIGNED=true
    debug "self-signed: $SELF_SIGNED"

    SERIAL="$(openssl x509 -in "$CERT" -noout -serial \
        | sed 's/serial=//g' | tr 'A-F' 'a-f')"

    AUTH_KEY_IDENTIFIER="$(openssl asn1parse -in "$CERT" \
        | grep -A1 ":X509v3 Authority Key Identifier" | tail -n1 \
        | sed 's/.*\[HEX DUMP\]://' \
        | sed 's/^.\{8\}//')"
    debug "Original AuthKeyIdentifier: $AUTH_KEY_IDENTIFIER"
}

function create-fake-CA () {
    openssl req -x509 -new -nodes -days 1024 -sha256 \
        -subj "$NEW_ISSUER_DN" \
        -config <(sed "s/.*subjectKeyIdentifier.*=.*hash/subjectKeyIdentifier=$AUTH_KEY_IDENTIFIER/" /etc/ssl/openssl.cnf) \
        "$@" \
        -out "$FAKE_ISSUER_CERT" 2> /dev/null
}

function clone_cert () {
    local CERT="$1"
    extract-values

    if [[ $SELF_SIGNED = false && $KEEP_ISSUER_NAME = false ]]; then
        if [[ $ISSUER =~ I ]] ; then
            NEW_ISSUER=$(printf "%s" "$ISSUER" | sed "s/I/l/")
        elif [[ $ISSUER =~ l ]] ; then
            NEW_ISSUER=$(printf "%s" "$ISSUER" | sed "s/l/I/")
        elif [[ $ISSUER =~ O ]] ; then
            NEW_ISSUER=$(printf "%s" "$ISSUER" | sed "s/O/0/")
        elif [[ $ISSUER =~ 0 ]] ; then
            NEW_ISSUER=$(printf "%s" "$ISSUER" | sed "s/0/O/")
        else
            NEW_ISSUER=$(printf "%s" "$ISSUER" | sed "s/.$/ /")
        fi
    else
        NEW_ISSUER=$ISSUER
    fi

    if [[ $SELF_SIGNED = false && $KEEP_SERIAL = false ]]; then
        NEW_SERIAL=$(openssl rand -hex 8)
        NEW_SERIAL=$(printf "%s" "$SERIAL" | sed "s/.\{16\}\(.\{4\}\)\$/$NEW_SERIAL\1/")
    else
        NEW_SERIAL=$SERIAL
    fi

    ISSUER=$(printf "%s" "$ISSUER" | hexlify)
    NEW_ISSUER=$(printf "%s" "$NEW_ISSUER" | hexlify)
    NEW_ISSUER_DN="$(printf "%s" "$ISSUER_DN" | hexlify | sed "s/$ISSUER/$NEW_ISSUER/" | unhexlify)"
    CLONED_CERT="${CERT}.cert"
    CLONED_KEY="${CERT}.key"
    FAKE_ISSUER_KEY="${CERT}.CA.key"
    FAKE_ISSUER_CERT="${CERT}.CA.cert"

    OLD_MODULUS="$(openssl x509 -in "$CERT" -modulus -noout \
        | sed -e 's/Modulus=//' | tr "[:upper:]" "[:lower:]")"
    if [[ $OLD_MODULUS = "wrong algorithm type" ]] ; then
        SCHEME=ec
        offset="$(openssl x509 -in "$CERT" -pubkey -noout 2> /dev/null \
            | openssl asn1parse \
            | tail -n1 |sed 's/ \+\([0-9]\+\):.*/\1/')"
        OLD_MODULUS="$(openssl x509 -in "$CERT" -pubkey -noout 2> /dev/null \
            | openssl asn1parse -offset "$offset" -noout \
                -out >(dd bs=1 skip=2 2> /dev/null | hexlify))"
        EC_OID="$(openssl x509 -in "$CERT" -text -noout \
            | grep "ASN1 OID: " | sed 's/.*: //')"
        NEW_MODULUS="$(generate_ec_key "$EC_OID" "$CLONED_KEY")"
        if [[ $SELF_SIGNED = true ]] ; then
            FAKE_ISSUER_KEY="$CLONED_KEY"
            FAKE_ISSUER_CERT="$CLONED_CERT"
        else
            if [[ $REUSE_KEYS = true ]] && [[ -f "$DIR/EC" ]] ; then
                create-fake-CA -key "$DIR/EC"
                FAKE_ISSUER_KEY="$DIR/EC"
            else
                create-fake-CA -keyout "$FAKE_ISSUER_KEY"
            fi
        fi
    else
        SCHEME=rsa
        KEY_LEN="$(openssl x509  -in "$CERT" -noout -text \
            | grep Public-Key: | grep -o "[0-9]\+")"
        NEW_MODULUS="$(generate_rsa_key "$KEY_LEN" "$CLONED_KEY")"
        if [[ $SELF_SIGNED = true ]] ; then
            FAKE_ISSUER_KEY="$CLONED_KEY"
            FAKE_ISSUER_CERT="$CLONED_CERT"
        else
            if [[ $REUSE_KEYS = true ]] && [[ -f "$DIR/RSA_2048" ]] ; then
                create-fake-CA -key "$DIR/RSA_2048"
                FAKE_ISSUER_KEY="$DIR/RSA_2048"
            else
                create-fake-CA -keyout "$FAKE_ISSUER_KEY"
            fi
        fi
    fi

    if [[ -n "$ISSUER_CERT" && -n "$ISSUER_KEY" ]] ; then
        FAKE_ISSUER_KEY="$ISSUER_KEY"
        FAKE_ISSUER_CERT="$ISSUER_CERT"
        ISSUER_KEY_IDENTIFIER="$(openssl x509 -in "$ISSUER_CERT" -ext subjectKeyIdentifier -noout \
            | sed -ne '2s/[ :]//gp' | tr 'A-F' 'a-f')"
        AUTH_KEY_IDENTIFIER="$(openssl x509 -in "$CERT" -ext authorityKeyIdentifier -noout \
            | sed -ne '2s/[ :]\|keyid//gp' | tr 'A-F' 'a-f')"
        openssl x509 -in "$CERT" -outform DER | hexlify \
            | sed "s/$OLD_MODULUS/$NEW_MODULUS/" \
            | sed "s/$AUTH_KEY_IDENTIFIER/$ISSUER_KEY_IDENTIFIER/" \
            | unhexlify \
            | openssl x509 -days 356 -inform DER -CAkey "$ISSUER_KEY" \
                -CA "$ISSUER_CERT" -CAcreateserial \
                -out "$CLONED_CERT"  2> /dev/null
        return-result
    else
        if [[ -n "$ISSUER_CERT" || -n "$ISSUER_KEY" ]] ; then
            die "If you provide one of <KEY> or <CERT>, you must also provide the other"
        fi
    fi

    offset="$(openssl asn1parse -in "$CERT" | grep SEQUENCE \
        | tail -n1 |sed 's/ \+\([0-9]\+\):.*/\1/' | head -n1)"
    SIGNING_ALGO="$(openssl asn1parse -in "$CERT" \
        -strparse "$offset" -noout -out >(hexlify))"
    offset="$(openssl asn1parse -in "$CERT" \
        | tail -n1 |sed 's/ \+\([0-9]\+\):.*/\1/' | head -n1)"
    OLD_SIGNATURE="$(openssl asn1parse -in "$CERT" \
        -strparse "$offset" -noout -out >(hexlify))"
    OLD_TBS_CERTIFICATE="$(openssl asn1parse -in "$CERT" \
        -strparse 4 -noout -out >(hexlify))"

    NEW_TBS_CERTIFICATE="$(printf "%s" "$OLD_TBS_CERTIFICATE" \
        | sed "s/$ISSUER/$NEW_ISSUER/" \
        | sed "s/$SERIAL/$NEW_SERIAL/" \
        | sed "s/$OLD_MODULUS/$NEW_MODULUS/")"

    digest="$(oid "$SIGNING_ALGO")"
    NEW_SIGNATURE="$(printf "%s" "$NEW_TBS_CERTIFICATE" | unhexlify \
        | openssl "$digest" -sign "$FAKE_ISSUER_KEY" \
        | hexlify)"

    OLD_ASN1_SIG=$(asn1-bitstring "$OLD_SIGNATURE")
    NEW_ASN1_SIG=$(asn1-bitstring "$NEW_SIGNATURE")

    OLD_CERT_LENGTH="$(openssl x509 -in "$CERT" -outform der \
        | dd bs=2 skip=1 count=1 2> /dev/null | hexlify)"
    OLD_CERT_LENGTH=$((16#$OLD_CERT_LENGTH))
    NEW_CERT_LENGTH=$((OLD_CERT_LENGTH \
        -${#OLD_ASN1_SIG}/2+${#NEW_ASN1_SIG}/2 \
        ))
    OLD_CERT_LENGTH="$(printf "%04x" $OLD_CERT_LENGTH)"
    NEW_CERT_LENGTH="$(printf "%04x" $NEW_CERT_LENGTH)"

    openssl x509 -in "$CERT" -outform DER | hexlify \
        | sed "s/$OLD_MODULUS/$NEW_MODULUS/" \
        | sed "s/$ISSUER/$NEW_ISSUER/" \
        | sed "s/$SERIAL/$NEW_SERIAL/" \
        | sed "s/$OLD_ASN1_SIG/$NEW_ASN1_SIG/" \
        | sed "s/^\(....\)$OLD_CERT_LENGTH/\1$NEW_CERT_LENGTH/" \
        | unhexlify \
        | openssl x509 -inform DER -outform PEM > "$CLONED_CERT"

    if [[ ! -s "$CLONED_CERT" ]] ; then
        rm "$CLONED_CERT"
        rm "$CLONED_KEY"
        die "Cloning failed"
    fi
    return-result
}

function return-result () {
    sanity-check || ( rm -rf "$CLONED_KEY" "$CLONED_CERT" ; exit 1)
    printf "%s\n" "$CLONED_KEY"
    printf "%s\n" "$CLONED_CERT"
    exit 0
}

function sanity-check () {
    diff -q <(openssl x509 -in "$CLONED_CERT" -pubkey -noout 2> /dev/null ) \
        <(openssl $SCHEME -in "$CLONED_KEY" -pubout 2> /dev/null) \
        || ( echo Key mismatch, probably due to a bug >&2; return 1 )
    if [[ $SELF_SIGNED = true ]] ; then return 0 ; fi
    openssl verify -CAfile "$FAKE_ISSUER_CERT" "$CLONED_CERT" > /dev/null \
        || ( echo Verification failed, probably due to a bug >&2; return 1 )
}

function main () {
    if [[ -f "$HOST" ]] ; then
        clone_cert "$HOST"
    else
        openssl s_client -servername "$SNI" \
            -verify 5 \
            -showcerts -connect "$HOST" < /dev/null 2>/dev/null | \
             parse_certs
        clone_cert "$DIR/${CERTNAME}_0"
    fi
}

function enhanced_main() {
    print_banner
    check_dependencies
    parse_arguments "$@"
    setup_environment
    
    info "Starting certificate cloning process..."
    info "Target: $HOST"
    info "Output directory: $DIR"
    
    local start_time=$(date +%s)
    
    local result
    result=$(main)
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $? -eq 0 ]]; then
        success "Certificate cloned successfully in ${duration}s"
        
        CLONED_KEY=$(echo "$result" | head -1)
        CLONED_CERT=$(echo "$result" | tail -1)
        
        echo -e "\n${BOLD}${GREEN}Output Files:${NC}"
        echo "Private Key: $CLONED_KEY"
        echo "Certificate: $CLONED_CERT"
        
        print_cert_info "$CLONED_CERT" "Cloned Certificate"
        
        if [[ "$VERIFY" = true ]]; then
            verify_certificate "$CLONED_CERT" "$CLONED_KEY"
        fi
        
        if [[ "$COMPARE" = true && -f "$HOST" ]]; then
            compare_certificates "$HOST" "$CLONED_CERT"
        elif [[ "$COMPARE" = true ]]; then
            warn "Cannot compare with remote certificate. Use --compare only with local certificate files."
        fi
        
        echo -e "\n${BOLD}${CYAN}=== Usage Examples ===${NC}"
        echo -e "Use with web server: ${BOLD}openssl s_server -cert '$CLONED_CERT' -key '$CLONED_KEY' -www${NC}"
        echo -e "Test with curl:     ${BOLD}curl --cacert '$CLONED_CERT' https://localhost/${NC}"
        echo -e "View certificate:   ${BOLD}openssl x509 -in '$CLONED_CERT' -text -noout${NC}"
        
    else
        die "Certificate cloning failed"
    fi
}

# Start the enhanced version
enhanced_main "$@"
