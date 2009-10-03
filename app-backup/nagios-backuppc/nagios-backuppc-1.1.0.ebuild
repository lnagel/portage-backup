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

src_unpack() {
	unpack ${A}
	cd "${S}"
}

src_prepare() {
	sed -i "s+NAGIOS_LIB+/usr/lib/nagios/plugins+" check_backuppc
	sed -i "s+BACKUPPC_LIB+/usr/lib/BackupPC+" check_backuppc
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
	insinto /usr/lib/nagios/plugins
	doins check_backuppc
}
