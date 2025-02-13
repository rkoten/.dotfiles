# rkoten's Linux readme


## Basics

### List permissions
`ls -ld`
- {read, write, execute} by {user, group, other}
- Read=4, Write=2, Execute=1; combination=sum.

### Hex dump
`xxd | less`

### Mount NTFS drives
1. `lsblk -f` lists available filesystems.
2. `udisksctl mount -b /dev/X` mounts specified block device.

NixOS note: make sure `"ntfs"` is listed under `boot.supportedFilesystems` in OS config.


## Initial setup

### Dual boot with Windows
Fix Windows timezone:
```
timedatectl set-local-rtc 1
```

### Disabling Ubuntu update notifications
 - (?) `sudo chmod 000 /usr/bin/update-manager`
 - `sudo chmod 000 /usr/bin/update-notifier`
 - Reboot


## Networking

### Network fileshare
 1. ```
    sudo apt install samba smbclient
    [for Ubuntu/Nautilus] sudo apt install nautilus-share
    ```
 2. Grant firewall permissions.
    ```
    sudo ufw allow 'Samba'
    ```
 3. Create a network password for your user.
    ```
    sudo smbpasswd -a <username>
    ```
 4. Reboot.
 5. (Optional) Verify  SMB service is running.
    ```
    systemctl status smbd
    ```
 6. Access via `smb://<ip-address>` and use the full `username@hostname` combination as username when connecting.

### Check active network interface
```shell
route -n get <any-ip> | grep interface
# e.g.
route -n get 1.1.1.1 | grep interface
```

## Utils
  - [GRUB Customizer](https://launchpad.net/grub-customizer) is a GUI for GRUB configuration.
    ```
    sudo add-apt-repository ppa:danielrichter2007/grub-customizer
    sudo apt install grub-customizer
    ```

### Gnome

#### Extensions
  - [Grand Theft Focus](https://extensions.gnome.org/extension/5410/grand-theft-focus) brings popup windows to focus instead of "is ready" notification.

### raspbian

#### raspi-config
TODO
