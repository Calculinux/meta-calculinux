FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# This patch includes both image status file support AND query filtering
SRC_URI += "file://0002-opkg-add-query-filtering-for-split-status-files.patch \
            "
