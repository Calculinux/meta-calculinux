FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append := " \
                    file://fstab \
                    file://locale.sh \
                    file://vconsole.conf \
                    file://bash_completion.sh \
                  "
                  
do_install:append() {
    install -d ${D}${sysconfdir}/profile.d
    install -m 0644 ${WORKDIR}/sources/locale.sh ${D}${sysconfdir}/profile.d/locale.sh
    install -m 0644 ${WORKDIR}/sources/bash_completion.sh ${D}${sysconfdir}/profile.d/bash_completion.sh

    install -d ${D}${sysconfdir}
    
    # Install vconsole.conf for default console font
    install -m 0644 ${WORKDIR}/sources/vconsole.conf ${D}${sysconfdir}/vconsole.conf

    codename="${DISTRO_CODENAME}"
    [ -n "${codename}" ] || codename="unknown"

    cat <<EOF > ${D}${sysconfdir}/issue
${DISTRO_NAME}
====================
Version : ${DISTRO_VERSION}
Codename: ${codename}
Machine : ${MACHINE}

Docs
  https://calculinux.org/
Issues
  github.com/Calculinux
  /meta-calculinux/issues
EOF

    cat <<EOF > ${D}${sysconfdir}/issue.net
${DISTRO_NAME}
====================
Version : ${DISTRO_VERSION}
Codename: ${codename}
Machine : ${MACHINE}

Docs
  https://calculinux.org/
Issues
  github.com/Calculinux
  /meta-calculinux/issues
EOF

    cat <<EOF > ${D}${sysconfdir}/motd
Welcome to ${DISTRO_NAME} ${DISTRO_VERSION}

System
  Codename: ${codename}
  Machine : ${MACHINE}

Help
  Docs   : https://calculinux.org/
  Issues : github.com/Calculinux
           /meta-calculinux/issues
  Feeds  : https://opkg.calculinux.org/

Quick Commands
  opkg update
  opkg list
  opkg list-installed
  cat /etc/os-release
EOF
}
