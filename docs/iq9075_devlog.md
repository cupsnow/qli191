

Build
----

- [Build with GitHub for unregistered users](https://docs.qualcomm.com/doc/80-70030-254/topic/github_workflow_unregistered_users.html)
- [Flash software images](https://docs.qualcomm.com/doc/80-70030-254/topic/flash_images.html#panel-1-SVEtOTA3NSBFVks=)

- [Qualcomm Linux Yocto documentation](https://docs.qualcomm.com/doc/80-70030-27/topic/yocto_landing_page.html)
- [qcom-manifest](https://github.com/qualcomm-linux/qcom-manifest.git)/README.md - Another source to build Qualcomm Linux (QLI)

Build qli191

Initialize project

    make .layers

Build project

    make qli

Flash
----

UDEV

    SUBSYSTEMS=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", MODE="0666", GROUP="plugdev"

EDL mode

1. Turn ON Switch SW2 (Mode) pin3
1. Check lsusb shows "05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)"

Provision file

    provision_1_2.xml

qdl dependency hack

    ln -sfn /usr/lib/x86_64-linux-gnu/libxml2.so.16 tool/lib/libxml2.so.2
    ln -sfn /usr/lib/x86_64-linux-gnu/libzip.so.5 tool/lib/libzip.so.4
    LD_LIBRARY_PATH=`pwd`/tool/lib qualcomm-device-loader_2.8_linux_x64/qdl -h

UFS provision

    ./qdl --storage ufs prog_firehose_ddr.elf provision_1_2.xml

Flash SAIL

> # SAIL image is under <workspace_path>/build-<DISTRO>/tmp-glibc/deploy/images/<MACHINE>/<IMAGE>/sail_nor
> # build_path: For DISTRO=qcom-wayland, it's build-qcom-wayland.
> #             For DISTRO=qcom-robotics-ros2-jazzy, it's build-qcom-robotics-ros2-jazzy
> # qdl --storage spinor <prog.mbn> [<program> <patch> ...]
> # Example, build_path is build-qcom-wayland
> cd <workspace_path>/build-qcom-wayland/tmp-glibc/deploy/images/qcs9075-rb8-core-kit/qcom-multimedia-image/sail_nor
> <qdl_download_path>/QDL_<version>_<operating_system>_<architecture_type>/qdl --storage spinor prog_firehose_ddr.elf rawprogram0.xml patch0.xml
> # Example, <qdl_download_path>/QDL_2.3.9_Linux_x64/qdl --storage spinor prog_firehose_ddr.elf rawprogram0.xml patch0.xml

flash cdt

flash software

    ./qdl --storage ufs prog_firehose_ddr.elf rawprogram*.xml patch*.xml

Abbreviate
----

- Qualcomm Linux (QLI)
- Universal flash storage (UFS)
- Configuration Data Table (CDT)
- Qualcomm Device Loader (QDL)
- Safety Island (SAIL)