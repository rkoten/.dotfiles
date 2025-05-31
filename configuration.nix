# https://search.nixos.org/options
# https://search.nixos.org/packages
# nixos-help

{ config, currentSystem, flakeInputs, lib, ... }:

let
  pkgs = import flakeInputs.nixpkgs {
    system = currentSystem;
    config = {
      allowUnfree = true;
      joypixels.acceptLicense = true;
    };
  };
  unstable = import flakeInputs.nixpkgs-unstable {
    system = currentSystem;
    config.allowUnfree = true;
  };
in {
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./wireguard.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    supportedFilesystems = [ "ntfs" ];
  };

  # Covered by hardware config.
  # swapDevices = [ { label = "swap"; } ];

  # Enable TRIM support and set filesystem flags to improve SSD performance.
  fileSystems."/".options = [ "noatime" "nodiratime" "discard" ];

  networking = {
    hostName = "rmdesklin";

    # Pick only one of the below networking options.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  };

  time = {
    timeZone = "America/New_York";
    hardwareClockInLocalTime = true;  # Fixes time issues when dual-booting with Windows.
  };
  i18n.defaultLocale = "en_US.UTF-8";

  # Nvidia config
  hardware.graphics = {
    enable = true;
    package = unstable.mesa;
    enable32Bit = true;
  };
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Sound config
  security.rtkit.enable = true;  # Optional but recommended.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    pulse.enable = true;
  };

  services.udisks2.enable = true;  # Needed to enable auto-mounting storage devices.

  security.polkit.enable = true;
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      enable = true;
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;  # Replaces identical store files with hard links on every build.
  };
  nixpkgs.config.allowUnfree = true;  # Needed for things outside of flake inputs e.g. nvidia drivers.

  environment.sessionVariables = {
    NIXOS_CONFIG = "/etc/nixos/configuration.nix";
  };
  environment.shellAliases = {
    nfu = "nix flake update";
    nrb = "nixos-rebuild --impure";
    nsg = "nix store gc";
    nso = "nix store optimise";
  };

  environment.systemPackages = with pkgs; [
    bintools
    cifs-utils  # SMB helpers
    cmake
    dconf
    freeglut
    git
    glibc
    gmp
    gnumake
    gnupg
    inetutils
    jre_minimal
    libexecinfo
    libgcc
    libglvnd
    libmpc
    libpulseaudio
    libxcrypt
    unstable.mesa
    meson
    mpfr
    ninja
    nvidia-vaapi-driver
    p7zip
    pipewire
    polkit_gnome
    python3
    rar
    rustup
    tree
    usbutils
    wayland
    wget
    wireguard-tools
    wireplumber
    wl-clipboard-x11
    xorg.libX11
    xwayland
  ];

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
    libraries = with pkgs; [
      # https://github.com/Mic92/dotfiles/blob/main/nixos/modules/nix-ld.nix
      # https://unix.stackexchange.com/a/522823
      stdenv.cc.cc
      glibc
      libcxx
      libelf
      libgcrypt
    ];
  };

  users.groups = {
    plugdev = {};
  };
  users.users.rm = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "docker"  # Enables interaction with the docker daemon.
      "networkmanager"  # Grants permission to change network settings. [1]
      "plugdev"  # Allows mounting (only nodev and nosuid, for security reasons) removable devices through pmount. [3]
      "wheel"  # Enable sudo for the user.
    ];
  };

  fonts.packages = with pkgs; [
    fira-code
    fira-code-symbols
    font-awesome  # Waybar icons support
    joypixels  # Emoji support
    liberation_ttf
    mplus-outline-fonts.githubRelease
    noto-fonts
    noto-fonts-cjk-sans  # Asian languages support
    vistafonts  # Consolas <3
  ];

  virtualisation.docker.enable = true;

  services.samba = {
    # Note: still need to set up once manually with `sudo smbpasswd -a yourusername`.
    # Note: untested after the settings entry has been migrated from 24.05 to 25.05
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        browseable = "yes";
        "smb encrypt" = "required";
      };
      homes = {
        browseable = "no";
        "read only" = "no";
        "guest ok" = "no";
      };
    };
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      domain = true;
      hinfo = true;
      userServices = true;
      workstation = true;
    };
    extraServiceFiles = {
      smb = ''
        <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
        <service-group>
          <name replace-wildcards="yes">%h</name>
          <service>
            <type>_smb._tcp</type>
            <port>445</port>
          </service>
        </service-group>
      '';
    };
  };

  services.udev = {
    # Might need to manually apply changes with `sudo udevadm control --reload-rules && sudo udevadm trigger`.
    packages = [
      (pkgs.writeTextFile {
        name = "wooting_udev";
        text = ''
          # Wooting One Legacy
          SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff01", TAG+="uaccess", GROUP="plugdev"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff01", TAG+="uaccess", GROUP="plugdev"

          # Wooting One update mode
          SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2402", TAG+="uaccess", GROUP="plugdev"

          # Wooting Two Legacy
          SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff02", TAG+="uaccess", GROUP="plugdev"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="ff02", TAG+="uaccess", GROUP="plugdev"

          # Wooting Two update mode
          SUBSYSTEM=="hidraw", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2403", TAG+="uaccess", GROUP="plugdev"

          # Generic Wootings
          SUBSYSTEM=="hidraw", ATTRS{idVendor}=="31e3", TAG+="uaccess", GROUP="plugdev"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="31e3", TAG+="uaccess", GROUP="plugdev"
        '';
        destination = "/etc/udev/rules.d/70-wooting.rules";
      })
    ];
  };

  # TODO cachix
  # nix.settings = {
  #   substituters = [];
  # }

  # Some programs need SUID wrappers, can be configured further or are started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # services.openssh.enable = true;

  # Copies the NixOS configuration file and links it from the resulting system (/run/current-system/configuration.nix).
  # This is useful in case configuration.nix is accidentally deleted.
  system.copySystemConfiguration = true;

  # The state version is required and should stay at the version that was originally installed. [2]
  system.stateVersion = "23.11";

  # TODO enable when a by-number param is available
  # https://github.com/NixOS/nix/issues/9455
  # https://github.com/NixOS/nix/pull/10426
  # nix.gc = {
  #   automatic = true;
  #   persistent = true;
  #   dates = "05:00:00";
  #   options = "--delete-older-than 7d";
  # };
}

# [1]: https://nixos.org/manual/nixos/unstable/index.html#sec-networkmanager
# [2]: https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
# [3]: https://wiki.debian.org/SystemGroups
