# rkoten's Unix notes

## Basics

### Files

#### Iterate over files in a directory
```bash
for file in *; do
  if [ -f "$file" ]; then  # Skip to include directories
    echo "$file"
  fi
done
```

#### List file permissions
```shell
ls -ld
```
- {read, write, execute} by {user, group, other}
- Read=4, Write=2, Execute=1; combination=sum.

#### Mount NTFS drives
1. `lsblk -f` lists available filesystems.
2. `udisksctl mount -b /dev/X` mounts specified block device.

NixOS note: make sure `"ntfs"` is listed under `boot.supportedFilesystems` in OS config.

### Processes

#### Find a process by keyword
```shell
pgrep -il "keyword"
```
\- OR -
```shell
ps aux | grep "keyword"
```
(ignore `grep` itself as it'll be included in the `ps aux` results).

#### Kill a process

- Gracefully by PID: `kill <pid>`
- Forcefully by PID: `kill -9 <pid>`
- Suspended process in the current shell: `kill %1`

### Utils

- File description: `file`
- Hex dump: `xxd` (best piped through `less`).


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

### Run a speed test (macOS)
```shell
networkquality
```

### SSH via ghostty
When ssh-ing from ghostty into a machine that is unaware of ghostty's metadata, an `Error opening terminal: xterm-ghostty.` may occur. To fix, once in the remote shell:
```shell
export TERM=xterm-256color
```
Reference: https://ghostty.org/docs/help/terminfo


## Nix specifics

### Include a specific package inline
On the example of `nix` and `nixos-rebuild` from the unstable repo:
```shell
nix shell github:NixOS/nixpkgs/nixpkgs-unstable#{nix,nixos-rebuild}
```


## Utils

### Docker
Assume container name "image".

Build the container from Dockerfile in the current dir:
```shell
docker build -t image .
```

Run the built container, assume port 1337:
```shell
docker run [--rm] [-d] [--privileged] -p 1337:1337 [--name nickname] image
```
- `--rm` removes the container once it's stopped.
- `-d` runs it detached and gives back control over the shell.
- `--privileged` lifts capability limitations on the container (can do virtually everything that the host can).
- `--name` gives the container a nickname, for convenient referencing.

List existing (running and stopped) containers:
```shell
docker ps -a
```

From the listed containers in the step above, take the reference (hash or nickname) of the given container.
```shell
docker exec -it <reference> /bin/bash
```

When done:
```shell
docker stop <reference>
```

If `--rm` was not passed when running a container, to remove it after stopping:
```shell
docker rm <reference>
```

### Gnome

#### Extensions
  - [Grand Theft Focus](https://extensions.gnome.org/extension/5410/grand-theft-focus) brings popup windows to focus instead of "is ready" notification.

### GRUB
[GRUB Customizer](https://launchpad.net/grub-customizer) is a GUI for GRUB configuration.
```shell
sudo add-apt-repository ppa:danielrichter2007/grub-customizer
sudo apt install grub-customizer
```

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

### cpdf (Coherent PDF)
Manual: [link](https://coherentpdf.com/dotnetcpdflibmanual.pdf)

#### Combine PDFs
```shell
cpdf input1.pdf input2.pdf [inputN.pdf] -o output.pdf
```

### raspbian

#### raspi-config
TODO
