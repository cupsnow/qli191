#------------------------------------
#
SHELL=/bin/bash
.DEFAULT_GOAL=help

PROJDIR=$(CURDIR)
PYVENVDIR?=$(PROJDIR)/.venv
PYVENV=. $(PYVENVDIR)/bin/activate

APP_PLATFORM?=iq9075evk

APP_ATTR_iq9075evk=iq9075evk

APP_ATTR+=$(APP_ATTR_$(APP_PLATFORM))

#------------------------------------
#
GENDIR:=

help:
	echo "do nothing"

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
MACHINE_iq9075evk=qcs9075-iq-9075-evk
BUILDDIR?=build_$(APP_PLATFORM)

# setup-environment also use BUILDDIR variable
YOENV=MACHINE=$(MACHINE) DISTRO=qcom-wayland BUILDDIR= . ./setup-environment $(notdir $(BUILDDIR))
BBMAKE=$(YOENV) && chrt -i 0 bitbake

ifneq ($(wildcard $(PROJDIR)/tool/bin/qdl),)
QDL=$(PROJDIR)/tool/bin/qdl
else
# required for qdl, TODO: build these libraries
# ln -sfn /usr/lib/x86_64-linux-gnu/libxml2.so.16 tool/lib/libxml2.so.2
# ln -sfn /usr/lib/x86_64-linux-gnu/libzip.so.5 tool/lib/libzip.so.4
QDL_DIR=$(PROJDIR)/tool/qualcomm-device-loader_2.8_linux_x64
QDL=LD_LIBRARY_PATH=$(PROJDIR)/tool/lib $(QDL_DIR)/qdl
endif

.repo: BRANCH_NAME?=qcom-linux-scarthgap
.repo: RELEASE_MANIFEST?=qcom-6.6.142-QLI.1.9.1-Ver.1.1_qim-product-sdk-2.5.1.xml
.repo:
	repo init -u https://github.com/qualcomm-linux/qcom-manifest -b $(BRANCH_NAME) -m $(RELEASE_MANIFEST)

.layers: | .repo
	repo sync

qli_fetch:
	$(BBMAKE) --runall=fetch qcom-multimedia-image

qli:
# 	$(BBMAKE) qcom-multimedia-image
	ls -ld $(BUILDDIR)/tmp-glibc/deploy/images/$(MACHINE)/qcom-multimedia-image
	ls -ld $(BUILDDIR)/tmp-glibc/deploy/images/$(MACHINE)/sail_nor
	@echo 'To programming IQ-9075-EVK'
	@echo '  1. Turn ON Switch SW2 (Mode) pin3'
	@echo '  2. Check lsusb shows "05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)"'

CMD_UFSPROVISION=$(QDL) --storage ufs \
    $(or $(1),$(PROJDIR)/qcs9100-provision/)prog_firehose_ddr.elf \
	$(or $(1),$(PROJDIR)/qcs9100-provision/)provision_1_2.xml

ufs_provision:
	$(call CMD_UFSPROVISION,$(PROJDIR)/tool/qcs9100-provision/)

flash_check_qdl:
# 	check qdl runable
# 	check machine edl(qdl) mode
#	check files

onig:
	$(BBMAKE) onig-native

bb_%:
	$(BBMAKE) $*

dkqqdiff1:
	cd layers/meta-openembedded \
	  && git add -N meta-oe/recipes-support/onig/onig/0003-fix-build-with-gcc-15-c23.patch \
	  && git diff -- \
	      meta-oe/recipes-support/onig/onig_6.9.9.bb \
		  meta-oe/recipes-devtools/jq/jq_1.7.1.bb \
		  meta-oe/recipes-support/onig/onig/0003-fix-build-with-gcc-15-c23.patch \
		  | tee $(CURDIR)/0001-meta-openembedded.patch \
	  ; git reset meta-oe/recipes-support/onig/onig/0003-fix-build-with-gcc-15-c23.patch

dkqqdiff2:
	cd layers/meta-tensorflow \
	  && git diff -- \
	      classes/bazel.bbclass \
		  | tee $(CURDIR)/0002-meta-tensorflow.patch

dkqqdiff: dkqqdiff1 dkqqdiff2


#------------------------------------
#
print_%:
	@echo $*=$($*)

$(sort $(GENDIR)):
	mkdir -p $@

#------------------------------------
#------------------------------------
#------------------------------------
#------------------------------------

