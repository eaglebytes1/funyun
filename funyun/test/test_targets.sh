#!/usr/bin/env bash
DOC="""Test all funyun targets.

Usage:
       funyun_test.sh [-v]

Options:
       -v  verbose mode, shows all returns.

Before running this script, funyun should be configured and started.
"""
set -e # exit on errors
error_exit() {
   >&2 echo "$DOC"
   >&2 echo "ERROR--unexpected exit from ${BASH_SOURCE} script at line:"
   >&2 echo "   $BASH_COMMAND"
}
trap error_exit EXIT
#
# Process option (verbose flag)
#
SLEEPTIME=1
_V=0
verbose_flag=""
while getopts "v" OPTION
do
   case ${OPTION} in
     v) _V=1
	verbose_flag="-v"
        ;;
   esac
done
#
# Get environmental variables.
#
source ~/.funyun/funyun_rc
#
# Functions
#
test_GET () {
   # Tests HTTP return code of GET, optionally printing results.
   # Arguments:
   #         $1 - target URL
   #         $2 - expected return code (200 if not supplied)
   #
   tmpfile=$(mktemp /tmp/funyun-test_all.XXXXX)
   if [ -z "${2}" ] ; then
      code="200"
   else
      code="${2}"
   fi
   status=$(curl ${FUNYUN_CURL_ARGS} -s -o ${tmpfile} -w '%{http_code}' ${FUNYUN_CURL_URL}${1})
   if [ "${status}" -eq "${code}" ]; then
      echo "GET ${1} returned HTTP code ${status} as expected."
      if [ "$_V" -eq 1 ]; then
	 echo "Response is:"
         cat ${tmpfile}
         echo ""
	 echo ""
      fi
      rm "$tmpfile"
   else
      >&2 echo "ERROR--GET ${FUNYUN_CURL_URL}${1} returned HTTP code ${status}, expected ${2}."
      >&2 echo "Full response is:"
      >&2 cat ${tmpfile}
      >&2 echo ""
      rm "$tmpfile"
      trap - EXIT
      exit 1
   fi
}
#
test_GET_PASSWORD() {
   # Tests HTTP return code of GET with password, optionally printing results.
   # Arguments:
   #         $1 - target URL
   #         $2 - expected return code (200 if not supplied)
   #
   tmpfile=$(mktemp /tmp/funyun-test_all.XXXXX)
   if [ -z "${2}" ] ; then
      code="200"
   else
      code="${2}"
   fi
   status=$(curl -u funyun:${FUNYUN_SECRET_KEY} ${FUNYUN_CURL_ARGS} -s -o ${tmpfile} -w '%{http_code}' ${FUNYUN_CURL_URL}${1})
   if [ "${status}" -eq "${code}" ]; then
      echo "GET ${1} returned HTTP code ${status} as expected."
      if [ "$_V" -eq 1 ]; then
	 echo "Response is:"
         cat ${tmpfile}
         echo ""
	 echo ""
      fi
      rm "$tmpfile"
   else
      >&2 echo "ERROR--GET ${FUNYUN_CURL_URL}${1} returned HTTP code ${status}, expected ${2}."
      >&2 echo "Full response is:"
      >&2 cat ${tmpfile}
      >&2 echo ""
      rm "$tmpfile"
      trap - EXIT
      exit 1
   fi
}
#
# Start testing.
#
echo "Testing funyun server on ${FUNYUN_CURL_URL}."
#
# Test random non-tree targets.
#
test_GET /status
test_GET /healthcheck
test_GET /badtarget 404
test_GET /funyun/time
test_GET /funyun/time_as_JSON
# Post text data.
./post_text.sh ${verbose_flag} "This is some text" pass_data
# Post images.
./post_image.sh ${verbose_flag}  taylorswiftups.png recognize_as_text

#
# Passworded targets.
#
test_GET_PASSWORD /log.txt
test_GET_PASSWORD /environment
trap - EXIT
echo "funyun  tests completed successfully."
exit 0
