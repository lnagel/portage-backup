# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

inherit eutils webapp

MY_P="BackupPC-${PV}"

DESCRIPTION="A high-performancee system for backing up computers to a server's disk."
HOMEPAGE="http://backuppc.sourceforge.net"
SRC_URI="mirror://sourceforge/${PN}/${MY_P}.tar.gz"

LICENSE="GPL-2"
KEYWORDS="~amd64 ~x86"

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
	www-servers/apache[suexec]
	rsync? ( >=dev-perl/File-RsyncP-0.68 )
	rss? ( dev-perl/XML-RSS )
	samba? ( net-fs/samba )"

WEBAPP_MANUAL_SLOT="yes"
SLOT="0"

S=${WORKDIR}/${MY_P}

CONFDIR="/etc/BackupPC"
DATADIR="/var/lib/backuppc"
LOGDIR="/var/log/BackupPC"

pkg_setup() {
	webapp_pkg_setup
	enewgroup backuppc
	enewuser backuppc -1 -1 /dev/null backuppc
}

src_unpack() {
	unpack ${A}
	cd "${S}"
	epatch "${FILESDIR}/fix-configure.pl.patch"
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

	## For upgrading, we need to copy in the current config file
	## Currently disabled since the configure.pl script is broken
	#if [[ -f "${CONFDIR}/config.pl" ]]; then
	#	einfo "Feeding in the current config file ${CONFDIR}/config.pl"
	#	einfo " as ${WORKDIR}/config.pl"
	#	cp "${CONFDIR}/config.pl" "${WORKDIR}/config.pl"
	#	myconf="${myconf} --config-path ${WORKDIR}/config.pl"
	#fi

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
		--config-dir ${CONFDIR} \
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

	dodir ${CONFDIR}/pc

	keepdir ${CONFDIR}
	keepdir ${CONFDIR}/pc
	keepdir ${DATADIR}/{trash,pool,pc,cpool}
	keepdir ${LOGDIR}

	newinitd "${S}"/init.d/gentoo-backuppc backuppc
	newconfd "${S}"/init.d/gentoo-backuppc.conf backuppc
	
	ebegin "Setting up an apache instance for backuppc"

	cp "${FILESDIR}/apache2-backuppc."{conf,init} "${WORKDIR}/"
	cp "${FILESDIR}/httpd.conf" "${WORKDIR}/httpd.conf"
	sed -i -e "s+HTDOCSDIR+${MY_HTDOCSDIR}+g" "${WORKDIR}/httpd.conf"
	sed -i -e "s+AUTHFILE+${CONFDIR}/users.htpasswd+g" "${WORKDIR}/httpd.conf"

	moduledir="/usr/lib/apache2/modules"

	# Check if the Apache ServerRoot is real.
	# This is sometimes broken on older amd64 systems.
	# In this case we just patch our config file appropriately.
	if [[ ! -d "/usr/lib/apache2" ]]; then 
		if [[ -d "/usr/lib64/apache2" ]]; then
			sed -i -e "s+/usr/lib/apache2+/usr/lib64/apache2+g" "${WORKDIR}/httpd.conf"
			sed -i -e "s+/usr/lib/apache2+/usr/lib64/apache2+g" "${WORKDIR}/apache2-backuppc.conf"
			moduledir="/usr/lib64/apache2/modules"
		fi
	fi

	# Check if we're using mod_cgid instead of mod_cgi
	# This happens if you install apache with USE="threads"
	if [[ -f "${moduledir}/mod_cgid.so" ]]; then
		sed -i -e "s+mod_cgi+mod_cgid+g" "${WORKDIR}/httpd.conf"
		sed -i -e "s+cgi_module+cgid_module+g" "${WORKDIR}/httpd.conf"
	fi

	# Generate a new password if there's no auth file
	if [[ ! -f "${CONFDIR}/users.htpasswd" ]]; then
		adminuser="backuppc"
		adminpass=$( makepasswd --chars=12 )
		htpasswd -bc "${WORKDIR}/users.htpasswd" $adminuser $adminpass
	fi

	# Install conf.d/init.d files
	if [ -e /etc/init.d/apache2 ]; then
		newconfd "${WORKDIR}/apache2-backuppc.conf" apache2-backuppc
		newinitd /etc/init.d/apache2 apache2-backuppc
	else
		newconfd "${WORKDIR}/apache2-backuppc.conf" apache2-backuppc
		newinitd "${WORKDIR}/apache2-backuppc.init" apache2-backuppc
	fi

	# Install httpd.conf & possibly a fresh htpasswd file
	insopts -m 0644
	insinto ${CONFDIR}
	doins "${WORKDIR}/httpd.conf"

	if [[ -f "${WORKDIR}/users.htpasswd" ]]; then
		doins "${WORKDIR}/users.htpasswd"
	fi

	eend $?

	webapp_src_install || die "webapp_src_install"

	ebegin "Patching config.pl for sane defaults"
		cd ${D}${CONFDIR}
		patch -p0 < "${FILESDIR}/config.pl-defaults.patch"
	eend $?

	# Make sure that the ownership is correct
	chown -R backuppc:backuppc "${D}${CONFDIR}"
	chown -R backuppc:backuppc "${D}${DATADIR}"
	chown -R backuppc:backuppc "${D}${LOGDIR}"
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
	elog "You also might want to add these scripts to your default runlevel:"
	elog "# rc-update add backuppc default"
	elog "# rc-update add apache2-backuppc default"
	elog ""

	if [[ -n "$adminpass" ]]; then
		elog "Created admin user $adminuser with password $adminpass"
		elog ""
	fi
}
