Memo
----

- [Qualcomm Linux Yocto documentation](https://docs.qualcomm.com/doc/80-70030-27/topic/yocto_landing_page.html)
- [Build with GitHub for unregistered users](https://docs.qualcomm.com/doc/80-70030-254/topic/github_workflow_unregistered_users.html)
- [Flash software images](https://docs.qualcomm.com/doc/80-70030-254/topic/flash_images.html)
- [qcom-manifest](https://github.com/qualcomm-linux/qcom-manifest.git)/README.md - Another source to build Qualcomm Linux (QLI)

Build
----

Setup the HOST build environment

- Refer to [Set up the Ubuntu host computer](https://docs.qualcomm.com/doc/80-70030-254/topic/github_workflow_unregistered_users.html#set-up-the-ubuntu-host-computer)

Initialize project

    make .layers

Build project

    make qli

Flash
----

Force EDL mode

1. Append file to /etc/udev/rules.d/

        # 05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", MODE="0664", GROUP="plugdev"

2. For IQ9075 EVK, turn ON the Switch SW2 (labeled "Mode") pin3
3. Plug USB0 (ADB)
4. Power on
6. Check `lsusb` have `05c6:9008 Qualcomm, Inc. Gobi Wireless Modem (QDL mode)`

Disable ModemManager: `systemctl stop ModemManager`

Provision UFS (one-time prerequisite)

1. (Re)Start at EDL mode
2. run `make ufs_provision`

Flash CDT

1. (Re)Start at EDL mode
2. run `make flash_cdt`

Flash SAIL (one-time prerequisite)

1. (Re)Start at EDL mode
2. run `make flash_sail`

Flash software

1. Disable ModemManager: `systemctl stop ModemManager`
2. (Re)Start at EDL mode
3. run `make flash_qli`

login
----

root / oelinux123

Abbreviate
----

- Qualcomm Linux (QLI)
- Universal flash storage (UFS)
- Configuration Data Table (CDT)
- Qualcomm Device Loader (QDL)
- Safety Island (SAIL)