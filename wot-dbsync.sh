#!/bin/bash
#
# WHAT ============================================================
#   Connects to MySQL over ports -m and -M on servers -h and -H,
#   exports databases -d and -D, then saves the files at -e.
#   If files for -d and -D exist at -e and are non-zero, -D is
#   overwritten with the saved export of -d. Optional invocations
#   can be used to connect to -h or -H over SSH, or to save exports
#   of -d and -D at -e without -D being overwritten.
#
# USAGE ===========================================================
#   $ ./wot-dbsync sync -s host -S user -m port -d db -h host -u user -p pass -M port -D db -H host -U user -P pass -o export/path
#   ( ) = optional, (*) = required:
#   where -s = ( ) for host -h or -H, connect over ssh
#         -S = ( ) if -s is set, login as user -S
#         -m = (*) connect to mysql over port -m on source
#         -d = (*) export database -d from source
#         -h = (*) connect to mysql host -h on source
#         -u = (*) login as user -u on source
#         -p = (*) login with password -p on source
#         -M = (*) connect to mysql over port -M on destination
#         -D = (*) export database -D from destination
#         -H = (*) connect to mysql host -H on destination
#         -U = (*) login as user -U on destination
#         -P = (*) login with password -p on destination
#         -o = (*) export path (no trailing slash)
#
#   $ ./wot-dbsync backup ...
#   where ... = params as outlined above
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

export_ssh () {
  # suser, shost, port, host, user, pass, data, path, file
  ssh ${1}@${2} "mysqldump --add-drop-table -P ${3} -h ${4} -u ${5} -p${6} ${7}" > ${8}/${9}
}

export_mysql () {
  # port, host, user, pass, path, file, data
  mysqldump --add-drop-table -P ${1} -h ${2} -u ${3} -p${4} -r ${5}/${6} ${7} 2>/dev/null
}

import_ssh () {
  # suser, shost, port, host, user, pass, data, path, file
  ssh ${1}@${2} "mysql -P ${3} -h ${4} -u ${5} -p${6} ${7}" < ${8}/${9}
}

import_mysql () {
  # port, host, user, pass, data, path, file
  mysql -P ${1} -h ${2} -u ${3} -p${4} ${5} < ${6}/${7} 2>/dev/null
}

do_sync () {
  stamp=$(timestamp)
  afile=${ahost}_${stamp}_${adata}.sql
  bfile=${bhost}_${stamp}_${bdata}.sql

  # Export
  if [[ ! -z ${shost} ]] ; then
    if [[ ! -z ${suser} ]] ; then
      if [[ ${shost} == ${ahost} ]] ; then
        export_ssh ${suser} ${shost} ${aport} ${ahost} ${auser} ${apass} ${adata} ${path} ${afile}
        export_mysql ${bport} ${bhost} ${buser} ${bpass} ${path} ${bfile} ${bdata}
      elif [[ ${shost} == ${bhost} ]] ; then
        export_mysql ${aport} ${ahost} ${auser} ${apass} ${path} ${afile} ${adata}
        export_ssh ${suser} ${shost} ${bport} ${bhost} ${buser} ${bpass} ${bdata} ${path} ${bfile}
      else
        fail "invalid ssh hostname, must match -h or -H"
      fi
    else
      fail "invalid or missing ssh arguments"
    fi
  else
    export_mysql ${aport} ${ahost} ${auser} ${apass} ${path} ${afile} ${adata}
    export_mysql ${bport} ${bhost} ${buser} ${bpass} ${path} ${bfile} ${bdata}
  fi

  # Import
  if [[ -e ${path}/${afile} && -s ${path}/${afile} ]] ; then
    if [[ -e ${path}/${bfile} && -s ${path}/${bfile} ]] ; then
      if [[ ${action} == "sync" ]] ; then
        if [[ ${shost} == ${bhost} ]] ; then
          import_ssh ${suser} ${shost} ${bport} ${bhost} ${buser} ${bpass} ${bdata} ${path} ${afile}
        else
          import_mysql ${bport} ${bhost} ${buser} ${bpass} ${bdata} ${path} ${afile}
        fi
        success "synced ${ahost}/${adata} to ${bhost}/${bdata} using ${path}/${afile}"
      else
        success "exported ${ahost}/${adata} and ${bhost}/${bdata} to ${path}"
      fi
    else
      fail "${bhost} database incomplete or unavailable"
    fi
  else
    fail "${ahost} database incomplete or unavailable"
  fi
}

if [[ ${1} == "sync" || ${1} == "backup" ]] ; then
  action=${1}
  shift
  args=$(getopt s:S:m:d:h:u:p:M:D:H:U:P:o: $*)
  set -- $args
  for i ; do
    case "$i" in
      -s ) shost="${2}"
           shift ; shift ;;
      -S ) suser="${2}"
           shift ; shift ;;
      -m ) aport="${2}"
           shift ; shift ;;
      -d ) adata="${2}"
           shift ; shift ;;
      -h ) ahost="${2}"
           shift ; shift ;;
      -u ) auser="${2}"
           shift ; shift ;;
      -p ) apass="${2}"
           shift ; shift ;;
      -M ) bport="${2}"
           shift ; shift ;;
      -D ) bdata="${2}"
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
  if [[ ! -z ${aport} && ! -z ${adata} && ! -z ${ahost} && ! -z ${auser} && ! -z ${apass} && ! -z ${bport} && ! -z ${bdata} && ! -z ${bhost} && ! -z ${buser} && ! -z ${bpass} && ! -z ${path} ]] ; then
    do_sync ${action} ${shost} ${suser} ${aport} ${adata} ${ahost} ${auser} ${apass} ${bport} ${bdata} ${bhost} ${buser} ${bpass} ${path}
  else
    fail "invalid or missing arguments"
  fi
else
  fail "unknown command: ${1}"
fi
