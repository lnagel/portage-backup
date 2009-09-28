# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit eutils webapp

MY_P="BackupPC-${PV}"

DESCRIPTION="backup system for desktops to a servers disk"
HOMEPAGE="http://backuppc.sourceforge.net"
SRC_URI="mirror://sourceforge/${PN}/${MY_P}.tar.gz"

LICENSE="GPL-2"
KEYWORDS="~amd64 x86"

IUSE="doc rsync samba"

DEPEND="dev-lang/perl"
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

# we really should install into a fixed slot otherwise upgrades will fail due to file collisions.
WEBAPP_MANUAL_SLOT="yes"
SLOT="0"

# detect if a previous installation exists and install into that slot to avoid file collisions.
oldslot=$( equery -C -N -q list -i backuppc )
oldslot=${oldslot##*(}
oldslot=${oldslot%%)*}
if [ "X$oldslot" != "X" ]; then
	SLOT="$oldslot"
	UPGRADE="true"
fi

S=${WORKDIR}/${MY_P}
migratedata="false"
DATADIR="/var/lib/BackupPC" #important: no trailing slash here!

pkg_setup() {
	enewgroup backuppc
	enewuser backuppc -1 -1 /dev/null backuppc
	webapp_pkg_setup
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
	local myconf
	myconf=""
	if use samba ; then
		myconf="--bin-path smbclient=$(type -p smbclient)"
		myconf="${myconf} --bin-path nmblookup=$(type -p nmblookup)"
	fi
	if [ $UPGRADE=="true" ]; then
		oldconfdir=$( find /etc/ -name config.pl -ipath "*backuppc*" )
		if [ "X$oldconfdir" != "X" ]; then
			#stop the server, just in case
			/etc/init.d/backuppc stop
			oldconfdir="${oldconfdir%/*}"
			#now make the old config files available for the new server
			insopts -m 644
			insinto /etc/BackupPC
			doins "${oldconfdir}/config.pl"
			doins "${oldconfdir}/hosts"
			ewarn "This is an upgrade. The config dir is now /etc/BackupPC."
			ewarn "If you are upgrading from a version prior to 3.x, you will have to carefully"
			ewarn "Check the new config file and then delete /etc/backuppc"
		fi
	fi

	webapp_src_preinst
	einfo ${MY_HTDOCSDIR}
	dodir ${MY_HTDOCSDIR}/${PN}

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
	keepdir /var/lib/BackupPC

	diropts -m 755
	keepdir /etc/BackupPC

	newinitd "${S}"/init.d/gentoo-backuppc backuppc
	newconfd "${S}"/init.d/gentoo-backuppc.conf backuppc
	
	ebegin "setting up an apache instance for backuppc"
	cp "${FILESDIR}/httpd.conf" "${WORKDIR}/httpd.conf"
	cd "$WORKDIR"
	sed -i -e "s+HTDOCSDIR+${MY_HTDOCSDIR}+g" "${WORKDIR}/httpd.conf"
	sed -i -e "s+AUTHFILE+/etc/BackupPC/authUser+g" "${WORKDIR}/httpd.conf"
	
	
	if [ -e /etc/init.d/apache2 ]; then
		newconfd "${FILESDIR}/apache2-backuppc.conf" apache2-backuppc
		newinitd /etc/init.d/apache2 apache2-backuppc
	elif [ -e /etc/init.d/apache ]; then #not sure if this works, could someone please test?
		newconfd "${FILESDIR}/apache2-backuppc.conf" apache-backuppc
		newinitd /etc/init.d/apache apache-backuppc
	else
		newconfd "${FILESDIR}/apache2-backuppc.conf" apache2-backuppc
		newinitd "${FILESDIR}/apache2-backuppc.init" apache2-backuppc
	fi

	insopts -m 644
	insinto /etc/BackupPC
	doins "${FILESDIR}"/authUser
	doins "${WORKDIR}/httpd.conf"
	eend $?
	
	webapp_postinst_txt en "${FILESDIR}"/postinstall-en.txt || die "webapp_postinst_txt"

	if [ $UPGRADE=="true" ]; then
		ebegin "Trying to migrate datadir..."
			if [ -e ${DATADIR} ] && [ ! -e /var/lib/backuppc ]; then
				elog "Upgrading: seems like the datadir is already in the correct position."
				i=0
			elif [ -e ${DATADIR} ] && [ -e /var/lib/backuppc ]; then
				ewarn "Upgrading: seems like you have both the old and the new datadir in your filesystem:"
				ewarn "${DATADIR} and /var/lib/backuppc. Please make sure BackupPC finds its data in ${DATADIR}."
				i=1
			elif [ ! -e ${DATADIR} ] && [ -e /var/lib/backuppc ]; then
				elog "Upgrading: will migrate /var/lib/backuppc to ${DATADIR} after installation"
				migratedata="true"
				i=0
			fi
		eend $i
	fi
	webapp_src_install || die "webapp_src_install"
}

pkg_postinst() {

	webapp_pkg_postinst
	if [ $UPGRADE=="true" ]; then
		ebegin "executing data migration..."
		if [ $migratedata == "true" ]; then
			rm -rf "${DATADIR}"
			mv /var/lib/backuppc "${DATADIR}"
			elog "sucessfully migrated old data to ${DATADIR}"
		fi
		oldifs=$IFS
		IFS='
'
		for oldhostconfig in $( find "${DATADIR}/pc" -maxdepth 2 -name config.pl ); do
			host=${oldhostconfig%/config.pl}; host=${host##*/}
			newhostconfig="/etc/BackupPC/pc/${host}.pl"
			if [ ! -e $newhostconfig ]; then
				mv "$oldhostconfig" "$newhostconfig"
				elog "Sucessfully moved config for ${host}"
			else
				elog "Config files for ${host} exist in both ${oldhostconfig} and ${newhostconfig}."
				elog "Not migrating configs for ${host}"
			fi
		done
		IFS=$oldifs
		eend $?
	fi
	ebegin "Adjusting ownership of various things..."
	chown -Rf backuppc:backuppc /etc/BackupPC
	#chown -f  root:apache       /etc/BackupPC/authUser
	chown -Rf backuppc:backuppc /var/log/BackupPC
	chown -Rf backuppc:backuppc ${DATADIR}
	chown -Rf backuppc:backuppc "${MY_HTDOCSDIR}"
	eend $?
	ebegin "making sure to not interfere with the standard apache installation"
	rm -rf "${G_HTDOCSDIR}/${PN}"
	eend $?

	elog "Please read the documentation"
	elog "you can start the server by typing:"
	elog "/etc/init.d/backuppc start && /etc/init.d/apache2-backuppc start"
	elog "afterwards you will be able to reach the web-frontend under the following address:"
	elog "https://your-servers-ip-address:28000/BackupPC_Admin"
}
