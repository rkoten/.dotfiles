# https://search.nixos.org/options
# https://search.nixos.org/packages
# nixos-help

{ config, lib, pkgs, ... }:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
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
  services.xserver.videoDrivers = ["nvidia"];
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
    pulse.enable = true;
    jack.enable = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    joypixels.acceptLicense = true;
  };

  environment.systemPackages = let
    # Didn't check if the global allowUnfree applies already.
    unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };
  in with pkgs; [
    cmake
    dconf
    git
    gnumake
    libgcc
    meson
    ninja
    nvidia-vaapi-driver
    pipewire
    python3
    rustup
    tree
    wayland
    wget
    wireplumber
    wl-clipboard-x11
    xwayland
  ];

  users.users.rm = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];  # Enable sudo for the user.
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.rm = { pkgs, ... }: {
    home.packages = let
      # Didn't check if the global allowUnfree applies already.
      unstable = import <nixos-unstable> { config = { allowUnfree = true; }; };    
    in with pkgs; [
      discord
      docker
      dunst
      emote
      firefox
      gedit
      kitty
      mc
      qt6.qtwayland
      spotify
      swaybg
      telegram-desktop
      vlc
      vscode
      waybar
      wofi
      xdg-desktop-portal-hyprland

      unstable.hyprland
    ];
    programs.bash.enable = true;

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

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

  # Hyprland config
  programs.hyprland = {
    enable = true;
    enableNvidiaPatches = true;  # Deprecated? TODO check
    xwayland.enable = true;
  };
  programs.xwayland.enable = false;
  security.polkit.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # TODO figure out polkit agent
  # TODO fix hyprpm errors
}

