#!/bin/sh
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE file for details.

#DOMAINS=(
#'amazon.com 443'
#'facebook.com 443'
#'twitter.com 443'
#'google.de 443'
#'google.com 443'
#'gmail.com 443'
#'gmail-smtp-in.l.google.com. 25 smtp'
#)

DOMAINS_LIST="google.de yahoo.com flickr.com"
# DOMAIN_LIST=$(ls /home/user100domain/data/www | egrep -v 'tar|gz|bz2|::')

ping_packet_count="2"

detect_OS() {
    ostype=$(uname -s | tr '[:upper:]' '[:lower:]')
}

check_ssl_cert()
{
    host=$1
    port=${2:-"443"}
    proto=$3

    [ -z $host ] && break;
    if [ -n "$proto" ]
    then
        starttls="-starttls $proto"
    else
        starttls=""
    fi

    if ! ping -q -c${ping_packet_count} $host > /dev/null 2>&1; then
        printf "| %30s | %5s | %-109s |\n" "$host" "$port" "No ping to host!"
        return;
    fi

    cert=`openssl s_client -servername $host -host $host -port $port -showcerts $starttls -prexit </dev/null 2>/dev/null |
              sed -n '/BEGIN CERTIFICATE/,/END CERT/p' |
              openssl x509 -text 2>/dev/null`
    end_date=`echo "$cert" | sed -n 's/ *Not After : *//p'`

    case $ostype in
        linux)
            end_date_seconds=`date '+%s' --date "$end_date"`
        ;;
        freebsd|darwin)
            end_date_seconds=`env LC_ALL=C date -j -f "%b %d %T %Y %Z" "$end_date" "+%s"`
        ;;
        # for Linux
        *)
            end_date_seconds=`date '+%s' --date "$end_date"`
        ;;
    esac
    now_seconds=`date '+%s'`
    end_date=$(echo "(${end_date_seconds}-${now_seconds})/24/3600" | bc)

    issue_dn=`echo "$cert" | sed -n 's/ *Issuer: *//p'`
    issuer=`echo ${issue_dn} | sed -n 's/.*CN=*//p' | awk -F" = " '{print $2;}'`

    serial=`echo "$cert" | openssl x509 -serial -noout`
    serial=`echo $serial | sed -n 's/.*serial=*//p'`

    printf "| %30s | %5s | %-13s | %-40s | %-50s |\n" "$host" "$port" "$end_date" "$serial" "${issuer}"
}

[ ! -e /usr/bin/openssl ] && { echo "The package openssl is not installed!"; exit; }

printf "%s\n" "/--------------------------------------------------------------------------------------------------------------------------------------------------------\\"
printf "| %30s | %5s | %-13s | %-40s | %-50s |\n" "Domain" "Port" "Expire (days)" "Serial" "Issuer"
printf "%s\n" "|--------------------------------|-------|---------------|------------------------------------------|----------------------------------------------------|"
if [ ! -z $DOMAINS ] && [[ ${DOMAINS[@]} ]]; then
    for domain in "${DOMAINS[@]}"; do
        check_ssl_cert $domain
    done
fi
# Check the second list of domains.
if [ ! -z "${DOMAINS_LIST}" ]; then
    for domain in ${DOMAINS_LIST}; do
        check_ssl_cert $domain
    done
fi
printf "%s\n" "\\--------------------------------------------------------------------------------------------------------------------------------------------------------/"
