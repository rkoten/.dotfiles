{ pkgs ? import <nixpkgs> {} }: pkgs.mkShell {
  
  # nativeBuildInputs:
  #   Should be used for commands which need to run at build time (e.g. cmake) or shell hooks (e.g. autoPatchelfHook).
  #   These packages will be of the buildPlatforms architecture, and added to PATH. [1]
  nativeBuildInputs = with pkgs.buildPackages; [
    cmake
    gnumake
    # libexecinfo
    libgcc
    # udis86
  ];

  # buildInputs:
  #   Should be used for things that need to be linked against (e.g. openssl). These will be of the hostPlaform’s
  #   architecture. With strictDeps = true; (or by extension cross-platform builds), these will not be added to PATH.
  #   However, linking related variables will capture these packages (e.g. NIX_LD_FLAGS, CMAKE_PREFIX_PATH,
  #   PKG_CONFIG_PATH). [1]
  buildInputs = with pkgs.buildPackages; [
    freeglut
    libglvnd
    mesa
    # ------------- the cut line below which i have no idea if any of the listed is needed
    cmake
    gnumake
    # libexecinfo
    libgcc
    # udis86
  ];

  # packages:
  #   Adds executable packages to the nix-shell environment. [2]
  packages = with pkgs; [
    cmake
    gnumake
    libgcc
    pavucontrol
  ];

  # shellHook:
  #   Bash statements that are executed by nix-shell. [2]
  shellHook = "";

  LD_LIBRARY_PATH = "${pkgs.libglvnd}/lib";
  # OPENGL_gles3_LIBRARY = "${pkgs.libglvnd}/lib";
}

# [1]: https://discourse.nixos.org/t/use-buildinputs-or-nativebuildinputs-for-nix-shell/8464
# [2]: https://ryantm.github.io/nixpkgs/builders/special/mkshell/
