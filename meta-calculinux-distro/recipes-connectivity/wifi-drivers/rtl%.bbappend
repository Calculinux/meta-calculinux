# GCC 15 treats mismatched vendor header guards as errors. Realtek's out-of-tree
# drivers have several of these; -Wno-error=header-guard covers the family
# instead of patching each typo as CI finds it.
EXTRA_OEMAKE:append = " KCFLAGS=-Wno-error=header-guard"
