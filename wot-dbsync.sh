#!/bin/bash
#
# WHAT ============================================================
#   Connects to MySQL over port -m on a source host -h and exports
#   a database -d to -o. If a user@host string -s is passed, the
#   MySQL connection to the source host -h will be opened locally
#   through SSH. This process is repeated over port -M for a
#   destination host -H, with a database -D also exported to -o.
#   If a user@host string -S is passed, the MySQL connection to the
#   destination host -H will be opened locally through SSH.
#
#   If both exports succeed and the script is invoked with the sync
#   command, the destination hosts database -D will be overwritten
#   with the export of the source hosts database -d. If the script
#   is instead invoked with the backup command, execution completes
#   after the exports of -d and -D are created, or returns an error
#   if either export appears to have failed.
#
# USAGE ===========================================================
# - SYNC ----------------------------------------------------------
#   $ ./wot-dbsync sync -s user@host -m port -h host -u user -p pass -d db -S user@host -M port -H host -U user -P pass -D db -o export/path
#   ( ) = optional, (*) = required:
#   where -s = ( ) source: route through ssh connection -s
#         -m = ( ) source: connect to mysql over port -m [default = 3306]
#         -h = (*) source: connect to mysql host -h
#         -u = (*) source: login as user -u
#         -p = ( ) source: login with password -p [default = empty]
#         -d = (*) source: export database -d
#   and
#   where -S = ( ) destination: route through ssh connection -S
#         -M = ( ) destination: connect to mysql over port -M [default = 3306]
#         -H = (*) destination: connect to mysql host -H
#         -U = (*) destination: login as user -U
#         -P = ( ) destination: login with password -P [default = empty]
#         -D = (*) destination: export database -D
#
#     and -o = (*) store database exports at -o,
#                  n.b. no trailing slash!
#
# - BACKUP --------------------------------------------------------
#   $ ./wot-dbsync backup ...
#   where ... = params as outlined above
#
# - NOTE ----------------------------------------------------------
#   If an optional argument has a default value, omitting its flag
#   during command invocation will cause that default value to be
#   passed. As an example, if the MySQL user you intend to login as
#   on destination host -H does not have a password defined, omit
#   the -P flag to pass the default (empty) password.
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
  ssh ${1} "mysqldump --add-drop-table -P ${2} -h ${3} -u ${4} --password='${5}' ${6}" > ${7}/${8}
}

export_mysql () {
  mysqldump --add-drop-table -P ${1} -h ${2} -u ${3} --password='${4}' -r ${5}/${6} ${7} 2>/dev/null
}

import_ssh () {
  ssh ${1} "mysql -P ${2} -h ${3} -u ${4} --password='${5}' ${6}" < ${7}/${8}
}

import_mysql () {
  mysql -P ${1} -h ${2} -u ${3} --password='${4}' ${5} < ${6}/${7} 2>/dev/null
}

do_sync () {
  t=$(timestamp)
  f=${h}_${t}_${d}.sql
  F=${H}_${t}_${D}.sql

  # Export source database
  if [[ ! -z ${s} ]] ; then
    export_ssh ${s} ${m} ${h} ${u} "${p}" ${d} ${o} ${f}
  else
    export_mysql ${m} ${h} ${u} "${p}" ${o} ${f} ${d}
  fi

  # Export destination database
  if [[ ! -z ${S} ]] ; then
    export_ssh ${S} ${M} ${H} ${U} "${P}" ${D} ${o} ${F}
  else
    export_mysql ${M} ${H} ${U} "${P}" ${o} ${F} ${D}
  fi

  # Import source database or exit
  if [[ -e ${o}/${f} && -s ${o}/${f} ]] ; then
    if [[ -e ${o}/${F} && -s ${o}/${F} ]] ; then
      if [[ ${command} == "sync" ]] ; then
        if [[ ! -z ${S} ]] ; then
          import_ssh ${S} ${M} ${H} ${U} "${P}" ${D} ${o} ${f}
        else
          import_mysql ${M} ${H} ${U} "${P}" ${D} ${o} ${f}
        fi
        success "synced ${h}/${d} to ${H}/${D} using ${o}/${f}"
      else
        success "exported ${h}/${d} and ${H}/${D} to ${o}"
      fi
    else
      fail "database ${D} from ${H} is incomplete or unavailable"
    fi
  else
    fail "database ${d} from ${h} is incomplete or unavailable"
  fi
}

if [[ ${1} == "sync" || ${1} == "backup" ]] ; then
  command=${1}
  shift
  args=$(getopt s:m:h:u:p:d:S:M:H:U:P:D:o: $*)
  set -- $args
  for i ; do
    case "$i" in
      -s ) s="${2}"
           shift ; shift ;;
      -m ) m="${2}"
           shift ; shift ;;
      -h ) h="${2}"
           shift ; shift ;;
      -u ) u="${2}"
           shift ; shift ;;
      -p ) p="${2}"
           shift ; shift ;;
      -d ) d="${2}"
           shift ; shift ;;
      -S ) S="${2}"
           shift ; shift ;;
      -M ) M="${2}"
           shift ; shift ;;
      -H ) H="${2}"
           shift ; shift ;;
      -U ) U="${2}"
           shift ; shift ;;
      -P ) P="${2}"
           shift ; shift ;;
      -D ) D="${2}"
           shift ; shift ;;
      -o ) o="${2}"
           shift ; shift ;;
      -- ) shift ; break ;;
    esac
  done
  if [[ ! -z ${h} && ! -z ${u} && ! -z ${d} && ! -z ${H} && ! -z ${U} && ! -z ${D} && ! -z ${o} ]] ; then
    do_sync ${command} ${s} ${m:=3306} ${h} ${u} ${p:=""} ${d} ${S} ${M:=3306} ${H} ${U} ${P:=""} ${D} ${o}
  else
    fail "invalid or missing arguments"
  fi
else
  fail "unknown command: ${1}"
fi
