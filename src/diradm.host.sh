#!@FALSE@
# $Header: /code/convert/cvsroot/infrastructure/diradm/src/Attic/diradm.host.sh,v 1.1 2005/01/09 07:01:49 robbat2 Exp $
# vim: ts=4 sts=4 noexpandtab sw=4 ft=sh syntax=sh:
# This contains all of the functions specific to the host sub-system.

hostadd() {
	# TODO: cleanup
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
	append "dn: cn=${NAME},${HOST_BASEDN}"
	append "changetype: add"
	append "objectClass: top"
	append "objectClass: device"
	append "cn: ${NAME}"

	if [ -n "${ETHERS}" ]; then
		append "objectClass: ieee802device"
		for i in ${ETHERS//, }; do
			append "macAddress: ${i}"
		done
	fi
	if [ -n "${IPS}" ]; then
		append "objectClass: ipHost"
		for i in ${IPS//, /}; do
			append "ipHostNumber: ${i}"
		done
	fi
	if [ -n "${ALIASES}" ]; then
		for i in ${ALIASES//,/ }; do
			append "cn: ${i}"
		done
	fi

	append "\n\n"

	runmodify
}

hostdel() {
	# TODO: cleanup
	[ -z "${modulename}" ] && modulename="hostdel"
	if [ "${#}" -ne 1 ]; then
		print_usage ${modulename}
		exit 2
	else
		NAME="${1}"
	fi
	NAME_DOLLAR="${NAME}\$"
	search_host "cn" "${NAME_DOLLAR}"
	if [ "$?" -ne 0 ]; then
		echo "${modulename}: Host \"${NAME}\" does not exist"
		exit 6
	fi
	append "dn: cn=${NAME_DOLLAR},${HOST_BASEDN}"
	append "changetype: delete"
	append "\n"

	runmodify
}

hostmod() {
	# TODO: cleanup
	[ -z "${modulename}" ] && modulename="hostmod"
	if [ "${#}" -le 1 ]; then
		print_usage ${modulename}
		echo "${modulename}: No flags given"
		exit 2
	fi
	while getopts "e:E:i:I:a:A:n:" OPTION; do
		case "${OPTION}" in
			e) ETHERS_ADD="${OPTARG//,/ } ${ETHERS_ADD}";;
			E) ETHERS_DELETE="${OPTARG//,/ } ${ETHERS_DELETE}";;
			i) IPS_ADD="${OPTARG//,/ } ${IPS_ADD}";;
			I) IPS_DELETE="${OPTARG//,/ } ${IPS_DELETE}";;
			a) ALIASES_ADD="${OPTARG//,/ } ${ALIASES_ADD}";;
			A) ALIASES_DELETE="${OPTARG//,/ } ${ALIASES_DELETE}";;
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
	COMMAND_DN="dn: cn=${NAME},${HOST_BASEDN}"
	append "${COMMAND_DN}"
	append "changetype: modify"
	ETHERS_CURRENT="$(ldap_search_getattr ${HOST_BASEDN} "cn=${NAME}" macAddress)"
	IPS_CURRENT="$(ldap_search_getattr ${HOST_BASEDN} "cn=${NAME}" ipHostNumber)"
	ALIASES_CURRENT="$(ldap_search_getattr ${HOST_BASEDN} "cn=${NAME}" cn)"
	# build correct data
	ETHERS_ADD="$(set_complement "${ETHERS_ADD}" "${ETHERS_CURRENT} ${ETHERS_DELETE}")"
	ETHERS_DELETE=$(set_intersection "${ETHERS_DELETE}" "${ETHERS_CURRENT}")
	# build correct data
	IPS_ADD="$(set_complement "${IPS_ADD}" "${IPS_CURRENT} ${IPS_DELETE}")"
	IPS_DELETE=$(set_intersection "${IPS_DELETE}" "${IPS_CURRENT}")
	# build correct data
	ALIASES_ADD="$(set_complement "${ALIASES_ADD}" "${ALIASES_CURRENT} ${ALIASES_DELETE}")"
	ALIASES_DELETE=$(set_intersection "${ALIASES_DELETE}" "${ALIASES_CURRENT}")
	if [ -n "$(set_intersection "${ALIASES_DELETE}" "${NAME}")" ]; then
		echo "${modulename}: Cannot delete primary name of ${NAME}! Use rename instead."
		print_usage ${modulename}
		exit 6
	fi

	if [ -n "${ETHERS_ADD}" ]; then
		search_attr "${HOST_BASEDN}" "(cn=${NAME})" "objectClass: ieee802device" \
			|| append_attrib_add objectClass "ieee802device"
		for i in ${ETHERS_ADD}; do
			append_attrib_add macAddress "${i}"
		done
	fi
	if [ -n "${ETHERS_DELETE}" ]; then
		for i in ${ETHERS_DELETE}; do
			append_attrib_delete macAddress "${i}"
		done
	fi
	if [ -n "${IPS_ADD}" ]; then
		search_attr "${HOST_BASEDN}" "(cn=${NAME})" "objectClass: ipHost" \
			|| append_attrib_add objectClass "ipHost"
		for i in ${IPS_ADD}; do
			append_attrib_add ipHostNumber "${i}"
		done
	fi
	if [ -n "${IPS_DELETE}" ]; then
		for i in ${IPS_DELETE}; do
			append_attrib_delete ipHostNumber "${i}"
		done
	fi
	if [ -n "${ALIASES_ADD}" ]; then
		for i in ${ALIASES_ADD}; do
			append_attrib_add cn "${i}"
		done
	fi
	if [ -n "${ALIASES_DELETE}" ]; then
		for i in ${ALIASES_DELETE}; do
			append_attrib_delete cn "${i}"
		done
	fi
	[ "${COMMAND}" = "${COMMAND_DN}" ] && unset COMMAND
	[ -n "${NEWNAME}" ] && append "dn: cn=${NAME},${HOST_BASEDN}\nchangetype: modrdn\nnewrdn: cn=${NEWNAME}\n"

	#echo "${COMMAND}"
	runmodify
}
