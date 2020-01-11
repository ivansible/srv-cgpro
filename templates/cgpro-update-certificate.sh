#!/bin/bash
#
# {{ cgpro_cert_update_script }}
# ansible-managed
#
# This script uploads new certificate and private key to CommuniGate Pro.
#
# Note: ssl_fullchain must be a full-chain pem file, where first part is
#       a server certificate and remaining parts consitute authority chain.

#set -x

## set parameters

username="postmaster"
password="{{ cgpro_postmaster_password }}"
domain="{{ cgpro_main_domain }}"
curl_port="{{ cgpro_curl_port }}"

ssl_fullchain="{{ cgpro_ssl_cert }}"
ssl_privkey="{{ cgpro_ssl_key }}"

cert_url="http://localhost:${curl_port}/Master/Domains/DomainCertificate.html?domainName=${domain}"

curl_opts="--noproxy localhost --digest -L -s -w %{http_code} -H Expect:"
# note:
# --noproxy = direct connection to given host
# --digest = force digest authentication, because default (basic) method may
#            result in cgpro error "clear text authentication is prohibited"
# -L = follow redirects (always want to see status 200, not 301/201)
# -H "Expect:" = disable the "expect 100 continue" behavior


## verify input files and cgpro connectivity

if [ ! -r $ssl_fullchain ]; then
    echo "cgpro error: $ssl_fullchain: not found"
    exit 1
fi

if [ ! -r $ssl_privkey ]; then
    echo "cgpro error: $ssl_privkey: not found"
    exit 1
fi

if ! nc -z -w5 localhost $curl_port ; then
    systemctl restart cgpro
    sleep 5
    if ! nc -z -w5 localhost $curl_port ; then
        echo "cgpro error: cannot connect to cgpro on port $curl_port"
        exit 1
    fi
fi


## split full-chain pem into certificate and authority chain parts

temp_dir=$(mktemp -d -t cgpro-cert-XXXXXXXX)

function finish {
    rm -rf $temp_dir
}
trap finish EXIT

temp_cert=$temp_dir/cert.pem
temp_chain=$temp_dir/chain.pem

awk '/-----BEGIN CERTIFICATE-----/ { n++ }
    { if (n == 1) print $0 }' \
    < "$ssl_fullchain" > $temp_cert

awk '/-----BEGIN CERTIFICATE-----/ { n++ }
    { if (n > 1)  print $0 }' \
    < "$ssl_fullchain" > $temp_chain


## print info about certificate and authority chain

cert_info=$(openssl x509 -in "$temp_cert" -noout -text \
            | egrep '(After |Subject):' | sort -r \
            | sed -Ee 's/[ ]+/ /g' | tr '\n' ' ')
echo "cgpro certificate: $cert_info"

if [ -s "$temp_chain" ]; then
    chain_info=$(openssl x509 -in "$temp_chain" -noout -text \
                 | egrep '(After |Subject):' | sort -r \
                 | sed -Ee 's/[ ]+/ /g' | tr '\n' ' ')
    echo "cgpro authority chain: $chain_info"
else
    echo "cgpro authority chain: none"
fi


## verify that cgpro has private key, certitificate, authority chain

temp_html="$temp_dir/check.html"

function check_state {
    rm -f $temp_html

    st_check=$(curl $curl_opts -o $temp_html \
        --url "$cert_url" \
        -u "$username:$password" \
        2>/dev/null)

    grep -q 'value="Remove Key and Certificate"' $temp_html && st_key="key1" || st_key="key0"
    grep -q 'value="Remove Certificate"' $temp_html && st_cert="cert1" || st_cert="cert0"
    grep -q 'value="Remove Authority Chain"' $temp_html && st_chain="chain1" || st_chain="chain0"

    echo "$st_check $st_key $st_cert $st_chain"
}


## remove old certificate and private key

st_rmcert=$(curl $curl_opts -o /dev/null \
    --url "$cert_url" \
    -H "Referer: $cert_url" \
    -u "$username:$password" \
    -d "RemoveKey=Remove Key and Certificate" \
    2>/dev/null)

st_rmchain=$(curl $curl_opts -o /dev/null \
    --url "$cert_url" \
    -H "Referer: $cert_url" \
    -u "$username:$password" \
    -d "RemoveChain=Remove Authority Chain" \
    2>/dev/null)

if [ "$st_rmcert $st_rmchain" != "200 200" \
        -o "$(check_state)" != "200 key0 cert0 chain0" ]; then
    echo "cgpro error: cannot remove old private key, certificate and authority chain"
    exit 1
fi


## add new private key and certificate

st_addkey=$(curl $curl_opts -o /dev/null \
    --url "$cert_url" \
    -H "Referer: $cert_url" \
    -u "$username:$password" \
    -F "GenKey=Generate Key" \
    -F "requestedKeySize=0" \
    -F "PrivateKey=$(cat $ssl_privkey)" \
    2>/dev/null)

st_addcert=$(curl $curl_opts -o /dev/null \
    --url "$cert_url" \
    -H "Referer: $cert_url" \
    -u "$username:$password" \
    -F "SetCert=Set Certificate" \
    -F "Certificate=$(cat $temp_cert)" \
    2>/dev/null)

if [ "$st_addkey $st_addcert" != "200 200" \
        -o "$(check_state)" != "200 key1 cert1 chain0" ]; then
    echo "cgpro error: cannot set new private key and certificate"
    exit 1
fi


## add new authority chain

if [ -s "$temp_chain" ]; then
    st_addchain=$(curl $curl_opts -o /dev/null \
        --url "$cert_url" \
        -H "Referer: $cert_url" \
        -u "$username:$password" \
        -F "SetCA=Set Authority Chain" \
        -F "CAChain=$(cat $temp_chain)" \
        2>/dev/null)

    if [ "$st_addchain" != "200" \
            -o "$(check_state)" != "200 key1 cert1 chain1" ]; then
        echo "cgpro error: cannot set new authority chain"
        exit 1
    fi
fi

echo "cgpro ok"
exit 0
