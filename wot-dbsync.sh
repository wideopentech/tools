#!/bin/bash
#
# WHAT ============================================================
#   Connects to MySQL over port -m on servers -h and -H, exports
#   databases -t and -T respectively, then saves the files at -e.
#   Finally, if files for -t and -T exist at -e and are non-zero,
#   -T is overwritten with the saved export of -t.
#
# USAGE ===========================================================
#   $ ./wot-dbsync sync -m port -t db -h host -u user -p pass -T db -H host -U user -P pass -e export/path
#   where -m = the mysql port
#         -t = the production server target db
#         -h = the production server's address
#         -u = the production mysql username
#         -p = the production mysql password
#         -T = the development server target db
#         -H = the development server's address
#         -U = the development mysql username
#         -P = the development mysql password
#         -e = the location to store db exports (no trailing slash)
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
  pfile=${prod}_${stamp}_${ptarg}.sql
  dfile=${dev}_${stamp}_${dtarg}.sql

  # Export
  mysqldump --add-drop-table -P ${port} -h ${prod} -u ${puser} -p${ppass} -r ${path}/${pfile} ${ptarg} 2>/dev/null
  mysqldump --add-drop-table -P ${port} -h ${dev} -u ${duser} -p${dpass} -r ${path}/${dfile} ${dtarg} 2>/dev/null

  # Import
  if [[ -e ${path}/${pfile} && -s ${path}/${pfile} ]] ; then
    if [[ -e ${path}/${dfile} && -s ${path}/${dfile} ]] ; then
      mysql -P ${port} -h ${dev} -u ${duser} -p${dpass} ${dtarg} < ${path}/${pfile} 2>/dev/null
      success "synced ${prod}/${ptarg} to ${dev}/${dtarg} using ${path}/${pfile}..."
    else
      fail "${dev} database incomplete or unavailable!"
    fi
  else
    fail "${prod} database incomplete or unavailable!"
  fi
}

if [[ ${1} == 'sync' ]] ; then
  shift
  args=$(getopt m:t:h:u:p:T:H:U:P:e: $*)
  set -- $args
  for i ; do
    case "$i" in
      -m ) port="${2}"
           shift ; shift ;;
      -t ) ptarg="${2}"
           shift ; shift ;;
      -h ) prod="${2}"
           shift ; shift ;;
      -u ) puser="${2}"
           shift ; shift ;;
      -p ) ppass="${2}"
           shift ; shift ;;
      -T ) dtarg="${2}"
           shift ; shift ;;
      -H ) dev="${2}"
           shift ; shift ;;
      -U ) duser="${2}"
           shift ; shift ;;
      -P ) dpass="${2}"
           shift ; shift ;;
      -e ) path="${2}"
           shift ; shift ;;
      -- ) shift ; break ;;
    esac
  done
  if [[ ! -z ${port} && ! -z ${ptarg} && ! -z ${prod} && ! -z ${puser} && ! -z ${ppass} && ! -z ${dtarg} && ! -z ${dev} && ! -z ${duser} && ! -z ${dpass} && ! -z ${path} ]] ; then
    do_sync ${port} ${ptarg} ${prod} ${puser} ${ppass} ${dtarg} ${dev} ${duser} ${dpass} ${path}
  else
    fail "invalid or missing arguments!"
  fi
else
  fail "unknown command: ${1}!"
fi