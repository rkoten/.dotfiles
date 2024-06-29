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
    # ./wireguard.nix
    <home-manager/nixos>
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # Covered by hardware config.
  # swapDevices = [ { label = "swap"; } ];

  # Enable TRIM support and set filesystem flags to improve SSD performance.
  fileSystems."/".options = [ "noatime" "nodiratime" "discard" ];

  networking.hostName = "rmdesklin";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  time = {
    timeZone = "America/New_York";
    hardwareClockInLocalTime = true;  # Fixes time issues when dual-booting with Windows.
  };
  i18n.defaultLocale = "en_US.UTF-8";

  # Nvidia config
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Sound config
  security.rtkit.enable = true;  # Optional but recommended.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = false;
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
    auto-optimise-store = true;  # Hardlinks unused store files on every build.
  };
  nixpkgs.config.allowUnfree = true;  # Needed for things outside of flake inputs e.g. nvidia drivers.

  environment.sessionVariables = {
    NIXOS_CONFIG = "/etc/nixos/configuration.nix";
  };

  environment.systemPackages = with pkgs; [
    cmake
    dconf
    freeglut
    git
    glibc
    gmp
    gnumake
    gnupg
    libexecinfo
    libgcc
    libglvnd
    libmpc
    libxcrypt
    mesa
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
    udis86
    wayland
    wev
    wget
    wireguard-tools
    wireplumber
    wl-clipboard-x11
    xwayland
  ];

  users.users.rm = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "networkmanager"  # Grants permission to change network settings. [1]
      "wheel"  # Enable sudo for the user.
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
  home-manager.users.rm = { ... }: {
    home.packages = with pkgs; [
      discord
      docker
      dunst
      emote
      firefox
      gedit
      gimp
      gnome.eog  # Image viewer
      gnome.gnome-calculator
      gnome.gnome-characters
      gnome.gnome-font-viewer
      gnome.gnome-system-monitor
      gnome.nautilus
      imv
      kdePackages.okular
      kitty
      libreoffice
      mc
      nodePackages.nodejs
      obs-studio
      obs-studio-plugins.wlrobs
      unstable.obsidian
      pavucontrol
      qbittorrent
      qemu
      qgis
      qt6.qtwayland
      shotman
      slurp
      spotify
      unstable.telegram-desktop
      vlc
      unstable.vscode
      unstable.waybar
      wev
      wofi
      xdg-desktop-portal-hyprland
      xdg-utils
    ];

    programs.vscode = {
      enable = true;
      package = unstable.vscode;
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = with unstable.vscode-extensions; [
        alefragnani.bookmarks
        jebbs.plantuml
        jnoortheen.nix-ide
        ms-vscode.hexeditor
        zainchen.json
        zxh404.vscode-proto3
      ];
      userSettings = {
        "editor.rulers" = [ 120 ];
        "editor.selectionClipboard" = false;  # Fixes middle click multi-cursor selection.
        "gitlens.codeLens.enabled" = false;
        "gitlens.statusBar.enabled" = false;
        "update.showReleaseNotes" = false;
      };
    };

    # Hyprland config
    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      systemd.enable = true;
      xwayland.enable = true;
      settings = {
        # https://wiki.hyprland.org/Configuring/Keywords
        # https://wiki.hyprland.org/Configuring/Variables
        monitor = ",preferred,auto,auto";  # https://wiki.hyprland.org/Configuring/Monitors
        exec-once = [
          "dunst &"
          "waybar &"
        ];
        env = [
          "GBM_BACKEND,nvidia-drm"
          "GTK_THEME,Adwaita:dark"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "LIBVA_DRIVER_NAME,nvidia"
          "NIXOS_OZONE_WL,1"
          "QT_QPA_PLATFORM,wayland"
          "QT_SCALE_FACTOR,1.2"
          "WLR_NO_HARDWARE_CURSORS,1"
          "XCURSOR_SIZE,24"
          "XDG_SESSION_TYPE,wayland"
        ];
        input = {
          kb_layout = "us,ua";
          kb_options = "grp:win_space_toggle";
          kb_model = "";
          kb_rules = "";
          kb_variant = "";
          follow_mouse = 1;
          sensitivity = -0.5;  # [-1.0, 1.0]; 0 means no modification.
        };
        general = {
          gaps_in = 5;
          gaps_out = 20;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
          allow_tearing = false;  # https://wiki.hyprland.org/Configuring/Tearing
        };
        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
          };
          drop_shadow = true;
          shadow_range = 4;
          shadow_render_power = 3;
          "col.shadow" = "rgba(1a1a1aee)";
        };
        # https://wiki.hyprland.org/Configuring/Animations
        animations = {
          enabled = true;
          bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
          animation = [
            # NAME, ONOFF {0, 1}, SPEED {1ds = 100ms}, CURVE [,STYLE]
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 4, default"
          ];
        };
        # https://wiki.hyprland.org/Configuring/Dwindle-Layout
        dwindle = {
          pseudotile = true;  # Master switch for pseudotiling. Bound to mainMod+P in the keybinds section.
          preserve_split = true;  # Recommended to enable.
        };
        master.new_status = "master";  # https://wiki.hyprland.org/Configuring/Master-Layout
        gestures.workspace_swipe = false;
        misc.force_default_wallpaper = 0;  # Disables the anime mascot wallpapers.
        # Example windowrule v1
        # windowrule = float, ^(kitty)$
        # Example windowrule v2
        # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
        # See https://wiki.hyprland.org/Configuring/Window-Rules for more
        "$mainMod" = "SUPER";
        "$appLauncher" = "wofi --show drun";
        "$fileManager" = "nautilus";
        "$terminal" = "kitty";
        # https://wiki.hyprland.org/Configuring/Binds
        bind = [
          "$mainMod, Q, exec, $terminal"
          "$mainMod, C, killactive,"
          "$mainMod SHIFT, Q, exit,"
          "$mainMod, E, exec, $fileManager"
          "$mainMod, V, togglefloating,"
          "$mainMod, R, exec, $appLauncher"
          "$mainMod, P, pseudo,"  # dwindle
          "$mainMod, J, togglesplit,"  # dwindle
          # Move focus with mainMod+arrow keys
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          # Switch workspaces with mainMod+[1,5]
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          # Move active window to a workspace with mainMod+SHIFT+[1,5]
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          # Example special workspace (scratchpad)
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
          # Scroll through existing workspaces with mainMod+scroll
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"
        ];
        # Move/resize windows with mainMod + LMB/RMB and dragging
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
      plugins = with pkgs; [
        hyprlandPlugins.hyprbars
      ];
    };

    services.udiskie.enable = true;  # Requires system-level `services.udisks2.enable` set to true.

    # Enable links opening across programs.
    xdg.portal = {
      # TODO fix telegram links
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
      config.common.default = [ "*" ];  # TODO there's probably a more granular working setup
      xdgOpenUsePortal = true;
    };

    # The state version is required and should stay at the version that was originally installed.
    home.stateVersion = "23.11";
  };

  fonts.packages = with pkgs; [
    fira-code
    fira-code-symbols
    font-awesome  # Waybar icons support
    joypixels  # Emoji support
    liberation_ttf
    mplus-outline-fonts.githubRelease
    noto-fonts
    noto-fonts-cjk  # Asian languages support
    vistafonts  # Consolas <3
  ];

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

  # TODO fix vlc pixelation & hangs
  # TODO setup smb file sharing
}

# [1]: https://nixos.org/manual/nixos/unstable/index.html#sec-networkmanager
# [2]: https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
