# https://search.nixos.org/options
# https://search.nixos.org/packages
# nixos-help

{ config, lib, pkgs, ... }:

let
  unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
in {
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./wireguard.nix
    <home-manager/nixos>
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Covered by hardware config.
  # swapDevices = [ { label = "swap"; } ];

  # Enable TRIM support and set filesystem flags to improve SSD performance.
  fileSystems."/".options = [ "noatime" "nodiratime" "discard" ];

  networking.hostName = "rmdesklin";
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true;  # Fixes time issues when dual-booting with Windows.
  i18n.defaultLocale = "en_US.UTF-8";

  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

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
  };

  nixpkgs.config = {
    allowUnfree = true;
    joypixels.acceptLicense = true;
  };

  environment.systemPackages = with pkgs; [
    cmake
    dconf
    freeglut
    git
    gnumake
    gnupg
    libgcc
    mesa
    meson
    ninja
    nvidia-vaapi-driver
    p7zip
    pipewire
    polkit_gnome
    python3
    rar
    rustup
    tree
    wayland
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
      "wheel"  # Enable sudo for the user.
    ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.rm = { pkgs, ... }: {
    # The state version is required and should stay at the version that was originally installed.
    home.stateVersion = "23.11";

    home.packages = with pkgs; [
      discord
      docker
      dunst
      emote
      firefox
      gedit
      unstable.hyprland
      kitty
      libreoffice
      mc
      nodePackages.nodejs
      qbittorrent
      qemu
      qgis
      qt6.qtwayland
      spotify
      swaybg
      telegram-desktop
      vlc
      unstable.vscode
      waybar
      wofi
      xdg-desktop-portal-hyprland
    ];

    programs.vscode = {
      enable = true;
      package = unstable.vscode;
      extensions = with unstable.vscode-extensions; [
        alefragnani.bookmarks
        jebbs.plantuml
        jnoortheen.nix-ide
        ms-vscode.hexeditor
        zainchen.json
        zxh404.vscode-proto3
      ];
    };

    # Hyprland config
    wayland.windowManager.hyprland = {
      enable = true;
      package = unstable.hyprland;
      systemd.enable = true;
      xwayland.enable = true;
      settings = {
        # https://wiki.hyprland.org/Configuring/Keywords
        # https://wiki.hyprland.org/Configuring/Variables
        monitor = ",preferred,auto,auto";  # https://wiki.hyprland.org/Configuring/Monitors
        exec-once = [
          "dunst &"
          "waybar &"
          "swaybg &"
          # "hyprpm reload -n"  # TODO fix
          # "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1 &"
        ];
        env = [
          "XCURSOR_SIZE,24"
          "LIBVA_DRIVER_NAME,nvidia"
          "XDG_SESSION_TYPE,wayland"
          "GBM_BACKEND,nvidia-drm"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "WLR_NO_HARDWARE_CURSORS,1"
        ];
        input = {
          kb_layout = "us";
          kb_variant = "";
          kb_model = "";
          kb_options = "";
          kb_rules = "";
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
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };
        # https://wiki.hyprland.org/Configuring/Dwindle-Layout
        dwindle = {
          pseudotile = true;  # Master switch for pseudotiling. Bound to mainMod+P in the keybinds section.
          preserve_split = true;  # Recommended to enable.
        };
        master.new_is_master = true;  # https://wiki.hyprland.org/Configuring/Master-Layout
        gestures.workspace_swipe = false;
        misc.force_default_wallpaper = 0;  # Disables the anime mascot wallpapers.
        # Example windowrule v1
        # windowrule = float, ^(kitty)$
        # Example windowrule v2
        # windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
        # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
        "$mainMod" = "SUPER";
        "$appLauncher" = "wofi --show drun";
        "$fileManager" = "mc";
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
          # Move focus with mainMod + arrow keys
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          # Switch workspaces with mainMod + [0-9]
          #  "$mainMod, 1, workspace, 1"
          #  "$mainMod, 2, workspace, 2"
          #  "$mainMod, 3, workspace, 3"
          #  "$mainMod, 4, workspace, 4"
          #  "$mainMod, 5, workspace, 5"
          #  "$mainMod, 6, workspace, 6"
          #  "$mainMod, 7, workspace, 7"
          #  "$mainMod, 8, workspace, 8"
          #  "$mainMod, 9, workspace, 9"
          #  "$mainMod, 0, workspace, 10"
          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          #  "$mainMod SHIFT, 1, movetoworkspace, 1"
          #  "$mainMod SHIFT, 2, movetoworkspace, 2"
          #  "$mainMod SHIFT, 3, movetoworkspace, 3"
          #  "$mainMod SHIFT, 4, movetoworkspace, 4"
          #  "$mainMod SHIFT, 5, movetoworkspace, 5"
          #  "$mainMod SHIFT, 6, movetoworkspace, 6"
          #  "$mainMod SHIFT, 7, movetoworkspace, 7"
          #  "$mainMod SHIFT, 8, movetoworkspace, 8"
          #  "$mainMod SHIFT, 9, movetoworkspace, 9"
          #  "$mainMod SHIFT, 0, movetoworkspace, 10"
          # Example special workspace (scratchpad)
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"
          # Scroll through existing workspaces with mainMod + scroll
          "$mainMod, mouse_down, workspace, e+1"
          "$mainMod, mouse_up, workspace, e-1"
        ];
        # Move/resize windows with mainMod + LMB/RMB and dragging
        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
      # TODO
      # plugins = [
      #
      # ];
    };
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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  # services.openssh.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?

  # TODO enable when a by-number param is available
  # https://github.com/NixOS/nix/issues/9455
  # https://github.com/NixOS/nix/pull/10426
  # nix.gc = {
  #   automatic = true;
  #   persistent = true;
  #   dates = "05:00:00";
  #   options = "--delete-older-than 7d";
  # };

  programs.xwayland.enable = false;
  security.polkit.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # TODO fix hyprpm errors
  # TODO fix vlc pixelation & hangs
  # TODO add language switching
  # TODO setup smb file sharing
}
