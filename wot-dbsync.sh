#!/bin/bash
#
# WHAT ============================================================
#   Connects to MySQL over port -m on servers -h and -H, exports
#   databases -t and -T respectively, then saves the files at -e.
#   Finally, if files for -t and -T exist at -e and are non-zero,
#   -T is overwritten with the saved export of -t.
#
# USAGE ===========================================================
#   $ ./wot-dbsync sync -m port -d db -h host -u user -p pass -M port -D db -H host -U user -P pass -o export/path
#   where -m = server a's mysql port
#         -d = server a's target db
#         -h = server a's address
#         -u = server a's mysql username
#         -p = server a's mysql password
#         -M = server b's mysql port
#         -D = server b's target db
#         -H = server b's address
#         -U = server b's mysql username
#         -P = server b's mysql password
#         -o = location to store exports (no trailing slash)
#
# Created: 05-Aug-2016

set -o errtrace

fail () {
  tput setaf 1 ; echo "Error: ${1}"
  tput sgr0    ; exit 1
}

success () {
  tput setaf 2 ; echo "Success: ${1}"
  tput sgr0    ; exit 0
}

timestamp () {
  date +%s
}

do_sync () {
  stamp=$(timestamp)
  afile=${ahost}_${stamp}_${atarg}.sql
  bfile=${bhost}_${stamp}_${btarg}.sql

  # Export
  mysqldump --add-drop-table -P ${aport} -h ${ahost} -u ${auser} -p${apass} -r ${path}/${afile} ${atarg} 2>/dev/null
  mysqldump --add-drop-table -P ${bport} -h ${bhost} -u ${buser} -p${bpass} -r ${path}/${bfile} ${btarg} 2>/dev/null

  # Import
  if [[ -e ${path}/${afile} && -s ${path}/${afile} ]] ; then
    if [[ -e ${path}/${bfile} && -s ${path}/${bfile} ]] ; then
      mysql -P ${bport} -h ${bhost} -u ${buser} -p${bpass} ${btarg} < ${path}/${afile} 2>/dev/null
      success "synced ${ahost}/${atarg} to ${bhost}/${btarg} using ${path}/${afile}..."
    else
      fail "${bhost} database incomplete or unavailable!"
    fi
  else
    fail "${ahost} database incomplete or unavailable!"
  fi
}

if [[ ${1} == 'sync' ]] ; then
  shift
  args=$(getopt m:d:h:u:p:M:D:H:U:P:o: $*)
  set -- $args
  for i ; do
    case "$i" in
      -m ) aport="${2}"
           shift ; shift ;;
      -d ) atarg="${2}"
           shift ; shift ;;
      -h ) ahost="${2}"
           shift ; shift ;;
      -u ) auser="${2}"
           shift ; shift ;;
      -p ) apass="${2}"
           shift ; shift ;;
      -M ) bport="${2}"
           shift ; shift ;;
      -D ) btarg="${2}"
           shift ; shift ;;
      -H ) bhost="${2}"
           shift ; shift ;;
      -U ) buser="${2}"
           shift ; shift ;;
      -P ) bpass="${2}"
           shift ; shift ;;
      -o ) path="${2}"
           shift ; shift ;;
      -- ) shift ; break ;;
    esac
  done
  if [[ ! -z ${aport} && ! -z ${atarg} && ! -z ${ahost} && ! -z ${auser} && ! -z ${apass} && ! -z ${bport} && ! -z ${btarg} && ! -z ${bhost} && ! -z ${buser} && ! -z ${bpass} && ! -z ${path} ]] ; then
    do_sync ${aport} ${atarg} ${ahost} ${auser} ${apass} ${bport} ${btarg} ${bhost} ${buser} ${bpass} ${path}
  else
    fail "invalid or missing arguments!"
  fi
else
  fail "unknown command: ${1}!"
fi
