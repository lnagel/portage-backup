# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

inherit eutils

MY_P="check_backuppc-${PV}"

DESCRIPTION="A Nagios plugin for monitoring the state of BackupPC."
HOMEPAGE="http://n-backuppc.sourceforge.net/"
SRC_URI="mirror://sourceforge/n-backuppc/${MY_P}.tar.gz"

LICENSE="GPL-2"
KEYWORDS="~amd64 ~x86"

IUSE=""

DEPEND="dev-lang/perl"
RDEPEND="${DEPEND}
	app-backup/backuppc
	net-analyzer/nagios-plugins"

SLOT="0"

S=${WORKDIR}/${MY_P}
PLUGINSDIR="/usr/lib/nagios/plugins"

src_unpack() {
	unpack ${A}
	cd "${S}"
}

src_prepare() {
	if [[ ! -d "$PLUGINSDIR" ]]; then
		if [[ -d "/usr/lib64/nagios/plugins" ]]; then
			PLUGINSDIR="/usr/lib64/nagios/plugins"
		fi
	fi

	sed -i "s+NAGIOS_LIB+$PLUGINSDIR+" check_backuppc
	sed -i "s+BACKUPPC_LIB+/usr/lib+" check_backuppc
}

src_compile() {
	true
}

src_test() {
	true
}

src_install() {
	doman check_backuppc.8

	insopts -m 0750 -g nagios
	insinto "$PLUGINSDIR"
	doins check_backuppc
}

pkg_postinst() {
	elog "You should probaby add backuppc to the group nagios:"
	elog "# gpasswd -a backuppc nagios"
	elog ""
	elog "Add to /etc/nagios/nrpe.cfg:"
	elog "  command[check_backuppc]=/usr/bin/sudo /bin/su -c $PLUGINSDIR/check_backuppc backuppc"
	elog ""
	elog "Add to sudoers using visudo:"
	elog "  %nagios         ALL=(ALL)       NOPASSWD: /bin/su -c $PLUGINSDIR/check_backuppc backuppc"
}
