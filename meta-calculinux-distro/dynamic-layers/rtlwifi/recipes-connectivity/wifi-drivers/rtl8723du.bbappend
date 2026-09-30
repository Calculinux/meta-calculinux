# GCC 15 treats mismatched vendor header guards as errors.
EXTRA_OEMAKE:append = " KCFLAGS=-Wno-error=header-guard"
