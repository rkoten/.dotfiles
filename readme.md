# rkoten's Unix readme

## Basics

### Iterate over files in a directory
```bash
for file in *; do
  if [ -f "$file" ]; then  # Skip to include directories
    echo "$file"
  fi
done
```

### List file permissions
`ls -ld`
- {read, write, execute} by {user, group, other}
- Read=4, Write=2, Execute=1; combination=sum.

### Hex dump
`xxd` (best piped through `less`).

### Mount NTFS drives
1. `lsblk -f` lists available filesystems.
2. `udisksctl mount -b /dev/X` mounts specified block device.

NixOS note: make sure `"ntfs"` is listed under `boot.supportedFilesystems` in OS config.


## Initial setup

### Dual boot with Windows
Fix Windows timezone:
```shell
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

### SSH via ghostty
When ssh-ing from ghostty into a machine that is unaware of ghostty's metadata, an `Error opening terminal: xterm-ghostty.` may occur. To fix, once in the remote shell:
```shell
export TERM=xterm-256color
```
Reference: https://ghostty.org/docs/help/terminfo

## Utils
  - [GRUB Customizer](https://launchpad.net/grub-customizer) is a GUI for GRUB configuration.
    ```
    sudo add-apt-repository ppa:danielrichter2007/grub-customizer
    sudo apt install grub-customizer
    ```

### Gnome

#### Extensions
  - [Grand Theft Focus](https://extensions.gnome.org/extension/5410/grand-theft-focus) brings popup windows to focus instead of "is ready" notification.

### ffmpeg

#### Reencode voice recording in Opus
Assume 24k output bitrate.
```shell
ffmpeg -i <audio-input> -c:a libopus -b:a 24k -ar 24k -ac 1 -application voip <audio-output.ogg>
```

#### Reencode video with rendered subtitles
Assume 1920x1080 output res, Avenir font @ size 16.
```shell
ffmpeg -i <video-input> -vf "scale=1920:1080:flags=lanczos:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,subtitles=<subtitle-input>:force_style='Fontname=Avenir,Fontsize=16'" -ss <start timestamp hh:mm:ss> -t <duration hh:mm:ss> <video-output>
```

### raspbian

#### raspi-config
TODO
