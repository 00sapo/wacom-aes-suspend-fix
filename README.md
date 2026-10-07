# Wacom USB HID suspend/resume fix for Linux

A small debianish systemd workaround for Wacom USB HID digitizers that remain present after suspend/resume but stop producing input events.

Created by ChatGPT.

This was tested for the Wacom AES digitizer in a Fujitsu LIFEBOOK U9310X, where the device is still visible after resume but `evtest` receives no pen or touch events. Other HID devices continue to work and the kernel log may contain no obvious error.

> ![NOTE]
> This is a different bug from the Lenovo Yoga 12, where after suspend the device where not recognized
and reloading the `wacom` kernel module was enough.

The workaround unbinds the matching Wacom HID interfaces and unloads the `wacom` kernel module before suspend. After resume it waits for the USB device to respond, reloads the module, and verifies that the HID driver binds again.

Default USB ID for the tested device: `056a:51dd`.

## Prerequisites

You need the USB **vendor ID (VID)** and **product ID (PID)** of your Wacom device. Install `usbutils` if `lsusb` is not already available:

```bash
sudo apt install usbutils
```

Then run:

```bash
lsusb | grep -i wacom
```

For the Fujitsu U9310X used to develop this workaround, the relevant part looks like:

```text
ID 056a:51dd Wacom Co., Ltd ...
```

Here `056a` is the vendor ID and `51dd` is the product ID.

#### If `lsusb` shows several Wacom devices

In this case, first identify the correct evdev node with:

```bash
sudo evtest
```

Then query that node, replacing `eventX` with the correct one:

```bash
udevadm info -q property -n /dev/input/eventX \
  | grep -E '^(ID_VENDOR_ID|ID_MODEL_ID)='
```

Example:

```text
ID_VENDOR_ID=056a
ID_MODEL_ID=51dd
```

The installer expects each value as exactly four hexadecimal digits. The values are case-insensitive.

You also need a systemd-based Linux installation and the in-kernel Wacom HID driver. The setup below is written for Debian and Debian-derived systems.

## Install

Clone or download this repository and run:

```bash
sudo ./install.sh 056a 51dd
```

Replace `056a 51dd` with your own VID and PID if necessary.

The installer creates:

```text
/usr/local/sbin/wacom-sleep-fix
/etc/default/wacom-sleep-fix
/etc/systemd/system/wacom-sleep-fix.service
```

and enables the service for `sleep.target`.

The configuration is stored in:

```text
/etc/default/wacom-sleep-fix
```

with this format:

```bash
VID=056a
PID=51dd
```

After changing it manually, no daemon reload is necessary because the file is read by the script at runtime.

## Test before suspending

Run the two halves manually first:

```bash
sudo /usr/local/sbin/wacom-sleep-fix pre
```

At this point the Wacom digitizer is intentionally detached. Check that the module was unloaded:

```bash
lsmod | grep '^wacom'
```

Then restore it:

```bash
sudo /usr/local/sbin/wacom-sleep-fix post
```

Check the HID driver and input events:

```bash
ls -l /sys/bus/hid/drivers/wacom/
sudo evtest
```

If pen/touch works again, test a real suspend/resume cycle:

```bash
sudo systemctl suspend
```

## Logging

The script logs through the journal. After resume:

```bash
journalctl -b -u wacom-sleep-fix.service
```

or only the script messages:

```bash
journalctl -b -t wacom-sleep-fix
```

A successful cycle should contain messages similar to:

```text
PRE: preparing Wacom 056a:51dd for suspend
unbinding HID device 0003:056A:51DD.0006
unbound 1 Wacom HID interface(s)
unloading wacom kernel module
PRE: complete
POST: system resumed
USB device 056a:51dd responding after attempt 1
loading wacom kernel module
Wacom HID driver rebound normally after attempt 1
POST: complete
```

## Verify the systemd unit

```bash
sudo systemd-analyze verify /etc/systemd/system/wacom-sleep-fix.service
systemctl is-enabled wacom-sleep-fix.service
systemctl list-dependencies sleep.target | grep wacom
```

The service uses the normal systemd sleep-target pattern: `ExecStart` runs before suspend, while `ExecStop` runs when `sleep.target` is torn down after resume.

## Manual installation

If you do not want to use `install.sh`:

```bash
sudo install -m 0755 wacom-sleep-fix /usr/local/sbin/wacom-sleep-fix
sudo install -m 0644 wacom-sleep-fix.service /etc/systemd/system/wacom-sleep-fix.service
sudo install -m 0644 wacom-sleep-fix.conf.example /etc/default/wacom-sleep-fix
sudo systemctl daemon-reload
sudo systemctl enable wacom-sleep-fix.service
```

Edit `/etc/default/wacom-sleep-fix` and set the correct VID/PID.

## Uninstall

```bash
sudo ./uninstall.sh
```

Or manually:

```bash
sudo systemctl disable wacom-sleep-fix.service
sudo rm -f /etc/systemd/system/wacom-sleep-fix.service
sudo rm -f /etc/default/wacom-sleep-fix
sudo rm -f /usr/local/sbin/wacom-sleep-fix
sudo systemctl daemon-reload
```

## How it works

The failure mode addressed here is not the common case where the USB device disappears completely after resume. The USB device and `/dev/input/event*` nodes may remain present, yet no pen or touch events are delivered.

The workaround performs this sequence:

```text
before suspend:
    locate matching Wacom HID interfaces
    -> unbind them from the wacom HID driver
    -> unload the wacom kernel module
    -> suspend

after resume:
    wait until the USB device responds
    -> reload the wacom module
    -> wait for normal HID rebinding
    -> request an HID reprobe if necessary
```

It does not unbind the xHCI controller and does not hard-code a USB topology path such as `1-9.1`.

## Ackowledgements

This workaround is based on the same approach documented for the Fujitsu LIFEBOOK U9310X in:

- https://github.com/pongwanitjea/LinuxWacomSleepResumeFIx

This repository packages the workaround in a Debian/systemd-friendly form, discovers the HID instance dynamically, keeps VID/PID in a configuration file, adds readiness/rebind checks, and adds structured journal logging.

## Caveats

- Unloading `wacom` affects every device currently using that kernel module during the suspend transition.
- This is a workaround for a resume failure, not a kernel/firmware fix.
- If your Wacom device actually disappears from USB after resume, a stronger USB-level reset or controller-specific workaround may be required instead.

## License

MIT.
