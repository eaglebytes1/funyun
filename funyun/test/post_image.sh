#!/usr/bin/env bash
# PUT an image file to a funyun URL and optionally print returns.
DOC="
Usage:
       put_image.sh  [-v] IMAGE TARGET [CODE]
             where
             -v   if present, specifies verbose output.
           IMAGE  is an image file (JPEG or PNG types only).
		   TARGET is the funyun URL.
		   CODE   is the expected HTTP code for this request
		          (200 if not specified).
Example:image
       ./put_image.sh taylorswiftups.png
"
#
# Parse option (verbose flag)
#
export ARGS="$@"
error_exit() {
   >&2 echo "ERROR--unexpected exit from ${BASH_SOURCE} script at line:"
   >&2 echo "   $BASH_COMMAND"
   >&2 echo "   with arguments \"${ARGS}\"."
}
_V=0 
while getopts "v" OPTION
do
   case ${OPTION} in
     v) _V=1
	shift
        ;;
   esac
done
#
# Get environmental variables.
#
source ~/.funyun/funyun_rc
#
if [ ! -f "$1" ] ; then
	>&2 echo "Must specify a readable HMM file."
	exit 1
fi
#
# Parse arguments.
#
if [ "$#" -lt 2 ]; then
	>&2 echo "$DOC"
	exit 1
fi
if [ ! -f "$1" ] ; then
	>&2 echo "Must specify an image file."
	>&2 echo "$DOC"
	exit 1
fi
if [ -z "$2" ] ; then
	>&2 echo "Must specify a target URL."
	>&2 echo "$DOC"
	exit 1
fi
if [ -z "${3}" ] ; then
   code="200"
else
   code="${3}"
fi
trap error_exit EXIT
#
# Issue the PUT.
#
full_target="/funyun/${2}"
tmpfile=$(mktemp /tmp/post_image.XXX)
status=$(curl ${FUNYUN_CURL_ARGS} \
         -s -o ${tmpfile} -w '%{http_code}' \
         -F "image=@${1}" \
        ${FUNYUN_CURL_URL}${full_target})

if [ "${status}" -eq "${code}" ]; then
   if [ $_V -eq 1 ]; then
     echo "PUT of ${1} to ${full_target} returned HTTP code ${status} as expected."
      echo "Response is:"
   fi
   cat "$tmpfile"
   echo ""
   rm "$tmpfile"
else
   >&2 echo "ERROR--PUT of ${1} to ${full_target} returned HTTP code ${status}, expected ${code}."
   >&2 echo "Full response is:"
   >&2 cat ${tmpfile}
   >&2 echo ""
   rm "$tmpfile"
   trap - EXIT
   exit 1
fi
trap - EXIT