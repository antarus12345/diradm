#!/bin/bash
#
################################################################################
#
# diradm:	A tool for managing posix-like things in a LDAP directory.
#		It uses ldap[add|modify|delete] from the OpenLDAP project.
#
# Version:	$Header: /code/convert/cvsroot/infrastructure/diradm/Attic/diradm.sh,v 1.1 2004/12/10 03:12:50 robbat2 Exp $
#
# Original Copyright (C) 2003  Daniel Himler  <dan@hits.at>
# Modifications Copyright (C) 2003,2004 by Robin Johnson <robbat2@gentoo.org> and
# Patrick Lougheed <pat@tfsb.org>.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
################################################################################

CONFIG_FILENAME="diradm.conf"
CONFIG="/etc/${CONFIG_FILENAME}"
if [ "${1}" == "-c" ]; then
	CONFIG="${2}"
	shift 2
fi
[ ! -f "${CONFIG}" ] && CONFIG="`dirname ${0}`/${CONFIG_FILENAME}"
[ ! -f "${CONFIG}" ] && CONFIG="~/.${CONFIG_FILENAME}"

##################### Don't touch anything below this line #####################

REVISION='$Revision: 1.1 $'
DATE='$Date: 2004/12/10 03:12:50 $'
VERSION="${REVISION} ${DATE}"
# get the stripped versions
REVISION="${REVISION% *}" ; REVISION="${REVISION/* }"
DATE="${DATE#* }" ; DATE="${DATE% *}"

if [ ! -r "${CONFIG}" ]; then
	echo "Unable to open configuration file \"${CONFIG}\"!"
	exit 1
fi

DEPENDENCIES="grep ldapsearch ldapadd ldapmodify ldapdelete sed stat perl"

mkpasswd_resolve() {
	b=`basename ${MKPASSWD}`
	d=`dirname ${MKPASSWD}`
	for i in ${d} {/,/usr}/{libexec,bin,sbin}; do
		f=${i}/${b}
		if [ -x "${f}" ]; then
			MKPASSWD="${f}"
		fi
	done
}

selftest() {
	for DEPENDENCY in ${DEPENDENCIES}; do
		EXECUTABLE="$(which "${DEPENDENCY}" 2> /dev/null)"
		if [ ! -x "${EXECUTABLE}" ]; then
			echo "Cannot find \"${DEPENDENCY}\"!"
			exit 1
		fi
	done
	${MKPASSWD} 1>/dev/null
	if [ $? -ne 1 ]; then
		echo "${MKPASSWD} failed!"
		exit 1
	fi
	# note specification of salt in test!
	test_m="$(${MKPASSWD} -m foo '$1$bJZFRnEN')"
	corr_m='$1$bJZFRnEN$O8Ms1y4YqCDDqbbt8bVFe0'
	test_i="$(${MKPASSWD} -i foo 'Eo')"
	corr_i='Eo5MXp8EqPaqE'
	test_l="$(${MKPASSWD} -l foo)"
	corr_l='5BFAFBEBFB6A0942AAD3B435B51404EE'
	test_n="$(${MKPASSWD} -n foo)"
	corr_n='AC8E657F83DF82BEEA5D43BDAF7800CC'
	t="${test_m}" c="${corr_m}"
	if [ "${t}" != "${c}" ]; then
		echo "${MKPASSWD} produced incorrect output: ${t} != ${c}"
		exit 1
	fi
	t="${test_i}" c="${corr_i}"
	if [ "${t}" != "${c}" ]; then
		echo "${MKPASSWD} produced incorrect output: ${t} != ${c}"
		exit 1
	fi
	t="${test_l}" c="${corr_l}"
	if [ "${t}" != "${c}" ]; then
		echo "${MKPASSWD} produced incorrect output: ${t} != ${c}"
		exit 1
	fi
	t="${test_n}" c="${corr_n}"
	if [ "${t}" != "${c}" ]; then
		echo "${MKPASSWD} produced incorrect output: ${t} != ${c}"
		exit 1
	fi
}

source "${CONFIG}"
CONFIGOPTIONS_STRING="LDAPURI BINDDN USERBASE GROUPBASE HOMEBASE SKEL
	DEFAULT_LOGINSHELL"
CONFIGOPTIONS_DIGIT="UIDNUMBERMIN UIDNUMBERMAX HOMEPERM DEFAULT_GIDNUMBER 
	GIDNUMBERMIN GIDNUMBERMAX SHADOWMIN SHADOWMAX SHADOWWARNING DEFAULT_SAMBAGID"
CONFIGOPTIONS_DIGIT_DISABLE="DEFAULT_SHADOWINACTIVE SHADOWFLAG"
CONFIGOPTIONS_DATE_DISABLE="DEFAULT_SHADOWEXPIRE"
for CONFIGOPTION in ${CONFIGOPTIONS_STRING}; do
	eval VALUE="\$${CONFIGOPTION}"
	if [ -z "${VALUE}" ]; then
		echo "Configuration error: ${CONFIGOPTION} not defined!"
		exit 1
	fi
done
for CONFIGOPTION in ${CONFIGOPTIONS_DIGIT}; do
	eval VALUE="\$${CONFIGOPTION}"
	if [ -z "${VALUE}" ]; then
		echo "Configuration error: ${CONFIGOPTION} not defined!"
		exit 1
	else
		echo "${VALUE}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "Configuration error: ${CONFIGOPTION} has invalid numerical value \"${VALUE}\"!"
			exit 1
		fi
	fi
done
for CONFIGOPTION in ${CONFIGOPTIONS_DIGIT_DISABLE}; do
	eval VALUE="\$${CONFIGOPTION}"
	if [ -z "${VALUE}" ]; then
		echo "Configuration error: ${CONFIGOPTION} not defined!"
		exit 1
	else
		if [ "${VALUE}" != "-1" ]; then
			echo "${VALUE}" | grep -qs "^[[:digit:]]*$"
			if [ "$?" -ne 0 ]; then
				echo "Configuration error: ${CONFIGOPTION} has invalid numerical value \"${VALUE}\"!"
				exit 1
			fi
		fi
	fi
done
for CONFIGOPTION in ${CONFIGOPTIONS_DATE_DISABLE}; do
	eval VALUE="\$${CONFIGOPTION}"
	if [ -z "${VALUE}" ]; then
		echo "Configuration error: ${CONFIGOPTION} not defined!"
		exit 1
	else
		if [ "${VALUE}" != "-1" ]; then
			echo "${VALUE}" | grep -qs "^[[:digit:]]\{4\}-[[:digit:]]\{2\}-[[:digit:]]\{2\}$"
			if [ "$?" -ne 0 ]; then
				echo "Configuration error: ${CONFIGOPTION} has invalid date value \"${VALUE}\"!"
				exit 1
			fi
		fi
	fi
done

OPTIONS="-x -H ${LDAPURI}"
if [ -n "${BINDPASS}" ]; then
	ADMINOPTIONS="${OPTIONS} -D ${BINDDN} -w ${BINDPASS}"
else
	ADMINOPTIONS="${OPTIONS} -D ${BINDDN} -W"
fi
#echo $ADMINOPTIONS
LDAPSEARCH="ldapsearch ${ADMINOPTIONS}"
LDAPADD="ldapadd ${ADMINOPTIONS}"
LDAPMODIFY="ldapmodify -c ${ADMINOPTIONS}"
LDAPDELETE="ldapdelete ${ADMINOPTIONS}"

print_usage_sub() {
	func="$1"
	case "$func" in
	useradd)
	echo " diradm useradd [-u uid [-o]] [-g group] [-G group,...] [-h hosts]"
	echo "                [-d home] [-s shell] [-c comment] [-m [-k template]]"
	echo "                [-f inactive] [-e expire] [-p passwd] [-E email] name"
	;;
	usermod)
	echo " diradm usermod [-u uid [-o]] [-g group] [-G group,...] [-h hosts]"
	echo "                [-d home [-m]] [-s shell] [-c comment] [-l new_name]"
	echo "                [-f inactive] [-e expire ] [-p passwd] [-L|-U]"
	echo "                [-E email] name"
	;;
	userdel)
	echo " diradm userdel [-r] name"
	;;
	groupadd)
	echo " diradm groupadd [-g gid [-o]] group"
	;;
	groupmod)
	echo " diradm groupmod [-g gid [-o]] [-n name] group"
	;;
	groupdel)
	echo " diradm groupdel group"
	;;
	chsh)
	echo " diradm chsh [-s login_shell] name"
	;;
	chfn)
	echo " diradm chfn [-f full_name] [-r room_no] [-w work_ph] [-h home_ph]" 
	echo "             [-o other] name"
	;;
	chage)
	echo " diradm chage [-m mindays] [-M maxdays] [-d lastday] [-I inactive]"
	echo "              [-E expiredate] [-W warndays] user"
	echo " diradm chage -l user"
	;;
	gpasswd)
	echo " diradm gpasswd group"
	echo " diradm gpasswd -a user group"
	echo " diradm gpasswd -d user group"
	echo " diradm gpasswd -R group"
	echo " diradm gpasswd -r group"
	echo " diradm gpasswd [-A user,...] [-M user,...] group"
	;;
	smbhostadd)
	echo " diradm smbhostadd [-r RID] host"
	;;
	smbhostdel)
	echo " diradm smbhostdel host"
	;;
	hostadd)
	echo " diradm hostadd [-i IP,...] [-e MAC,...] [-a othername,...] host"
	;;
	hostmod)
	echo " diradm hostmod [-i add-IP,...] [-I del-IP,...] [-e add-MAC,...]"
	echo "                [-E del-MAC,...] [-a add-othername,...]"
	echo "                [-A del-othername,...] [-n newname] host"
	;;
	hostdel)
	echo " diradm hostdel host"
	;;
	_version)
	echo " diradm version   Print diradm version number, then exit"
	;;
	_help)
	echo " diradm help      Print this help, then exit"
	;;
	_)
	echo
	;;
	esac
}

print_usage () {
	list=''
	[ -n "$1" ] && list="$1"
	echo "Usage:"
	[ -z "$list" -o "$list" == "_all" ] && list="useradd _ usermod _ userdel _ groupadd groupmod groupdel _ chsh _ chfn _ chage _ gpasswd _ smbhostadd smbhostdel _ hostadd hostmod hostdel _ _version  _help _"
	for i in $list; do
		print_usage_sub ${i}
	done;
}

print_version () {
	echo "diradm ${VERSION}"
	echo "Copyright (C) 2003 Daniel Himler <dan@hits.at>"
	echo "Copyright (C) 2003-2004 Robin H. Johnson <robbat2@orbis-terrarum.net>"
	echo "Copyright (C) 2003-2004 Patrick Lougheed <pat@tfsb.org>"
	echo "This is free software; see the source for copying conditions.  There is NO"
	echo "warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE."
}

# Call me nuts, I just wrote set functions in shell!
set_union() {
	a="$1"
	b="$2"
	t="$a"
	for i in $b; do
		echo "${a}" | grep -wqs "${i}"
		# if not there, add
		[ "$?" -ne 0 ] && t="${t} ${i}"
	done
	echo "$t"
}

set_intersection() {
	a="$1"
	b="$2"
	t=''
	for i in $a; do
		echo "${b}" | grep -wqs "${i}"
		# if there, add
		[ "$?" -eq 0 ] && t="${t} ${i}"
	done
	echo "$t"
}
set_complement() {
	a="$1"
	b="$2"
	t=''
	for i in $a; do
		echo "${b}" | grep -wqs "${i}"
		# if not there, add
		[ "$?" -ne 0 ] && t="${t} ${i}"
	done
	echo "$t"
}

# eg: 
# ldap_search_getattr "${GROUPBASE}" "gidNumber=100" cn
# (returns 'users' on systems with that initial data in LDAP)
ldap_search_getattr() {
	basedn="${1}"
	search="${2}"
	attr="${3}"
	regex="^${attr}:{1,2} "
	${LDAPSEARCH} -b "${basedn}" "${search}" ${attr} | egrep "${regex}" | sed -re "s/${regex}//"
}

ldap_base64_decode() {
	echo "$*" | perl -e 'use MIME::Base64; print(decode_base64(<STDIN>));'
}

search_attr() {
	${LDAPSEARCH} -b "${1}" "${2}" | grep -qs "^${3}$"
	return "$?"
}

search_smbhost() {
	search_attr "${SAMBAHOSTBASE}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}

search_host() {
	search_attr "${HOSTBASE}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}
search_user() {
	search_attr "${USERBASE}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}

search_group() {
	search_attr "${GROUPBASE}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}

append() {
	[ "x${*}" != "x" ] && COMMAND="${COMMAND}\n${*}"
}

append_attrib_replace() {
	local attrib="$1"
	shift
	append "replace: ${attrib}\n${attrib}: ${*}"
}
append_attrib_add() {
	local attrib="$1"
	shift
	append "add: ${attrib}\n${attrib}: ${*}"
}

runmodify() {
if [ -n "${DEBUG}" ]; then
	echo LDAP Modify:
	echo -------
	[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | uniq
	echo -------
fi

[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | ${LDAPMODIFY} > /dev/null
}

runadd() {
if [ -n "${DEBUG}" ]; then
	echo LDAP Add:
	echo -------
	[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | uniq
	echo -------
fi
[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | ${LDAPADD} > /dev/null
}

rundelete() {
if [ -n "${DEBUG}" ]; then
	echo LDAP Delete
	echo -------
	echo "${*}"
	echo -------
fi
[ -n "${*}" ] && ${LDAPDELETE} "${*}" > /dev/null
}

# Convert N days since Jan 1, 1970 to a date
# first paramater is the days
# rest is passed to date
days_to_date() {
local D="${1}"
shift
#date -u -d "Jan $((${D}+1)), 1970" ${OPT}
date -u -d "00:00:00 1970-01-01 UTC +$D days" "${*}"
}

# Does the reverse of days_to_date
# expects a date
# returns a number of days since Jan 1, 1970
date_to_days() {
local UNIXTIMESTAMP="$(date -u +%s -d "${*}")"
echo $((${UNIXTIMESTAMP}/(3600*24)))
}

daysnow() {
	date_to_days `date -u`
}


useradd () {
	[ -z "${modulename}" ] && modulename="useradd"
	while getopts "u:og:G:h:d:s:c:mk:f:e:E:p:Si" OPTION; do
		case "${OPTION}" in
			u) UIDNUMBER="${OPTARG}";;
			o) DUPLICATES="yes";;
			g) GID="${OPTARG}";;
			G) OTHERGROUPS="${OPTARG}";;
			h) HOSTLIST="${OPTARG}";;
			d) HOMEDIRECTORY="${OPTARG}";;
			s) LOGINSHELL="${OPTARG}";;
			c) COMMENT="${OPTARG}";;
			m) CREATEHOMEDIR="yes";;
			k) SKEL="${OPTARG}";;
			f) SHADOWINACTIVE="${OPTARG}";;
			e) SHADOWEXPIRE="${OPTARG}";;
			E) EMAIL="${OPTARG}";;
			p) USERPASSWORD="${OPTARG}";;
			S) SAMBA="yes";;
			i) IRIX="yes";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage
		exit 2
	else
		LOGIN="${1}"
	fi
	echo "${LOGIN}" | grep -qs "^[[:alnum:]\.]*$"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Invalid user name \"${LOGIN}\""
		exit 3
	else
		search_user "uid" "${LOGIN}"
		if [ "$?" -eq 0 ]; then
			echo "${modulename}: User \"${LOGIN}\" exists"
			exit 9
		fi
	fi
	if [ -n "${UIDNUMBER}" ]; then
		echo "${UIDNUMBER}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid numeric argument \"${UIDNUMBER}\""
			exit 3
		fi
		search_user "uidNumber" "${UIDNUMBER}"
		if [ "$?" -eq 0 -a "${DUPLICATES}" != "yes" ]; then
			echo "${modulename}: uid ${UIDNUMBER} is not unique"
			exit 4
		fi
	else
		UIDNUMBER="${UIDNUMBERMIN}"
		while [ "${UIDNUMBER}" -le "${UIDNUMBERMAX}" ]; do
			search_user "uidNumber" "${UIDNUMBER}"
			[ "$?" -ne 0 ] && break
			let UIDNUMBER="${UIDNUMBER} + 1"
		done
		if [ "${UIDNUMBER}" -gt "${UIDNUMBERMAX}" ]; then
			echo "${modulename}: Can't get unique uid"
			exit 4
		fi
	fi
	if [ -n "${GID}" ]; then
		echo "${GID}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -eq 0 ]; then
			GIDNUMBER="${GID}"
		else
			GIDNUMBER="$(ldap_search_getattr "${GROUPBASE}" "cn=${GID}" gidNumber)"
			if [ -z "${GIDNUMBER}" ]; then
				echo "${modulename}: Unknown group \"${GID}\""
				exit 6
			fi
		fi
	else
		GIDNUMBER="${DEFAULT_GIDNUMBER}"
	fi
	search_group "gidNumber" "${GIDNUMBER}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Warning! Group ${GIDNUMBER} not found. Adding user anyway."
	fi
	if [ -n "${OTHERGROUPS}" ]; then
		OTHERGROUPS="${OTHERGROUPS//,/ }"
		for POSIXGROUP in ${OTHERGROUPS}; do
			echo "${POSIXGROUP}" | grep -qs "^[[:digit:]]*$"
			if [ "$?" -eq 0 ]; then
				search_group "gidNumber" "${POSIXGROUP}"
				if [ "$?" -ne 0 ]; then
					echo "${modulename}: Unknown group \"${POSIXGROUP}\""
					exit 6
				fi
				POSIXGROUP="$(ldap_search_getattr "${GROUPBASE}" "gidNumber=${POSIXGROUP}" cn)"
				ADDTOGROUPS="${ADDTOGROUPS} ${POSIXGROUP}"
			else
				search_group "cn" "${POSIXGROUP}"
				if [ "$?" -ne 0 ]; then
					echo "${modulename}: Unknown group \"${POSIXGROUP}\""
					exit 6
				fi
				ADDTOGROUPS="${ADDTOGROUPS} ${POSIXGROUP}"
			fi
		done
	fi
	if [ -n "${HOSTLIST}" ]; then
		HOSTLIST="${HOSTLIST//,/ }"
		for HOST in ${HOSTLIST}; do
			HOSTS="${HOSTS}host: ${HOST}\n"
		done
		HOSTS="$(echo -e "${HOSTS}")"
	fi
	[ -z "${HOMEDIRECTORY}" ] && HOMEDIRECTORY="${HOMEBASE}/${LOGIN}"
	echo "${HOMEDIRECTORY}" | grep -qs "^/"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Invalid home directory \"${HOMEDIRECTORY}\""
		exit 3
	fi
	[ -z "${LOGINSHELL}" ] && LOGINSHELL="${DEFAULT_LOGINSHELL}"
	echo "${LOGINSHELL}" | grep -qs "^/"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Invalid shell \"${LOGINSHELL}\""
		exit 3
	fi
	[ -z "${COMMENT}" ] && COMMENT="${LOGIN},,,"
	if [ -n "${HOMEDIRECTORY}" -a "${CREATEHOMEDIR}" = "yes" ]; then
		if [ "$(whoami)" != "root" ]; then
			echo "${modulename}: Only root may create home directories"
			exit 12
		fi
		PARENTDIR="$(dirname "${HOMEDIRECTORY}")"
		if [ ! -w "${PARENTDIR}" ]; then
			echo "${modulename}: Cannot create directory \"${HOMEDIRECTORY}\""
			exit 12
		fi
	fi
	[ -z "${SHADOWINACTIVE}" ] && SHADOWINACTIVE="${DEFAULT_SHADOWINACTIVE}"
	if [ "${SHADOWINACTIVE}" != "-1" ]; then
		echo "${SHADOWINACTIVE}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid numeric argument \"${SHADOWINACTIVE}\""
			exit 3
		fi
	fi
	[ -z "${SHADOWEXPIRE}" ] && SHADOWEXPIRE="${DEFAULT_SHADOWEXPIRE}"
	if [ "${SHADOWEXPIRE}" != "-1" ]; then
		echo "${SHADOWEXPIRE}" | grep -qs "^[[:digit:]]\{4\}-[[:digit:]]\{2\}-[[:digit:]]\{2\}$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid date \"${SHADOWEXPIRE}\""
			exit 3
		else
			SHADOWEXPIRE="$(date_to_days "${SHADOWEXPIRE}")"
		fi
	fi
	# Set this to today's date
	# This is N days since Jan 1, 1970
	SHADOWLASTCHANGE="$(daysnow)"

	# Users Full Name
	FULLNAME="$(echo ${COMMENT} | cut -d, -f1)"
	ROOMNUMBER="$(echo ${COMMENT} | cut -d, -f2)"
	WORKPHONE="$(echo ${COMMENT} | cut -d, -f3)"
	HOMEPHONE="$(echo ${COMMENT} | cut -d, -f4)"
	FIRSTNAME="${FULLNAME// *}"
	SURNAME="${FULLNAME##* }"
	CN="${FIRSTNAME}"

	# Setup the commands
	append "dn: uid=${LOGIN},${USERBASE}"
	append "changetype: add"
	append "objectClass: top"
	#append "objectClass: account"
	append "objectClass: posixAccount"
	append "objectClass: shadowAccount"
	append "objectClass: organizationalPerson"
	append "objectClass: inetOrgperson"
	append "objectClass: userInformation"
	append "uid: ${LOGIN}"
	userPasswordCrypt="$(${MKPASSWD} -m ${USERPASSWORD})"
	sambaNTPassword="$(${MKPASSWD} -n ${USERPASSWORD})"
	sambaLMPassword="$(${MKPASSWD} -l ${USERPASSWORD})"
	irixPassword="$(${MKPASSWD} -i ${USERPASSWORD})"
	append "userPassword: {CRYPT}${userPasswordCrypt}"
	append "uidNumber: ${UIDNUMBER}"
	append "gidNumber: ${GIDNUMBER}"
	append "cn: ${CN}"
	append "homeDirectory: ${HOMEDIRECTORY}"
	append "loginShell: ${LOGINSHELL}"
	append "shadowLastChange: ${SHADOWLASTCHANGE}"
	append "shadowInactive: ${SHADOWINACTIVE}"
	append "shadowExpire: ${SHADOWEXPIRE}"
	append "shadowMin: ${SHADOWMIN}"
	append "shadowMax: ${SHADOWMAX}"
	append "shadowWarning: ${SHADOWWARNING}"
	append "shadowFlag: ${SHADOWFLAG}"
	[ -n "${HOSTS}" ] && append "${HOSTS}"
	[ -n "${SURNAME}" ] && append "sn: ${SURNAME}"
	[ -n "${FIRSTNAME}" ] && append "givenName: ${FIRSTNAME}"
	[ -n "${FULLNAME}" ] && append "displayName: ${FULLNAME}"
	[ -n "${ROOMNUMBER}" ] && append "roomNumber: ${ROOMNUMBER}"
	[ -n "${HOMEPHONE}" ] && append "homePhone: ${HOMEPHONE}"
	[ -n "${WORKPHONE}" ] && append "telephoneNumber: ${WORKPHONE}"
	[ -n "${EMAIL}" ] && append "email: ${EMAIL}"
	append "gecos: ${COMMENT}"

	if [ "${SAMBA}" = "yes" -a -n "${SAMBADOMAINSID}" ]; then
		append "objectClass: sambaSamAccount"

		let RID="2*${UIDNUMBER}+1000"
		SID="${SAMBADOMAINSID}-${RID}" 

		append "sambaSID: ${SID}"
		append "sambaPrimaryGroupSID: ${SAMBADOMAINSID}-${DEFAULT_SAMBAGID}"
		append "sambaAcctFlags: [UX         ]"
		append "sambaPwdCanChange: 0"
		append "sambaNTPassword: ${sambaNTPassword}"
		append "sambaLMPassword: ${sambaLMPassword}"
		append "sambaPwdLastSet: $(date -u +%s)";
		[ -n "${SAMBADRIVE}" ] && append "sambaHomeDrive: ${SAMBADRIVE}"
		[ -n "${SAMBAPATHPREPEND}" ] && append "sambaHomePath: ${SAMBAPATHPREPEND}\\\\${LOGIN}"
		[ -n "${SAMBAPROFILEPREPEND}" ] && append "sambaProfilePath: ${SAMBAPROFILEPREPEND}\\\\${LOGIN}"
		[ -n "${SAMBALOGONSCRIPT}" ] && append "sambaLogonScript: ${SAMBALOGONSCRIPT}"
	fi
	if [ "${IRIX}" = "yes" ]; then
		append "objectClass: irixAccount"
		append "irixPassword: {CRYPT}${irixPassword}"
	fi
	append "\n\n"
	
	# group stuff	
	if [ -n "${ADDTOGROUPS}" ]; then
		DELETEFROMGROUPS="$(ldap_search_getattr "${GROUPBASE}" "memberUid=${LOGIN}" cn)"
		for POSIXGROUP in ${DELETEFROMGROUPS}; do
			append "dn: cn=${POSIXGROUP},${GROUPBASE}\ndelete: memberUid\nmemberUid: ${LOGIN}\n"
		done
		for POSIXGROUP in ${ADDTOGROUPS}; do
			append "dn: cn=${POSIXGROUP},${GROUPBASE}\nadd: memberUid\nmemberUid: ${LOGIN}\n"
		done
	fi

	# automounted homedirs etc.
	append "dn: cn=${LOGIN},${AUTOMOUNT_USERBASE}"
	append "changetype: add"
	append "objectClass: automount"
	append "cn: ${LOGIN}"
	# build correct string
	val="${LOGIN}"
	AUTOMOUNT_APPEND="`eval echo "${AUTOMOUNT_HASHING}"`"
	append "automountInformation: ${AUTOMOUNT_OPTIONS} ${AUTOMOUNT_BASE}/${AUTOMOUNT_APPEND}"
	append "description: ${AUTOMOUNT_USERDESC}";
	append "\n\n"

	#echo -e "${COMMAND}"
	runmodify

	# Create Homedir
	targetdir="${AUTOMOUNT_BASE}/${AUTOMOUNT_APPEND}"
	# strip NFS host and assume local
	targetdir="${targetdir/*:}"
	if [ "${CREATEHOMEDIR}" = "yes" -a ! -d "${HOMEDIRECTORY}" -a ! -d "${targetdir}" ]; then
		echo Making Homedir stored in $targetdir, available as $HOMEDIRECTORY
		cp -ra "${SKEL}" "${targetdir}" >/dev/null
		chmod "${HOMEPERM}" "${targetdir}"
		chown -R "${UIDNUMBER}":"${GIDNUMBER}" "${targetdir}"
	fi
}

usermod () {
	[ -z "${modulename}" ] && modulename="usermod"
	if [ "${#}" -le 1 ]; then
		echo "${modulename}: No flags given"
		exit 2
	fi
	while getopts "u:og:G:h:d:s:c:l:mf:e:p:LUS" OPTION; do
		case "${OPTION}" in
			u) UIDNUMBER="${OPTARG}";;
			o) DUPLICATES="yes";;
			g) GID="${OPTARG}";;
			G) OTHERGROUPS="${OPTARG}";;
			h) HOSTLIST="${OPTARG}";;
			d) HOMEDIRECTORY="${OPTARG}";;
			s) LOGINSHELL="${OPTARG}";;
			c) COMMENT="${OPTARG}";;
			l) NEWLOGIN="${OPTARG}";;
			m) MOVEHOMEDIR="yes";;
			f) SHADOWINACTIVE="${OPTARG}";;
			e) SHADOWEXPIRE="${OPTARG}";;
			E) EMAIL="${OPTARG}";;
			p) if [ -n "${LOCKED}" ]; then print_usage ${modulename} ; exit 1; fi; USERPASSWORD="${2}";;
			L) if [ -n "${LOCKED}" -o -n "${USERPASSWORD}" ]; then print_usage ${modulename}; exit 1; fi; LOCKED="yes";;
			U) if [ -n "${LOCKED}" -o -n "${USERPASSWORD}" ]; then print_usage ${modulename}; exit 1; fi; LOCKED="no";;
			S) SAMBA="yes";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		LOGIN="${1}"
	fi
	search_user "uid" "${LOGIN}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: User \"${LOGIN}\" does not exist"
		exit 6
	fi
	if [ -n "${UIDNUMBER}" ]; then
		echo "${UIDNUMBER}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid numeric argument \"${UIDNUMBER}\""
			exit 3
		fi
		search_user "uidNumber" "${UIDNUMBER}"
		if [ "$?" -eq 0 -a "${DUPLICATES}" != "yes" ]; then
			echo "${modulename}: uid ${UIDNUMBER} is not unique"
			exit 4
		fi
	fi
	if [ -n "${GID}" ]; then
		echo "${GID}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -eq 0 ]; then
			GIDNUMBER="${GID}"
		else
			GIDNUMBER="$(ldap_search_getattr "${GROUPBASE}" "cn=${GID}" gidNumber)"
			if [ -z "${GIDNUMBER}" ]; then
				echo "${modulename}: Unknown group \"${GID}\""
				exit 6
			fi
		fi
		search_group "gidNumber" "${GIDNUMBER}"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Warning! Group ${GIDNUMBER} not found. Modifying user anyway."
		fi
	fi
	if [ -n "${OTHERGROUPS}" ]; then
		OTHERGROUPS="${OTHERGROUPS//,/ }"
		for POSIXGROUP in ${OTHERGROUPS}; do
			echo "${POSIXGROUP}" | grep -qs "^[[:digit:]]*$"
			if [ "$?" -eq 0 ]; then
				search_group "gidNumber" "${POSIXGROUP}"
				if [ "$?" -ne 0 ]; then
					echo "${modulename}: Unknown other group number \"${POSIXGROUP}\""
					exit 6
				fi
				POSIXGROUP="$(ldap_search_getattr "${GROUPBASE}" "gidNumber=${POSIXGROUP}" cn)"
				ADDTOGROUPS="${ADDTOGROUPS} ${POSIXGROUP}"
			else
				search_group "cn" "${POSIXGROUP}"
				if [ "$?" -ne 0 ]; then
					echo "${modulename}: Unknown other group \"${POSIXGROUP}\""
					exit 6
				fi
				ADDTOGROUPS="${ADDTOGROUPS} ${POSIXGROUP}"
			fi
		done
	fi
	if [ -n "${HOSTLIST}" ]; then
		HOSTLIST="${HOSTLIST//,/ }"
		for HOST in ${HOSTLIST}; do
			HOSTS="${HOSTS}host: ${HOST}\n"
		done
		HOSTS="$(echo -e "${HOSTS}")"
	fi
	if [ -n "${HOMEDIRECTORY}" ]; then
		echo "${HOMEDIRECTORY}" | grep -qs "^/"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid home directory \"${HOMEDIRECTORY}\""
			exit 3
		fi
	fi
	if [ -n "${LOGINSHELL}" ]; then
		echo "${LOGINSHELL}" | grep -qs "^/"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid shell \"${LOGINSHELL}\""
			exit 3
		fi
	fi
	if [ -n "${NEWLOGIN}" ]; then
		echo "${NEWLOGIN}" | grep -qs "^[[:alnum:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid user name \"${NEWLOGIN}\""
			exit 3
		else
			search_user "uid" "${NEWLOGIN}"
			if [ "$?" -eq 0 ]; then
				echo "${modulename}: User \"${NEWLOGIN}\" exists"
				exit 9
			fi
		fi
		if [ -z "${ADDTOGROUPS}" ]; then
			#ADDTOGROUPS="$(${LDAPSEARCH} -b "${GROUPBASE}" "memberUid=${LOGIN}" | grep "^cn:" | sed "s/^cn: //")"
			ADDTOGROUPS="$(ldap_search_getattr "${GROUPBASE}" "memberUid=${LOGIN}" cn)"
		fi
	fi
	if [ -n "${HOMEDIRECTORY}" -a "${MOVEHOMEDIR}" = "yes" ]; then
		if [ "$(whoami)" != "root" ]; then
			echo "${modulename}: Only root may move home directories"
			exit 12
		fi
		PARENTDIR="$(dirname "${HOMEDIRECTORY}")"
		if [ ! -w "${PARENTDIR}" ]; then
			echo "${modulename}: Cannot create directory \"${HOMEDIRECTORY}\""
			exit 12
		fi
		OLDHOMEDIRECTORY="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" homeDirectory)"
	fi
	if [ -n "${SHADOWINACTIVE}" ]; then
		if [ "${SHADOWINACTIVE}" != "-1" ]; then
			echo "${SHADOWINACTIVE}" | grep -qs "^[[:digit:]]*$"
			if [ "$?" -ne 0 ]; then
				echo "${modulename}: Invalid numeric argument \"${SHADOWINACTIVE}\""
				exit 3
			fi
		fi
	fi
	if [ -n "${SHADOWEXPIRE}" ]; then
		if [ "${SHADOWEXPIRE}" != "-1" ]; then
			echo "${SHADOWEXPIRE}" | grep -qs "^[[:digit:]]\{4\}-[[:digit:]]\{2\}-[[:digit:]]\{2\}$"
			if [ "$?" -ne 0 ]; then
				echo "${modulename}: Invalid date \"${SHADOWEXPIRE}\""
				exit 3
			else
				let SHADOWEXPIRE="$(date -d "${SHADOWEXPIRE}" +%s) / 86400"
			fi
		fi
	fi
	if [ -n "${LOCKED}" ]; then
		OLDPASSWORDENCODED="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" userPassword)"
		OLDPASSWORD="$(ldap_base64_decode "${OLDPASSWORDENCODED}")"
		sambaNTPassword="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" sambaNTPassword)"
		sambaLMPassword="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" sambaLMPassword)"
		irixPassword="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" irixPassword)"
		if [ "${LOCKED}" = "yes" ]; then
			USERPASSWORD="$(echo "${OLDPASSWORD}" | sed -re 's/}[!]?/}!/')"
			[ -n "${sambaNTPassword}" ] && sambaNTPassword="$(echo "${sambaNTPassword}" | sed -re 's/^[!]?/!/')"
			[ -n "${sambaLMPassword}" ] && sambaLMPassword="$(echo "${sambaLMPassword}" | sed -re 's/^[!]?/!/')"
			[ -n "${irixPassword}" ] && irixPassword="$(echo "${irixPassword}" | sed -re 's/}[!]?/}!/')"
		elif [ "${LOCKED}" = "no" ]; then
			USERPASSWORD="$(echo "${OLDPASSWORD}" | sed -re 's/}!/}/')"
			[ -n "${sambaNTPassword}" ] && sambaNTPassword="$(echo "${sambaNTPassword}" | sed -re 's/^[!]//')"
			[ -n "${sambaLMPassword}" ] && sambaLMPassword="$(echo "${sambaLMPassword}" | sed -re 's/^[!]//')"
			[ -n "${irixPassword}" ] && irixPassword="$(echo "${irixPassword}" | sed -re 's/}!/}/')"
		fi
	fi
	COMMAND_DN="dn: uid=${LOGIN},${USERBASE}"
	if [ -n "${ADDTOGROUPS}" ]; then
		DELETEFROMGROUPS="$(ldap_search_getattr "${GROUPBASE}" "memberUid=${LOGIN}" cn)"
		for POSIXGROUP in ${DELETEFROMGROUPS}; do
			append "dn: cn=${POSIXGROUP},${GROUPBASE}\ndelete: memberUid\nmemberUid: ${LOGIN}\n"
		done
		[ -n "${NEWLOGIN}" ] && LOGIN="${NEWLOGIN}"
		for POSIXGROUP in ${ADDTOGROUPS}; do
			append "dn: cn=${POSIXGROUP},${GROUPBASE}\nadd: memberUid\nmemberUid: ${LOGIN}\n"
		done
	fi
	append "${COMMAND_DN}"
	[ -n "${UIDNUMBER}" ] && append_attrib_replace "uidNumber" "${UIDNUMBER}\n-"
	[ -n "${GIDNUMBER}" ] && append_attrib_replace "gidNumber" "${GIDNUMBER}\n-"
	[ -n "${EMAIL}" ] && append_attrib_replace "email" "${EMAIL}\n-"
	[ -n "${HOSTS}" ] && append "replace: host\n${HOSTS}\n-"
	[ -n "${HOMEDIRECTORY}" ] && append_attrib_replace "homeDirectory" "${HOMEDIRECTORY}\n-"
	[ -n "${LOGINSHELL}" ] && append_attrib_replace "loginShell" "${LOGINSHELL}\n-"
	[ -n "${COMMENT}" ] && FULLNAME=${COMMENT//,*}
	[ -n "${COMMENT}" ] && append "replace: cn gecos\ncn: ${FULLNAME}\ncn: ${COMMENT}\n-"
	[ -n "${SHADOWINACTIVE}" ] && append_attrib_replace "shadowInactive" "${SHADOWINACTIVE}\n-"
	[ -n "${SHADOWEXPIRE}" ] && append_attrib_replace "shadowExpire" "${SHADOWEXPIRE}\n-"
	[ -n "${USERPASSWORD}" ] && append_attrib_replace "userPassword" "${USERPASSWORD}\n-"
	[ -n "${sambaNTPassword}" ] && append_attrib_replace "sambaNTPassword" "${sambaNTPassword}\n-"
	[ -n "${sambaLMPassword}" ] && append_attrib_replace "sambaLMPassword" "${sambaLMPassword}\n-"
	[ -n "${irixPassword}" ] && append_attrib_replace "irixPassword" "${irixPassword}\n-"
	[ "${COMMAND}" = "${COMMAND_DN}" ] && unset COMMAND
	[ -n "${NEWLOGIN}" ] && append "dn: uid=${LOGIN},${USERBASE}\nchangetype: modrdn\nnewrdn: uid=${NEWLOGIN}"
	#echo -e ">>>${LINENO}\n${COMMAND}<<<${LINENO}"
	runmodify
	if [ "${MOVEHOMEDIR}" = "yes" ]; then
		mv ${OLDHOMEDIRECTORY} ${HOMEDIRECTORY} > /dev/null 2>&1
		chmod "${HOMEPERM}" "${HOMEDIRECTORY}"
		chown -R "${UIDNUMBER}":"${GIDNUMBER}" "${HOMEDIRECTORY}"
	fi
}

userdel () {
	[ -z "${modulename}" ] && modulename="userdel"
	while getopts "r" OPTION; do
		case "${OPTION}" in
			r) REMOVEHOMEDIR="yes";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		LOGIN="${1}"
	fi
	search_user "uid" "${LOGIN}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: User \"${LOGIN}\" does not exist"
		exit 6
	fi
	if [ "${REMOVEHOMEDIR}" = "yes" ]; then
		if [ "$(whoami)" != "root" ]; then
			echo "${modulename}: Only root may remove home directories"
			exit 12
		fi
		HOMEDIRECTORY="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" homeDirectory)"
		UIDNUMBER="$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" uidNumber)"
	fi
	append "dn: uid=${LOGIN},${USERBASE}\nchangetype: delete\n"
	DELETEFROMGROUPS="$(ldap_search_getattr "${GROUPBASE}" "memberUid=${LOGIN}" cn)"
	for POSIXGROUP in ${DELETEFROMGROUPS}; do
		append "dn: cn=${POSIXGROUP},${GROUPBASE}\ndelete: memberUid\nmemberUid: ${LOGIN}\n"
	done
	runmodify
	if [ "${REMOVEHOMEDIR}" = "yes" -a -d "${HOMEDIRECTORY}" ]; then
		OWNER_UIDNUMBER="$(stat "${HOMEDIRECTORY}" |
			grep "Uid:" |
			sed "s/^.*Uid:.*(\(.*\)\/.*Gid:.*$/\1/" | tr -d " ")"
		if [ "${UIDNUMBER}" -eq "${OWNER_UIDNUMBER}" ]; then
			rm -rf "${HOMEDIRECTORY}"
		else
			echo "${modulename}: ${HOMEDIRECTORY} not owned by user \"${LOGIN}\", not removing"
			exit 12
		fi
	fi
}

groupadd () {
	[ -z "${modulename}" ] && modulename="groupadd"
	while getopts "g:o" OPTION; do
		case "${OPTION}" in
			g) GIDNUMBER="${OPTARG}";;
			o) DUPLICATES="yes";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		CN="${1}"
	fi
	echo "${CN}" | grep -qs "^[[:alnum:]]*$"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: \"${CN}\" is not a valid group name"
		exit 3
	else
		search_group "cn" "${CN}"
		if [ "$?" -eq 0 ]; then
			echo "${modulename}: Group \"${CN}\" exists"
			exit 9
		fi
	fi
	if [ -n "${GIDNUMBER}" ]; then
		echo "${GIDNUMBER}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid numeric argument \"${GIDNUMBER}\""
			exit 2
		fi
		search_group "gidNumber" "${GIDNUMBER}"
		if [ "$?" -eq 0 -a "${DUPLICATES}" != "yes" ]; then
			echo "${modulename}: gid ${GIDNUMBER} is not unique"
			exit 4
		fi
	else
		GIDNUMBER="${GIDNUMBERMIN}"
		while [ "${GIDNUMBER}" -le "${GIDNUMBERMAX}" ]; do
			search_group "gidNumber" "${GIDNUMBER}"
			[ "$?" -ne 0 ] && break
			let GIDNUMBER="${GIDNUMBER} + 1"
		done
		if [ "${GIDNUMBER}" -gt "${GIDNUMBERMAX}" ]; then
			echo "${modulename}: Can't get unique gid"
			exit 4
		fi
	fi
	# setup commands
	append "dn: cn=${CN},${GROUPBASE}"
	append "changetype: add"
	append "objectClass: top"
	append "objectClass: posixGroup"
	append "cn: ${CN}"
	append "gidNumber: ${GIDNUMBER}"
	append "\n\n"
	runmodify
}

groupmod () {
	[ -z "${modulename}" ] && modulename="groupmod"
	if [ "${#}" -le 1 ]; then
		echo "${modulename}: No flags given"
		exit 2
	fi
	while getopts "g:on:" OPTION; do
		case "${OPTION}" in
			g) GIDNUMBER="${OPTARG}";;
			o) DUPLICATES="yes";;
			n) NEWCN="${OPTARG}";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		CN="${1}"
	fi
	search_group "cn" "${CN}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Group \"${CN}\" does not exist"
		exit 6
	fi
	if [ -n "${GIDNUMBER}" ]; then
		echo "${GIDNUMBER}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid numeric argument \"${GIDNUMBER}\""
			exit 2
		fi
		search_group "gidNumber" "${GIDNUMBER}"
		if [ "$?" -eq 0 -a "${DUPLICATES}" != "yes" ]; then
			echo "${modulename}: gid ${GIDNUMBER} is not unique"
			exit 4
		fi
	fi
	if [ -n "${NEWCN}" ]; then
		echo "${NEWCN}" | grep -qs "^[[:alnum:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: \"${NEWCN}\" is not a valid group name"
			exit 3
		else
			search_group "cn" "${NEWCN}"
			if [ "$?" -eq 0 ]; then
				echo "${modulename}: \"${NEWCN}\" is not a unique name"
				exit 9
			fi
		fi
	fi
	[ -n "${GIDNUMBER}" ] && append "dn: cn=${CN},${GROUPBASE}\nreplace: gidNumber\ngidNumber: ${GIDNUMBER}\n"
	[ -n "${NEWCN}" ] && append "dn: cn=${CN},${GROUPBASE}\nchangetype: modrdn\nnewrdn: cn=${NEWCN}"
	runmodify
}

groupdel () {
	[ -z "${modulename}" ] && modulename="groupdel"
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		CN="${1}"
	fi
	search_group "cn" "${CN}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Group \"${CN}\" does not exist"
		exit 6
	fi
	rundelete "cn=${CN},${GROUPBASE}" 
}

grabinteractiveinput() {
	msg="${1}"
	setting="${2}"
	echo -en "${msg}"
	read userinput
	userinput="`echo "${userinput}" | sed -re 's/^[[:space:]]*//g;s/[[:space:]]*$//g;'`"
	eval ${setting}="${userinput}"
}

chsh() {
	[ -z "${modulename}" ] && modulename="chsh"
	while getopts "s:" OPTION; do
		case "${OPTION}" in
			s) LOGINSHELL="${OPTARG}";;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		LOGIN="${1}"
	fi
	OLDLOGINSHELL="`ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" "loginShell"`"
	if [ -z "${LOGINSHELL}" ]; then
		msg="Changing the login shell for ${LOGIN}\nEnter the new value, or press return for the default\n\tLogin Shell [${OLDLOGINSHELL}]: "
		grabinteractiveinput "${msg}" LOGINSHELL
		[ -z "${LOGINSHELL}" ] && LOGINSHELL="${OLDLOGINSHELL}"
	fi

	# recursive behaviour is nice...
	# But we only do the call if they are changing the shell
	[ "${OLDLOGINSHELL}" != "${LOGINSHELL}" ] && usermod -s "${LOGINSHELL}" "${LOGIN}"
}

chfn() {
	# TODO
	[ -z "${modulename}" ] && modulename="chfn"
	while getopts "f:h:o:r:w:" OPTION; do
		case "${OPTION}" in
			f) FULLNAME="${OPTARG}";;
			h) HOMEPHONE="${OPTARG}";;
			o) OTHER="${OPTARG}";;
			r) ROOMNUMBER="${OPTARG}";;
			w) WORKPHONE="${OPTARG}";;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		LOGIN="${1}"
	fi

	[ -n "${HOMEPH}" ] && append ""
	#FULLNAME="$(echo ${COMMENT} | cut -d, -f1)"
	#ROOMNUMBER="$(echo ${COMMENT} | cut -d, -f2)"
	#WORKPHONE="$(echo ${COMMENT} | cut -d, -f3)"
	#HOMEPHONE="$(echo ${COMMENT} | cut -d, -f4)"
	
	if [ -n "${FULLNAME}" ]; then
		FIRSTNAME="${FULLNAME// *}"
		SURNAME="${FULLNAME##* }"
		CN="${FIRSTNAME}"

	fi
	[ -n "${SURNAME}" ] && append_attrib_replace sn "${SURNAME}"
	[ -n "${FIRSTNAME}" ] && append_attrib_replace givenName "${FIRSTNAME}"
	[ -n "${FULLNAME}" ] && append_attrib_replace displayName "${FULLNAME}"
	[ -n "${ROOMNUMBER}" ] && append_attrib_replace roomNumber "${ROOMNUMBER}"
	[ -n "${HOMEPHONE}" ] && append_attrib_replace homePhone "${HOMEPHONE}"
	[ -n "${WORKPHONE}" ] && append_attrib_replace telephoneNumber "${WORKPHONE}"
	append "gecos: ${COMMENT}"
	append "\n\n"

	echo "Not done yet!"
	exit 99
}

chage() {
	# TODO
	LISTONLY="0"
	[ -z "${modulename}" ] && modulename="chsh"
	while getopts "lm:M:W:I:E:d:" OPTION; do
		case "${OPTION}" in
			l) LISTONLY="1";;
			m) MINDAYS="${OPTION}";;
			M) MAXDAYS="${OPTION}";;
			W) WARNDAYS="${OPTION}";;
			I) INACTIVEDAYS="${OPTION}";;
			E) ACCOUNTEXPIRY="${OPTION}";;
			d) LASTCHANGE="${OPTION}";;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		LOGIN="${1}"
	fi
	ALLOWED=0
	[ "x${LISTONLY}" == 'x1' -a `whoami` == "${LOGIN}" ] && ALLOWED=1
	[ `whoami` == 'root' ] && ALLOWED=1
	if [ ${ALLOWED} -ne 1 ]; then
		#You must be root to change password aging information, or view it"
		#for any user other than yourself."
		echo "${modulename}: permission denied"
		exit 1
	fi
	search_user "uid" "${LOGIN}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: unknown user: ${LOGIN}"
		exit 1
	fi
	if [ "x${LISTONLY}" == 'x1' ]; then
		MINDAYS=$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" shadowMin)
		MAXDAYS=$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" shadowMax)
		WARNDAYS=$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" shadowWarning)
		INACTIVEDAYS=$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" shadowInactive)
		ACCOUNTEXPIRY=$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" shadowExpire)
		LASTCHANGE=$(ldap_search_getattr "${USERBASE}" "uid=${LOGIN}" shadowLastChange)

		echo -e "Minimum:\t${MINDAYS}"
		echo -e "Maximum:\t${MAXDAYS}"
		echo -e "Warning:\t${WARNDAYS}"
		echo -e "Inactive:\t${INACTIVEDAYS}"
		#echo -e "Last Change:\t${LASTCHANGE}" # raw
		echo -e "Last Change:\t$(days_to_date ${LASTCHANGE} +'%b %d, %Y')"
		if [ ${LASTCHANGE} -le 0 -o ${MAXDAYS} -ge 10000 -o ${MAXDAYS} -le 0 ]; then
			PASSWORDEXPIRY_STRING="Never"
		else
			PASSWORDEXPIRY_STRING="$(days_to_date $((${LASTCHANGE} + ${MAXDAYS})) +'%b %d, %Y')"
		fi
		echo -e "Password Expires:\t${PASSWORDEXPIRY_STRING}"
		if [ ${LASTCHANGE} -le 0 -o ${MAXDAYS} -ge 10000 -o ${MAXDAYS} -le 0 -o ${INACTIVEDAYS} -le 0 ]; then
			PASSWORDINACTIVE_STRING="Never"
		else
			PASSWORDINACTIVE_STRING="$(days_to_date $((${LASTCHANGE} + ${MAXDAYS} + ${INACTIVEDAYS})) +'%b %d, %Y')"
		fi
		echo -e "Password Inactive:\t${PASSWORDINACTIVE_STRING}"
		if [ ${ACCOUNTEXPIRY} -le 0  ]; then
			ACCOUNTEXPIRY_STRING="Never"
		else
			ACCOUNTEXPIRY_STRING="$(days_to_date ${ACCOUNTEXPIRY} +'%b %d, %Y')"
		fi
		echo -e "Account Expires:\t${ACCOUNTEXPIRY_STRING}"
# shadowLastChange - The number of days (since January 1, 1970) since the password was last changed.
# shadowMin - The number of days before password may be changed (0 indicates it may be changed at any time)
# shadowMax - The number of days after which password must be changed (99999 indicates user can keep his or her password unchanged for many, many years)
# shadowWarning - The number of days to warn user of an expiring password (7 for a full week)
# shadowInactive - The number of days after password expires that account is disabled
# shadowExpire - The number of days since January 1, 1970 that an account has been disabled
# shadowFlag - A reserved field for possible future use
		exit 0
	fi
	# TODO
	echo "Not done yet! "
	exit 99
}


gpasswd() {
	# TODO
	[ -z "${modulename}" ] && modulename="gpasswd"
	PASSWD_SET=0
	MEMBERS_ADD=''
	MEMBERS_DELETE=''
	MEMBERS_SET=''
	while getopts "rRa:d:A:M:" OPTION; do
		case "${OPTION}" in
			r) if [ -n "$MODE_PASSWD" ]; then print_usage ${modulename} ; exit 1 ; fi
				MODE_PASSWD=1 PASSWD_SET=1 PASSWD='' ; echo TODO! ; exit 99 ;;
			R) if [ -n "$MODE_PASSWD" ]; then print_usage ${modulename} ; exit 1 ; fi
				MODE_PASSWD=1 PASSWD_SET=1 PASSWD="!" ; echo TODO! ; exit 99 ;;
			a) MODE_MEMBER=1 MEMBERS_ADD="${OPTARG//,/ }";;
			d) MODE_MEMBER=1 MEMBERS_DELETE="${OPTARG//,/ }";;
			M) MODE_MEMBER=1 MEMBERS_SET="${OPTARG//,/ }";;
			A) MODE_MEMBER=1 ADMINS="${OPTARG//,/ }" ; gpasswd_admin_error ; exit 99 ;;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		GROUP="${1}"
	fi
	# cannot set and add/delete together
	if [ -n "$MEMBERS_SET" ]; then
		if [ -n "$MEMBERS_ADD" -o -n "$MEMBERS_DELETE" ]; then 
			print_usage ${modulename} 
			exit 2
		fi
	fi
	
	
	COMMAND_DN="dn: cn=${GROUP},${GROUPBASE}"
	append "${COMMAND_DN}"
	append "changetype: modify"

	# TODO: -R/-r/passwd/ADMIN

	MEMBERS_CURRENT="$(ldap_search_getattr ${GROUPBASE} "cn=${GROUP}" memberUid)"
	#echo MC:$MEMBERS_CURRENT
	#echo MS:$MEMBERS_SET
	# if we are doing SET mode, then we do it differently
	if [ -n "${MEMBERS_SET}" ]; then
		# MEMBERS_DELETE = MEMBERS_CURRENT - MEMBERS_SET
		MEMBERS_DELETE="$(set_complement "${MEMBERS_CURRENT}" "${MEMBERS_SET}")"
		# MEMBERS_ADD = MEMBERS_SET - MEMBERS_CURRENT
		MEMBERS_ADD="$(set_complement "${MEMBERS_SET}" "${MEMBERS_CURRENT}")"
	else
		# select members to add that aren't already there only to avoid LDAP errors
		# remove all new members that we would delete as well
		MEMBERS_ADD="$(set_complement "${MEMBERS_ADD}" "${MEMBERS_CURRENT} ${MEMBERS_DELETE}")"
		# select members to delete so we don't get LDAP errors
		MEMBERS_DELETE="$(set_intersection "${MEMBERS_CURRENT}" "${MEMBERS_DELETE}")"
	fi
	#echo MD:$MEMBERS_DELETE
	#echo MA:$MEMBERS_ADD
		
	if [ -n "${MEMBERS_ADD}" ]; then
		for i in ${MEMBERS_ADD}; do
			append "add: memberUid"
			append "memberUid: ${i}"
			append "-"
		done
	fi
	if [ -n "${MEMBERS_DELETE}" ]; then
		for i in ${MEMBERS_DELETE}; do
			append "delete: memberUid"
			append "memberUid: ${i}"
			append "-"
		done
	fi

	# check if we should do anything
	[ "${COMMAND}" = "${COMMAND_DN}" ] && unset COMMAND
}

gpasswd_admin_error() {
	echo "So you want to set a group administrator..."
	echo "Unfortuntely you won't be able to do that"
	echo "As there is NO place for it in any schema"
	echo "Please contact me (Robin) if you do have a"
	echo "public schema that supports it."
}

smbhostadd() {
	[ -z "${modulename}" ] && modulename="smbhostadd"
	while getopts "u:" OPTION; do
		case "${OPTION}" in
			r) HOSTRID="${OPTARG}";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename} 
		exit 2
	else
		NAME="${1}"
	fi

	if [ -n "${HOSTRID}" ]; then
		echo "${HOSTRID}" | grep -qs "^[[:digit:]]*$"
		if [ "$?" -ne 0 ]; then
			echo "${modulename}: Invalid numeric argument \"${HOSTRID}\""
			exit 3
		fi
		search_smbhost "sambaSID" "${SAMBADOMAINSID}-${HOSTRID}"
		if [ "$?" -eq 0 ]; then
			echo "${modulename}: uid ${HOSTRID} is not unique"
			exit 4
		fi
	else
		HOSTRID="${SAMBAHOSTRIDMIN}"
		while [ "${HOSTRID}" -le "${SAMBAHOSTRIDMAX}" ]; do
			search_smbhost "sambaSID" "${SAMBADOMAINSID}-${HOSTRID}"
			[ "$?" -ne 0 ] && break
			let HOSTRID="${HOSTRID} + 1"
		done
	fi

	append "dn: uid=${NAME}\$,${SAMBAHOSTBASE}"
	append "changetype: add"
	append "objectClass: sambaSidEntry"
	append "objectClass: sambaSamAccount"
	append "uid: ${NAME}\$"
	append "sambaSID: ${SAMBADOMAINSID}-${HOSTRID}"
	let CANCHANGE="$(date -u +%s)"
	append "sambaPwdCanChange: ${CANCHANGE}"
	append "sambaPwdLastSet: ${CANCHANGE}"
	let MUSTCHANGE="${CANCHANGE} + 1814400"
	append "sambaPwdMustChange: ${MUSTCHANGE}"
	append "sambaAcctFlags: [W          ]"
	append "sambaLMPassword: $(${MKPASSWD} -l ${NAME}\$)"
	append "sambaNTPassword: $(${MKPASSWD} -n ${NAME}\$)"
	append "\n\n"

	runmodify
}

smbhostdel () {
	[ -z "${modulename}" ] && modulename="smbhostdel"
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		NAME="${1}"
	fi
	search_smbhost "uid" "${NAME}\$"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Machine \"${NAME}\" does not exist"
		exit 6
	fi
	append "dn: uid=${NAME}\$,${SAMBAHOSTBASE}"
	append "changetype: delete"
	append "\n"
	runmodify
}

hostadd () {
	[ -z "${modulename}" ] && modulename="hostadd"
	while getopts "e:i:a:" OPTION; do
		case "${OPTION}" in
			e) ETHERS="${OPTARG}";;
			i) IPS="${OPTARG}";;
			a) ALIASES="${OPTARG}";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		NAME="${1}"
	fi
	search_host "cn" "${NAME}"
	if [ "$?" -eq 0 ]; then
		echo "${modulename}: User \"${NAME}\" exists"
		exit 9
	fi

	# Setup the commands
	append "dn: cn=${NAME},${HOSTBASE}"
	append "changetype: add"
	append "objectClass: top"
	append "objectClass: device"
	append "cn: ${NAME}"

	if [ -n "${ETHERS}" ]; then
		ETHERS="${ETHERS//,/ }"
		append "objectClass: ieee802device"
		for i in ${ETHERS}; do
			append "macAddress: ${i}"
		done
	fi
	if [ -n "${IPS}" ]; then
		IPS="${IPS//,/ }"
		append "objectClass: ipHost"
		for i in ${IPS}; do
			append "ipHostNumber: ${i}"
		done
	fi
	if [ -n "${ALIASES}" ]; then
		ALIASES="${ALIASES//,/ }"
		for i in ${ALIASES}; do
			append "cn: ${i}"
		done
	fi

	append "\n\n"

	runmodify
}

hostdel () {
	[ -z "${modulename}" ] && modulename="hostdel"
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		NAME="${1}"
	fi
	search_host "cn" "${NAME}\$"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Host \"${NAME}\" does not exist"
		exit 6
	fi
	append "dn: cn=${NAME}\$,${HOSTBASE}"
	append "changetype: delete"
	append "\n"

	runmodify
}

hostmod () {
	[ -z "${modulename}" ] && modulename="hostmod"
	if [ "${#}" -le 1 ]; then
		echo "${modulename}: No flags given"
		exit 2
	fi
	while getopts "e:E:i:I:a:A:n:" OPTION; do
		case "${OPTION}" in
			e) ADDETHERS="${OPTARG} ${ADDETHERS}";;
			E) DELETHERS="${OPTARG} ${DELETHERS}";;
			i) ADDIPS="${OPTARG} ${ADDIPS}";;
			I) DELIPS="${OPTARG} ${DELIPS}";;
			a) ADDALIASES="${OPTARG} ${ADDALIASES}";;
			A) DELALIASES="${OPTARG} ${DELALIASES}";;
			n) NEWNAME="${OPTARG}";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		NAME="${1}"
	fi
	search_host "cn" "${NAME}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Host \"${NAME}\" does not exist"
		exit 6
	fi
	COMMAND_DN="dn: cn=${NAME},${HOSTBASE}"
	append "${COMMAND_DN}"
	append "changetype: modify"
	if [ -n "${ADDETHERS}" ]; then
		ADDETHERS="${ADDETHERS//,/ }"
		search_attr "${HOSTBASE}" "(cn=${NAME})" "objectClass: ieee802device"
		if [ "$?" -eq 1 ]; then
			append "add: objectClass"
			append "objectClass: ieee802device"
			append "-"
		fi
		# TODO: use correct set of ethers to avoid ldap error
		for i in ${ADDETHERS}; do
			append "add: macAddress"
			append "macAddress: ${i}"
			append "-"
		done
	fi
	# TODO: use correct set of ethers to avoid ldap error
	if [ -n "${DELETHERS}" ]; then
		DELETHERS="${DELETHERS//,/ }"
		for i in ${DELETHERS}; do
			append "delete: macAddress"
			append "macAddress: ${i}"
			append "-"
		done
	fi
	if [ -n "${ADDIPS}" ]; then
		ADDIPS="${ADDIPS//,/ }"
		search_attr "${HOSTBASE}" "(cn=${NAME})" "objectClass: ipHost"
		if [ "$?" -eq 1 ]; then
			append "add: objectClass"
			append "objectClass: ipHost"
			append "-"
		fi
		# TODO: use correct set of ip to avoid ldap error
		for i in ${ADDIPS}; do
			append "add: ipHostNumber"
			append "ipHostNumber: ${i}"
			append "-"
		done
	fi
	# TODO: use correct set of ip to avoid ldap error
	if [ -n "${DELIPS}" ]; then
		DELIPS="${DELIPS//,/ }"
		for i in ${DELIPS}; do
			append "delete: ipHostNumber"
			append "ipHostNumber: ${i}"
			append "-"
		done
	fi
	# TODO: use correct set of aliases to avoid ldap error
	if [ -n "${ADDALIASES}" ]; then
		ADDALIASES="${ADDALIASES//,/ }"
		for i in ${ADDALIASES}; do
			append "add: cn"
			append "cn: ${i}"
			append "-"
		done
	fi
	# TODO: use correct set of aliases to avoid ldap error
	if [ -n "${DELALIASES}" ]; then
		DELALIASES="${DELALIASES//,/ }"
		for i in ${DELALIASES}; do
			append "delete: cn"
			append "cn: ${i}"
			append "-"
		done
	fi
	[ "${COMMAND}" = "${COMMAND_DN}" ] && unset COMMAND
	[ -n "${NEWNAME}" ] && append "dn: cn=${NAME},${HOSTBASE}\nchangetype: modrdn\nnewrdn: cn=${NEWNAME}\n"

	#echo "${COMMAND}"
	runmodify
}

cvsadd() {
	# TODO
	[ -z "${modulename}" ] && modulename="hostadd"
	while getopts "m:" OPTION; do
		case "${OPTION}" in
			m) MEMBERS="${OPTARG}";;
			*) print_usage ${modulename} ; exit 1;;
		esac
	done
	shift $((${OPTIND} - 1))
	if [ "${#}" -ne 1 ]; then
		print_usage 
		exit 2
	else
		NAME="${1}"
	fi
	search_group "cn" "${NAME}"
	if [ "$?" -eq 0 ]; then
		echo "${modulename}: Group \"${NAME}\" exists"
		exit 9
	fi

	# Setup the commands
	append "dn: cn=${NAME},${GROUPBASE}"
	append "changetype: add"
	append "objectClass: top"
	append "objectClass: device"
	append "cn: ${NAME}"

	if [ -n "${MEMBERS}" ]; then
		MEMBERS="${MEMBERS//,/ }"
		for i in ${MEMBERS}; do
			append "memberUid: ${i}"
		done
	fi
}

case "${1}" in
	useradd|usermod|userdel|groupadd|groupmod|groupdel|chsh|chfn|chage|gpasswd|smbhostadd|smbhostdel|hostadd|hostdel|hostmod|selftest)
		ACTION="${1}"
		shift 1
		mkpasswd_resolve
		${ACTION} "$@"
		exit 0
		;;
		# host - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/hosts.htm#seg3b0sara
		# network - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/networks_NFS.htm#idx232
		# protocol - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/protocols.htm#idx546
		# service - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/services.htm#idx574
		# rpc - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/rpc.htm#idx286
		# ether - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/ethers.htm#idx111
		# netmask - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/netmasks.htm#idx226
		# netgroup - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/netgroup.htm#xqr310mart
		# bootparam - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/bootparams.htm#idx32
		# automount
		# aliases - http://publib16.boulder.ibm.com/pseries/en_US/files/aixfiles/aliases.htm#idx12
	_revision)
		echo ${REVISION}
		exit 0
		;;
	_date)
		echo ${DATE}
		exit 0
		;;
	version|--version)
		print_version
		exit 0
		;;
	help|--help)
		print_usage _all
		exit 0
		;;
	*)
		print_usage _all
		exit 1
		;;
esac

exit 0

# vim: ts=4 sts=4 noexpandtab sw=4 ft=sh:
