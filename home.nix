{ flakeInputs, currentSystem, ... }:

let
  pkgs = import flakeInputs.nixpkgs {
    system = currentSystem;
    config.allowUnfree = true;
  };
  unstable = import flakeInputs.nixpkgs-unstable {
    system = currentSystem;
    config.allowUnfree = true;
  };
in {
  home.sessionPath = [
    "$HOME/.cargo/bin"
  ];
  programs.bash = {
    enable = true;
    initExtra = ''
      # Include per-user hm-session-vars.sh if it exists.
      [[ -f /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh ]] &&
      source /etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh
    '';
  };

  home.packages = with pkgs; [
    # Dev packages
    nodePackages.nodejs
    protobuf
    protoc-gen-validate

    # Env packages
    dunst
    pavucontrol
    playerctl
    shotman
    slurp
    unstable.waybar
    wofi
    xdg-desktop-portal-hyprland
    xdg-utils

    # User packages
    discord
    firefox
    gedit
    gimp
    gnome.eog  # Image viewer
    gnome.gnome-calculator
    gnome.gnome-characters
    gnome.gnome-font-viewer
    gnome.gnome-system-monitor
    gnome.nautilus
    kdePackages.okular
    keepass
    kitty
    libreoffice
    mc
    obs-studio
    obs-studio-plugins.wlrobs
    unstable.obsidian
    qbittorrent
    qemu
    qgis
    qt6.qtwayland
    sparrow
    spotify
    unstable.telegram-desktop
    tldr
    vlc
    ungoogled-chromium
    unstable.vscode
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
        pseudotile = true;  # Master switch for pseudotiling. Bound to super+P in the keybinds section.
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
      "$launchpad" = "wofi --show drun";
      "$fileManager" = "nautilus";
      "$terminal" = "kitty";
      bind = [
        "SUPER, Q, exec, $terminal"
        "SUPER, C, killactive,"
        "SUPER SHIFT, Q, exit,"
        "SUPER, E, exec, $fileManager"
        "SUPER, V, togglefloating,"
        "SUPER, R, exec, $launchpad"
        # ", XF86Search, exec, $launchpad"
        "SUPER, P, pseudo,"  # dwindle
        "SUPER, J, togglesplit,"  # dwindle
        # Move focus with super+arrow keys
        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"
        # Switch workspaces with super+[1,5]
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        # Move active window to a workspace with super+SHIFT+[1,5]
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
        # Example special workspace (scratchpad)
        "SUPER, S, togglespecialworkspace, magic"
        "SUPER SHIFT, S, movetoworkspace, special:magic"
        # Scroll through existing workspaces with super+scroll
        "SUPER, mouse_down, workspace, e+1"
        "SUPER, mouse_up, workspace, e-1"
      ];
      # Bind flags [3]:
      # l -> locked, will also work when an input inhibitor (e.g. a lockscreen) is active.
      # r -> release, will trigger on release of a key.
      # e -> repeat, will repeat when held.
      # n -> non-consuming, key/mouse events will also be passed to the active window.
      # m -> mouse.
      # t -> transparent, cannot be shadowed by other binds.
      # i -> ignore modifiers.
      bindm = [
        "SUPER, mouse:272, movewindow"  # mouse1
        "SUPER, mouse:273, resizewindow"  # mouse2
      ];
      # https://github.com/xkbcommon/libxkbcommon/blob/master/include/xkbcommon/xkbcommon-keysyms.h
      # https://wiki.archlinux.org/title/WirePlumber#Keyboard_volume_control
      # Need to make sure `@DEFAULT_AUDIO_SINK@` is set correctly via `wpctl set-default <id from wpctl status>`.
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];
      bindle = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];
    };
    plugins = with pkgs; [
      hyprlandPlugins.hyprbars
    ];
  };

  services.udiskie.enable = true;  # Requires system-level `services.udisks2.enable` set to true.

  # Enable links opening across programs.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    config.common.default = [ "*" ];  # TODO there's probably a more granular working setup
    xdgOpenUsePortal = true;
  };

  # The state version is required and should stay at the version that was originally installed.
  home.stateVersion = "23.11";
}
