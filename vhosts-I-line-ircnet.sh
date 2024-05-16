#!/bin/bash
## Script name: vhosts.sh (v1.0)
## Description: List all virtual hosts
## Author:      base
## Date:        2022-04-29
## Version:     1.0
## Usage:       ./vhosts.sh

# Variables
DNS_RESOLVER_1="8.8.8.8"
DNS_RESOLVER_2="4.4.4.4"
DIG_OPTIONS="+short +time=1 +tries=1"

IPV4_HOSTS=$(ip -4 a | grep inet | awk '{print $2}' | grep -v -e '^127\|^10.\|^192.\|^172.' | awk -F '/' '{print $1}')
IPV6_HOSTS=$(ip -6 a | grep inet6 | awk '{print $2}' | grep -v -e '^f\|^::' | awk -F '/' '{print $1}')

EXTERNAL_IPV4=$(curl -s4X GET "https://api.ipify.org")
EXTERNAL_IPV6=$(curl -s6X GET "https://api6.ipify.org")

IPV4_ILINES=$(curl -sX GET "https://bot.ircnet.info/api/i-line?q=${EXTERNAL_IPV4}" -H "Content-Type: application/json" | jq -r '.response[].serverName' | grep -v ".onion" | sort -u)
IPV6_ILINES=$(curl -sX GET "https://bot.ircnet.info/api/i-line?q=${EXTERNAL_IPV6}" -H "Content-Type: application/json" | jq -r '.response[].serverName' | grep -v ".onion" | sort -u)

# Prepend IPv4 ILines with irc.
if [ -n "${IPV4_ILINES}" ]; then
  for HOST in ${IPV4_ILINES}; do
    if [ $(echo ${HOST} | grep -o "\." | wc -l) -lt 2 ]; then
        IPV4_ILINES=$(echo ${IPV4_ILINES} | sed "s/${HOST}/irc.${HOST}/")
    fi
  done
fi

# Prepend IPv6 ILines with irc. and check if it's an IPv6 address
if [ -n "${IPV6_ILINES}" ]; then
  for HOST in ${IPV6_ILINES}; do
    if [ $(echo ${HOST} | grep -o "\." | wc -l) -lt 2 ]; then
        IPV6_ILINES=$(echo ${IPV6_ILINES} | sed "s/${HOST}/irc.${HOST}/")
        HOST="irc.${HOST}"
    fi
    if [ $(dig ${DIG_OPTIONS} -t AAAA ${HOST} @${DNS_RESOLVER_1} @${DNS_RESOLVER_2} | wc -l) -eq 0 ]; then
        IPV6_ILINES=$(echo ${IPV6_ILINES} | sed "s/${HOST}//")
    fi
  done
fi

# Check the length of the IPV4_HOSTS variable
if [ ${#IPV4_HOSTS} -eq 0 ]; then
    IPV4_HOSTS=${EXTERNAL_IPV4}
fi

# Check the length of the IPV6_HOSTS variable
if [ ${#IPV6_HOSTS} -eq 0 ]; then
    IPV6_HOSTS=${EXTERNAL_IPV6}
fi

# Check RevDNS for each IPv4 and create a list of virtual hosts
if [ -n "${IPV4_HOSTS}" ]; then
  echo "-----------------------------------------------------------"
  echo "IPv4 vhosts:"
  for IP in ${IPV4_HOSTS}; do
      HOST=$(dig ${DIG_OPTIONS} -x ${IP} @${DNS_RESOLVER_1} @${DNS_RESOLVER_2} | sed 's/\.$//')
      echo " <*> ${IP} - ${HOST}"
  done
  if [ -n "${IPV4_ILINES}" ]; then
    echo " "
    echo "IPv4 I-Lines:"
    for IP in ${IPV4_ILINES}; do
      # Get ping response time
      PING=$(ping -4 -c 1 -W 1 ${IP} | grep "time=" | awk -F '=' '{print $4}' | awk '{print $1}')
      if [ -z "${PING}" ]; then
        PING="No ping response"
      else
        PING="${PING}ms"
      fi
      echo " --> ${IP} - ${PING}"
    done
  fi
fi

# Check RevDNS for each IPv6 and create a list of virtual hosts
if [ -n "${IPV6_HOSTS}" ]; then
  echo "-----------------------------------------------------------"
  echo "IPv6 vhosts:"
  for IP in ${IPV6_HOSTS}; do
      HOST=$(dig ${DIG_OPTIONS} -x ${IP} @${DNS_RESOLVER_1} @${DNS_RESOLVER_2} | sed 's/\.$//')
      if [ -z "${HOST}" ]; then
          HOST="No PTR record"
      fi
      echo " <*> ${IP} - ${HOST}"
  done
  if [ -n "${IPV6_ILINES}" ]; then
    echo " "
    echo "IPv6 I-Lines:"
    for IP in ${IPV6_ILINES}; do
      # Get ping response time
      PING=$(ping -6 -c 1 -W 1 ${IP} | grep "time=" | awk -F '=' '{print $4}' | awk '{print $1}')
      if [ -z "${PING}" ]; then
        PING="No ping response"
      else
        PING="${PING}ms"
      fi
      echo " --> ${IP} - ${PING}"
    done
  fi
fi

