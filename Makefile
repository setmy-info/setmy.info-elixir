# The RPM build lives in rpm/, as in the other setmy.info projects.
TARGETS  := all rpms tarball spec-check upload-test upload-live move-test move-live \
            deploy-test deploy-live clean help

MAKEFLAGS += --no-print-directory

.PHONY: $(TARGETS)

$(TARGETS):
	$(MAKE) -C rpm $@
