#!@FALSE@
# $Header: /code/convert/cvsroot/infrastructure/diradm/src/Attic/diradm.common.sh,v 1.1 2005/01/09 07:01:49 robbat2 Exp $
# vim: ts=4 sts=4 noexpandtab sw=4 ft=sh syntax=sh:
# This contains all of the common functions.

grabinteractiveinput() {
	msg="${1}"
	setting="${2}"
	echo -en "${msg}"
	read userinput
	userinput="`echo "${userinput}" | ${SED} -re 's/^[[:space:]]*//g;s/[[:space:]]*$//g;'`"
	eval ${setting}="${userinput}"
}

# Call me nuts, I just wrote set functions in shell!
# -Robin
set_union() {
	a="$1"
	b="$2"
	t="$a"
	for i in $b; do
		echo "${a}" | ${GREP} -wqs "${i}"
		# if not there, add
		[ "$?" -ne 0 ] && t="${t} ${i}"
	done
	echo "$t"
}

set_intersection() {
	a="$1"
	b="$2"
	t=''
	if [ -z "$a" -o -z "$b" ]; then
		t=''
	else
		for i in $a; do
			echo "${b}" | ${GREP} -wqs "${i}"
			# if there, add
			[ "$?" -eq 0 ] && t="${t} ${i}"
		done
	fi
	echo "$t"
}
set_complement() {
	a="$1"
	b="$2"
	t=''
	# check for special cases
	if [ -z "$a" ]; then
		t="$b"
	elif [ -z "$b" ]; then
		t=''
	# base case
	else
		for i in $a; do
			echo "${b}" | ${GREP} -wqs "${i}"
			# if not there, add
			[ "$?" -ne 0 ] && t="${t} ${i}"
		done
	fi
	echo "$t"
}

# eg: 
# ldap_search_getattr "${GROUP_BASEDN}" "gidNumber=100" cn
# (returns 'users' on systems with that initial data in LDAP)
ldap_search_getattr() {
	basedn="${1}"
	search="${2}"
	attr="${3}"
	regex="^${attr}:{1,2} "
	[ -n "$DEBUG" ] && echo ${LDAPSEARCH} -b "${basedn}" "${search}" ${attr}
	${LDAPSEARCH} -b "${basedn}" "${search}" ${attr} | ${EGREP} "${regex}" | ${SED} -re "s/${regex}//"
}

ldap_base64_decode() {
	echo "$*" | ${PERL} -MMIME::Base64 -e 'print(decode_base64(<STDIN>));'
}

search_attr() {
	[ -n "$DEBUG" ] && echo ${LDAPSEARCH} -b "${1}" "${2}"
	${LDAPSEARCH} -b "${1}" "${2}" | ${GREP} -qs "^${3}$"
	return "$?"
}

search_smbhost() {
	search_attr "${SAMBAHOST_BASEDN}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}

search_host() {
	search_attr "${HOST_BASEDN}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}
search_user() {
	search_attr "${USER_BASEDN}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}

search_group() {
	search_attr "${GROUP_BASEDN}" "${1}=${2}" "${1}: ${2}"
	return "$?"
}

append() {
	[ "x${*}" != "x" ] && COMMAND="${COMMAND}\n${*}"
}

append_attrib_replace() {
	local attrib="$1"
	shift
	append "replace: ${attrib}\n${attrib}: ${*}\n-"

}
append_attrib_add() {
	local attrib="$1"
	shift
	append "add: ${attrib}\n${attrib}: ${*}\n-"
}
append_attrib_delete() {
	local attrib="$1"
	shift
	append "delete: ${attrib}\n${attrib}: ${*}\n-"
}

runmodify() {
if [ -n "${DEBUG}" ]; then
	echo LDAP Modify:
	echo -------
	[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | ${UNIQ}
	echo -------
fi

[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | ${LDAPMODIFY} > /dev/null
}

runadd() {
if [ -n "${DEBUG}" ]; then
	echo LDAP Add:
	echo -------
	[ -n "${COMMAND}" ] && echo -e "${COMMAND}" | ${UNIQ}
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
	#${DATE} -u -d "Jan $((${D}+1)), 1970" ${OPT}
	${DATE} -u -d "00:00:00 1970-01-01 UTC +$D days" "${*}"
}

# Does the reverse of days_to_date
# expects a date
# returns a number of days since Jan 1, 1970
date_to_days() {
	local UNIXTIMESTAMP="$(${DATE} -u +%s -d "${*}")"
	echo $((${UNIXTIMESTAMP}/(3600*24)))
}

daysnow() {
	date_to_days `${DATE} -R -u`
}
