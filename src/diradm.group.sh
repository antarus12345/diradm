#!@FALSE@
# $Header: /code/convert/cvsroot/infrastructure/diradm/src/Attic/diradm.group.sh,v 1.1 2005/01/09 07:01:49 robbat2 Exp $
# vim: ts=4 sts=4 noexpandtab sw=4 ft=sh syntax=sh:
# This contains all of the functions specific to the group sub-system.

groupadd() {
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
	echo "${CN}" | ${GREP} -qs "^[[:alnum:]]*$"
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
		echo "${GIDNUMBER}" | ${GREP} -qs "^[[:digit:]]*$"
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
	append "dn: cn=${CN},${GROUP_BASEDN}"
	append "changetype: add"
	append "objectClass: top"
	append "objectClass: posixGroup"
	append "cn: ${CN}"
	append "gidNumber: ${GIDNUMBER}"
	append "\n\n"
	runmodify
}

groupmod() {
	[ -z "${modulename}" ] && modulename="groupmod"
	if [ "${#}" -le 1 ]; then
		print_usage ${modulename}
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
		echo "${GIDNUMBER}" | ${GREP} -qs "^[[:digit:]]*$"
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
		echo "${NEWCN}" | ${GREP} -qs "^[[:alnum:]]*$"
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
	[ -n "${GIDNUMBER}" ] && append "dn: cn=${CN},${GROUP_BASEDN}\nreplace: gidNumber\ngidNumber: ${GIDNUMBER}\n"
	[ -n "${NEWCN}" ] && append "dn: cn=${CN},${GROUP_BASEDN}\nchangetype: modrdn\nnewrdn: cn=${NEWCN}"
	runmodify
}

groupdel() {
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
	rundelete "cn=${CN},${GROUP_BASEDN}" 
}

gpasswd() {
	# TODO: set admin
	# TODO: password mode
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
	
	
	COMMAND_DN="dn: cn=${GROUP},${GROUP_BASEDN}"
	append "${COMMAND_DN}"
	append "changetype: modify"

	# TODO: -R/-r/passwd/ADMIN

	MEMBERS_CURRENT="$(ldap_search_getattr ${GROUP_BASEDN} "cn=${GROUP}" memberUid)"
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
	runmodify
}

gpasswd_admin_error() {
	echo "So you want to set a group administrator..."
	echo "Unfortuntely you won't be able to do that"
	echo "As there is NO place for it in any schema"
	echo "Please contact me (Robin) if you do have a"
	echo "public schema that supports it."
}
