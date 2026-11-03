#------------------------------------
#
SHELL=/bin/bash
.DEFAULT_GOAL=help
PROJDIR=$(CURDIR)

APP_PLATFORM?=iq9075evk

APP_ATTR_iq9075evk=iq9075evk

APP_ATTR+=$(APP_ATTR_$(APP_PLATFORM))

HOSTLSB_VER=$(strip $(shell lsb_release -rs))
APPARMOR_RESTRICT_USERNS=$(strip $(shell cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns))
LSUSB_QDL=$(strip $(shell lsusb -d 05c6:9008 >/dev/null 2>&1 && echo YES))

CLIARGS_VAL=$(if $(filter x"command line",x"$(strip $(origin $(1)))"),$($(1)))
CLIARGS_VERBOSE=$(or $(call CLIARGS_VAL,V),$(call CLIARGS_VAL,VERBOSE))

RSYNC_VERBOSE+=--debug=FILTER
ifneq ($(filter 1 2 3,$(CLIARGS_VERBOSE)),)
  CP_VERBOSE+=-v
  RM_VERBOSE+=-v
  MV_VERBOSE+=-v
  MKDIR_VERBOSE+=-v
  MESON_VERBOSE+=-v
  RSYNC_VERBOSE+=-v
  CMAKE_MAKE_VERBOSE+=VERBOSE=1
endif

GENDIR:=

#------------------------------------
#
help: help_self
help_self:
	@echo "Help your self"

PYVENVDIR?=$(PROJDIR)/.venv
PYVENV=. $(PYVENVDIR)/bin/activate

pyvenv $(PYVENVDIR):
	python3 -m venv $(PYVENVDIR)
	if [ -f "requirements.txt" ]; then \
	  $(PYVENV) && pip install -r requirements.txt --upgrade pip; \
	else \
	  $(PYVENV) && pip install --upgrade pip; \
	fi

#------------------------------------
# ubuntu 26.04: libusb-1.0-0-dev libzip-dev
#
qdl_DIR?=$(PROJDIR)/package/qdl
qdl_BUILDDIR?=$(PROJDIR)/build/qdl_$(APP_PLATFORM)
qdl_MESON=. $(PYVENVDIR)/bin/activate && meson

GENDIR+=$(qdl_BUILDDIR)

qdl_defconfig $(qdl_BUILDDIR)/build.ninja: | $(qdl_BUILDDIR) $(qdl_CROSSFILE_$(APP_PLATFORM))
	$(qdl_MESON) setup \
	    $(qdl_CROSSFILE_$(APP_PLATFORM):%=--cross-file=%) \
	    --prefix=/ \
	    --buildtype=release \
	    $(qdl_ACARGS_$(APP_PLATFORM)) \
	    $(qdl_BUILDDIR) $(qdl_DIR)

qdl_install: DESTDIR=$(PROJDIR)/tool
qdl_install: | $(qdl_BUILDDIR)/build.ninja
	$(qdl_MESON) compile $(MESON_VERBOSE) -C $(qdl_BUILDDIR)
	$(qdl_MESON) install --destdir=$(DESTDIR) -C $(qdl_BUILDDIR)

qdl: | $(qdl_BUILDDIR)/build.ninja
	$(qdl_MESON) compile $(MESON_VERBOSE) -C $(qdl_BUILDDIR)

#------------------------------------
#
qli_MACHINE_iq9075evk=qcs9075-iq-9075-evk

qli_MACHINE?=$(qli_MACHINE_$(APP_PLATFORM))
qli_BUILDDIR_rel?=build_yocto_$(APP_PLATFORM)
qli_BUILDDIR=$(qli_BUILDDIR_rel)

qli_DL_DIR?=/home/joelai/02_dev2/yocto-dl

qli_EXTRALAYERS+=meta-joedk

qli_YOENV=$(qli_EXTRALAYERS:%=EXTRALAYERS="%") \
    MACHINE=$(qli_MACHINE) DISTRO=qcom-wayland BUILDDIR= \
    DL_DIR=$(qli_DL_DIR) \
    . ./setenv.sh $(qli_BUILDDIR_rel)

qli_BITBAKE=$(qli_YOENV) && chrt -i 0 bitbake

QDL=$(PROJDIR)/tool/bin/qdl
QDL_PREREQ+=$(QDL)
$(QDL): qdl_install

.repo: BRANCH_NAME?=qcom-linux-scarthgap
.repo: RELEASE_MANIFEST?=qcom-6.6.142-QLI.1.9.1-Ver.1.1_qim-product-sdk-2.5.1.xml
.repo: MANIFEST_URL?=https://github.com/qualcomm-linux/qcom-manifest
.repo:
# make MANIFEST_URL=file://$(realpath ../qcom-manifest) .repo
	repo init -u $(MANIFEST_URL) -b $(BRANCH_NAME) -m $(RELEASE_MANIFEST)

layers: | .repo
	repo sync

qli_env: USERNS_CHECK
	$(qli_YOENV)

qli_fetch: USERNS_CHECK
	$(qli_BITBAKE) --runall=fetch dummy_target_qcom-multimedia-image

define qli_flash_hint
To programming IQ-9075-EVK
  1. Enter EDL mode by one of the following methods:
     - Run: adb shell reboot edl
     - Turn ON Switch SW1 (EDL) pin3
  2. Check lsusb shows a line likely "05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)"
  3. Run: make flash_qli
endef

.PHONY: qli_flash_hint
qli_flash_hint:
# if empty recipe, make will show "Nothing to be done for xxx"
	@:
	$(info $(qli_flash_hint))

qli: USERNS_CHECK | layers
	$(qli_BITBAKE) qcom-multimedia-image
	ls -ld $(qli_BUILDDIR)/tmp-glibc/deploy/images/$(qli_MACHINE)/qcom-multimedia-image
	ls -ld $(qli_BUILDDIR)/tmp-glibc/deploy/images/$(qli_MACHINE)/sail_nor
	@$(MAKE) --no-print-directory qli_flash_hint

CMD_UFSPROVISION= \
  cd $(or $(1),$(PROJDIR)/package/qcs9100-provision/) \
    && $(QDL) --storage ufs \
        $(or $(1),$(PROJDIR)/package/qcs9100-provision/)prog_firehose_ddr.elf \
        $(or $(1),$(PROJDIR)/package/qcs9100-provision/)provision_1_2.xml

ufs_provision: USBQDL_CHECK | $(QDL_PREREQ)
	$(call CMD_UFSPROVISION)

CMD_FLASHSAIL= \
  cd $(or $(1),$(qli_BUILDDIR)/tmp-glibc/deploy/images/$(qli_MACHINE)/sail_nor/) \
    && $(QDL) --storage spinor \
        prog_firehose_ddr.elf \
        rawprogram0.xml \
        patch0.xml

flash_sail: USBQDL_CHECK | $(QDL_PREREQ)
	$(call CMD_FLASHSAIL)

CMD_FLASHCDT= \
  cd $(or $(1),$(PROJDIR)/package/configuration-data-table-qcs9075-iq-9075-evk/) \
    && $(QDL) --storage ufs \
        prog_firehose_ddr.elf \
        rawprogram3.xml \
        patch3.xml

flash_cdt: USBQDL_CHECK | $(QDL_PREREQ)
	$(call CMD_FLASHCDT)

CMD_FLASH_QLI= \
  cd $(or $(1),$(qli_BUILDDIR)/tmp-glibc/deploy/images/$(qli_MACHINE)/qcom-multimedia-image/) \
    && cp $(CP_VERBOSE) \
        ./partition_ufs/gpt_main*.bin  \
        ./partition_ufs/gpt_backup*.bin  \
        ./partition_ufs/rawprogram[0-9].xml  \
        ./partition_ufs/patch*.xml  \
        ./partition_ufs/zeros_*sectors.bin  \
        ./ \
    && $(QDL) --storage ufs \
        prog_firehose_ddr.elf \
        rawprogram*.xml \
        patch*.xml

flash_qli: USBQDL_CHECK | $(QDL_PREREQ)
	$(call CMD_FLASH_QLI)

onig: USERNS_CHECK | layers
	$(qli_BITBAKE) onig-native

qli_%: USERNS_CHECK | layers
	$(qli_BITBAKE) $*

dkqqdiff1:
	cd layers/meta-openembedded \
	  && git add -N meta-oe/recipes-support/onig/onig/0003-fix-build-with-gcc-15-c23.patch \
	  && git diff -- \
	      meta-oe/recipes-support/onig/onig_6.9.9.bb \
	      meta-oe/recipes-devtools/jq/jq_1.7.1.bb \
	      meta-oe/recipes-support/onig/onig/0003-fix-build-with-gcc-15-c23.patch \
	      | tee $(PROJDIR)/0001-meta-openembedded.patch \
	  ; git reset meta-oe/recipes-support/onig/onig/0003-fix-build-with-gcc-15-c23.patch

dkqqdiff2:
	cd layers/meta-tensorflow \
	  && git diff -- \
	      classes/bazel.bbclass \
	      | tee $(PROJDIR)/0001-meta-tensorflow.patch

dkqqdiff: dkqqdiff1 dkqqdiff2

#------------------------------------
#
print_%:
	@echo '$*=$($*)'

$(sort $(GENDIR)):
	@mkdir -p $(MKDIR_VERBOSE) $@

# ERROR: User namespaces are not usable by BitBake, possibly due to AppArmor.
# See https://discourse.ubuntu.com/t/ubuntu-24-04-lts-noble-numbat-release-notes/39890#unprivileged-user-namespace-restrictions for more information.
USERNS_CHECK: FORCE
	@if [ ! "$(APPARMOR_RESTRICT_USERNS)" = "0" ]; then \
	  echo "In case of the error \"User namespaces are not usable by BitBake ...\""; \
	  echo "Please execute: echo 0 | sudo tee /proc/sys/kernel/apparmor_restrict_unprivileged_userns"; \
	  false; \
	fi

USBQDL_CHECK: FORCE
	@if [ -z "$(LSUSB_QDL)" ]; then \
	  echo "No QDL device (05c6:9008)."; \
	  echo "For IQ-9075 EVK; power off, turn on SW2 (Mode) pin3, connect USB0 (ADB), power on"; \
	  false; \
	fi

help:

FORCE:;
# do not add recipes to this target

#------------------------------------
#------------------------------------
#------------------------------------
#------------------------------------

