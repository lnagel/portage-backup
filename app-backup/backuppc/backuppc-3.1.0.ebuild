# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="1"

inherit eutils webapp

MY_P="BackupPC-${PV}"

DESCRIPTION="A high-performancee system for backing up computers to a server's disk."
HOMEPAGE="http://backuppc.sourceforge.net"
SRC_URI="mirror://sourceforge/${PN}/${MY_P}.tar.gz"

LICENSE="GPL-2"
KEYWORDS="~amd64 x86"

IUSE="doc +rsync samba"

DEPEND="dev-lang/perl
    app-admin/apache-tools
    app-admin/makepasswd"
RDEPEND="${DEPEND}
	perl-core/IO-Compress
	dev-perl/Archive-Zip
	>=app-arch/tar-1.13.20
	app-arch/par2cmdline
	app-arch/gzip
	app-arch/bzip2
	virtual/mta
	www-servers/apache
	rsync? ( >=dev-perl/File-RsyncP-0.68 )
	rss? ( dev-perl/XML-RSS )
	samba? ( net-fs/samba )"

WEBAPP_MANUAL_SLOT="yes"
SLOT="0"

S=${WORKDIR}/${MY_P}
DATADIR="/var/lib/backuppc"

pkg_setup() {
	webapp_pkg_setup
	enewgroup backuppc
	enewuser backuppc -1 -1 /dev/null backuppc
}

src_unpack() {
	unpack ${A}
	cd "${S}"
	sed -i -e "1s_/bin/perl_/usr/bin/perl_"  configure.pl
}

src_test() {
	einfo "Can not test"
}

src_install() {
	webapp_src_preinst

	local myconf
	myconf=""
	if use samba ; then
		myconf="--bin-path smbclient=$(type -p smbclient)"
		myconf="${myconf} --bin-path nmblookup=$(type -p nmblookup)"
	fi

	einfo ${MY_HTDOCSDIR}

	./configure.pl \
		--batch \
		--bin-path perl=$(type -p perl) \
		--bin-path tar=$(type -p tar) \
		--bin-path rsync=$(type -p rsync) \
		--bin-path ping=$(type -p ping) \
		--bin-path df=$(type -p df) \
		--bin-path ssh=$(type -p ssh) \
		--bin-path sendmail=$(type -p sendmail) \
		--bin-path hostname=$(type -p hostname) \
		--bin-path gzip=$(type -p gzip) \
		--bin-path bzip2=$(type -p bzip2) \
		--install-dir /usr \
		--data-dir ${DATADIR} \
		--hostname $(hostname) \
		--uid-ignore \
		--dest-dir "${D%/}" \
		--html-dir ${MY_HTDOCSDIR}/image \
		--html-dir-url /image \
		--cgi-dir ${MY_HTDOCSDIR} \
		--fhs \
		${myconf} || die "failed the configure.pl script"

	pod2man \
		--section=8 \
		--center="BackupPC manual" \
		"${S}"/doc/BackupPC.pod backuppc.8 || die "failed to generate man page"

	doman backuppc.8

	diropts -m 750
	keepdir /var/log/BackupPC
	fowners backuppc:backuppc /var/log/BackupPC
	keepdir ${DATADIR}
	fowners backuppc:backuppc ${DATADIR}

	diropts -m 755
	keepdir /etc/BackupPC
	fowners backuppc:backuppc /etc/BackupPC

	newinitd "${S}"/init.d/gentoo-backuppc backuppc
	newconfd "${S}"/init.d/gentoo-backuppc.conf backuppc
	
	ebegin "Setting up an apache instance for backuppc"

	cp "${FILESDIR}/httpd.conf" "${WORKDIR}/httpd.conf"
	cd "$WORKDIR"
	sed -i -e "s+HTDOCSDIR+${MY_HTDOCSDIR}+g" "${WORKDIR}/httpd.conf"
	sed -i -e "s+AUTHFILE+/etc/BackupPC/users.htpasswd+g" "${WORKDIR}/httpd.conf"

	if [[ ! -f "${ROOT}etc/BackupPC/users.htpasswd" ]]; then
		adminuser="backuppc"
		adminpass=$( makepasswd --chars=12 )
		htpasswd -bc "${WORKDIR}/users.htpasswd" $adminuser $adminpass
	fi
	
	if [ -e /etc/init.d/apache2 ]; then
		newconfd "${FILESDIR}/apache2-backuppc.conf" apache2-backuppc
		newinitd /etc/init.d/apache2 apache2-backuppc
	else
		newconfd "${FILESDIR}/apache2-backuppc.conf" apache2-backuppc
		newinitd "${FILESDIR}/apache2-backuppc.init" apache2-backuppc
	fi

	insopts -m 644
	insinto /etc/BackupPC

	if [[ -f "${WORKDIR}/users.htpasswd" ]]; then
		doins "${WORKDIR}/users.htpasswd"
	fi

	doins "${WORKDIR}/httpd.conf"
	eend $?

	webapp_src_install || die "webapp_src_install"
}

pkg_postinst() {
	# This is disabled since BackupPC doesn't need it
	# webapp_pkg_postinst 

	elog ""
	elog "Please read the documentation"
	elog "you can start the server by typing:"
	elog "/etc/init.d/backuppc start && /etc/init.d/apache2-backuppc start"
	elog "afterwards you will be able to reach the web-frontend under the following address:"
	elog "https://your-servers-ip-address/BackupPC_Admin"
	elog ""

	if [[ -n "$adminpass" ]]; then
		elog "Created admin user $adminuser with password $adminpass"
		elog ""
	fi
}
