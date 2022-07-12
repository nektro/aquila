# Generating the bootstrap QEMU images

## All
- set `root` password to `"root"`, some OSes don't like empty passwords
- set timezone as UTC
- most guided installers are really nice these days
- make the partitioner use the entire disk
- prefer picking a better mirror over enabling a proxy
- always install/enable OpenSSH

## Debian
- `./generate/debian.sh <arch>`
- Select "Install" option in GRUB when KVM boots up
- Most questions are prefilled but you do have to hit enter on the disk selection question
- During "Tasksel", uncheck "desktop environment" and "print server", check "openssh server"

## Alpine
- `./generate/alpine.sh <arch>`
- Login as "root"
- Run `setup-alpine` command and answer the installer prompts
- Run `poweroff` to shutdown the system

## FreeBSD
- `./generate/freebsd.sh <arch>`
- Select 'Multi user boot' in the bootloader (it's the first option)
- Select 'Install' at welcome screen
- Prefer UFS over ZFS for filesystem since jobs are run with low ram
- Prefer GPT partition table
- No need to add any other users
- Final config: exit
- Confirm opening a shell after installer is complete
- Run `poweroff` to shutdown the system

## NetBSD
- `./generate/netbsd.sh <arch>`
- Let it 'boot normally'
- Install netbsd to hard disk
- Guid partition table
- Let installer pick partiton sizes
- Use 'BIOS Console'
- either 'installation without X11' or 'minimal installation'
- Http download
- 'Configure Network'
- 'Get Distribution'
- Network info is fine to preserve
- Leave root password empty
- Enable sshd
- Enable ntpd
- Run ntpd at boot
- Select 'finish configuring'
- Select 'exit install system'
- Run `poweroff` to shutdown the system
