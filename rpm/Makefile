SRCNAME  := setmy-info-elixir
REPO     := $(abspath $(CURDIR)/..)
# @version of the umbrella's mix.exs; RELEASE is the Jenkins build number (SMI_RPM_RELEASE).
VERSION  := $(shell sed -n 's/^ *@version "\([0-9.]*\)".*/\1/p' $(REPO)/mix.exs)
RELEASE  ?= $(or $(SMI_RPM_RELEASE),1)
TOPDIR   := $(shell rpm --eval '%{_topdir}')
STAGE    := $(CURDIR)/.stage
TARBALL  := $(TOPDIR)/SOURCES/$(SRCNAME)-$(VERSION).tar.gz

SPECS    := $(sort $(wildcard *.spec))
RPM_LIVE := $(TOPDIR)/RPMS/noarch/setmy-info-elixir-$(VERSION)-$(RELEASE).noarch.rpm
RPM_TEST := $(TOPDIR)/RPMS/noarch/setmy-info-elixir-test-$(VERSION)-$(RELEASE).noarch.rpm

RPMBUILD := rpmbuild --quiet -D 'smi_version $(VERSION)' -D 'smi_release $(RELEASE)'

DEPLOY_USER ?= deploy
# No machine is named in this repository: [user@]host[:port], several separated by spaces,
# come from the CI job (SMI_ELIXIR_TEST_HOSTS, SMI_ELIXIR_LIVE_HOSTS) or the command line.
TEST_HOSTS  ?= $(SMI_ELIXIR_TEST_HOSTS)
LIVE_HOSTS  ?= $(SMI_ELIXIR_LIVE_HOSTS)
REMOTE_DIR  ?= /home/deploy/deploy
INCOMING    ?= /var/opt/setmy.info/incoming

SMI_DEPLOY  = SMI_DEPLOY_USER=$(DEPLOY_USER) SMI_DEPLOY_REMOTE_DIR=$(REMOTE_DIR) \
              SMI_DEPLOY_INCOMING_DIR=$(INCOMING) smi-deploy

.PHONY: all rpms tarball spec-check upload-test upload-live move-test move-live \
        deploy-test deploy-live clean help

all: rpms

# Always rebuilt: mix knows what changed, make does not.
rpms: tarball
	for spec in $(SPECS); do $(RPMBUILD) -bb $$spec || exit 1; done

# Every app of the live build except formatter (a mix format plugin), as
# modules/<app>/{ebin,priv}, and the configuration the apps read at start.
SRCDIR   := $(STAGE)/$(SRCNAME)-$(VERSION)
BUILDLIB := $(REPO)/_build/live/lib

tarball:
	rm -rf $(STAGE) && mkdir -p $(SRCDIR)/modules $(SRCDIR)/config $(SRCDIR)/src/main $(TOPDIR)/SOURCES
	cd $(REPO) && MIX_ENV=live mix compile
	for app in $$(ls $(BUILDLIB)); do \
	    [ "$$app" = formatter ] && continue; \
	    mkdir -p $(SRCDIR)/modules/$$app && cp -a $(BUILDLIB)/$$app/ebin $(SRCDIR)/modules/$$app/ || exit 1; \
	    if [ -e $(BUILDLIB)/$$app/priv ]; then cp -RL $(BUILDLIB)/$$app/priv $(SRCDIR)/modules/$$app/ || exit 1; fi; \
	done
	cd $(REPO) && elixir -e 'IO.write(:io_lib.format("~p.~n", [Config.Reader.read!("config/config.exs", env: :live)]))' \
	    > $(SRCDIR)/config/sys.config
	cp -a $(REPO)/src/main/sh $(SRCDIR)/src/main/
	cp -a $(REPO)/LICENSE $(SRCDIR)/
	tar -C $(STAGE) -czf $(TARBALL) $(SRCNAME)-$(VERSION)
	rm -rf $(STAGE)

spec-check:
	for spec in $(SPECS); do rpmspec -D 'smi_version $(VERSION)' -D 'smi_release $(RELEASE)' -q $$spec || exit 1; done

define require_hosts
@[ -n "$(1)" ] || { echo "no hosts: set $(2) or SMI_ELIXIR_$(2), e.g. make deploy-test TEST_HOSTS='one.example.com two.example.com:2222'"; exit 1; }
endef

upload-test:
	$(call require_hosts,$(TEST_HOSTS),TEST_HOSTS)
	SMI_DEPLOY_HOSTS="$(TEST_HOSTS)" $(SMI_DEPLOY) upload $(RPM_TEST)

upload-live:
	$(call require_hosts,$(LIVE_HOSTS),LIVE_HOSTS)
	SMI_DEPLOY_HOSTS="$(LIVE_HOSTS)" $(SMI_DEPLOY) upload $(RPM_LIVE)

move-test:
	$(call require_hosts,$(TEST_HOSTS),TEST_HOSTS)
	SMI_DEPLOY_HOSTS="$(TEST_HOSTS)" $(SMI_DEPLOY) handover $(notdir $(RPM_TEST))

move-live:
	$(call require_hosts,$(LIVE_HOSTS),LIVE_HOSTS)
	SMI_DEPLOY_HOSTS="$(LIVE_HOSTS)" $(SMI_DEPLOY) handover $(notdir $(RPM_LIVE))

deploy-test: upload-test move-test

deploy-live: upload-live move-live

clean:
	rm -rf $(STAGE)
	rm -f $(RPM_LIVE) $(RPM_TEST) $(TARBALL)

help:
	@echo "make              build the RPMs: $(notdir $(RPM_LIVE)) $(notdir $(RPM_TEST))"
	@echo "make deploy-test  upload and hand over the TEST RPM to $(TEST_HOSTS)"
	@echo "make deploy-live  upload and hand over the LIVE RPM to $(LIVE_HOSTS)"
	@echo "                  (or upload-test/move-test, upload-live/move-live one by one)"
	@echo "make spec-check   parse the specs"
	@echo "make clean        remove the RPMs and the tarball"
