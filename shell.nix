{ pkgs ? import <nixpkgs> {} }: pkgs.mkShell rec {
  # From [3]:
  #   - If it is used at build-time it's depsBuildXXX
  #   - If it is used at run-time it's depsHostXXX.
  #     [Stack linking doesn't effect this, even if it allows us to forget where things came from.]
  #   - If it is a tool and "acts" (e.g. helps build) on build-time stuff, then it's depsXXXBuild
  #   - If it is a tool and "acts" on run-time stuff, then it's depsXXXHost
  #   - If it is not a tool, it's depsXXX(XXX+1) (build + 1 == host, host +1 == target)
  #   - For backwards compatibility, use nativeBuildInputs instead of depsBuildHost and buildInputs instead of depsHostTarget.

  # nativeBuildInputs:
  #   Should be used for commands which need to run at build time (e.g. cmake) or shell hooks (e.g. autoPatchelfHook).
  #   These packages will be of the buildPlatforms architecture, and added to PATH. [1]
  nativeBuildInputs = with pkgs.buildPackages; [
    cmake
    gnumake
    libgcc
  ];

  # buildInputs:
  #   Should be used for things that need to be linked against (e.g. openssl). These will be of the hostPlaform’s
  #   architecture. With strictDeps = true; (or by extension cross-platform builds), these will not be added to PATH.
  #   However, linking related variables will capture these packages (e.g. NIX_LD_FLAGS, CMAKE_PREFIX_PATH,
  #   PKG_CONFIG_PATH). [1]
  buildInputs = with pkgs.buildPackages; [
    alsa-lib
    freeglut
    # glibc should be left out of buildInputs.
    gmp
    hiredis  # Redis library. Apparently used to speed things up locally by some libs.
    libglvnd
    libjack2
    libmpc
    # libstdcxx5 should be left out of buildInputs.
    libxcrypt
    mesa
    mpfr
    zlib
  ];

  # packages:
  #   Adds executable packages to the nix-shell environment. [2]
  packages = with pkgs; [
    cmake
    gnome.eog
    gnumake
    htop
    libgcc
    pavucontrol
  ];

  # shellHook:
  #   Bash statements that are executed by nix-shell. [2]
  shellHook = ''
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${pkgs.stdenv.cc.cc.lib.outPath}/lib"
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${pkgs.lib.makeLibraryPath buildInputs}"
  '';
}

# [1]: https://discourse.nixos.org/t/use-buildinputs-or-nativebuildinputs-for-nix-shell/8464
# [2]: https://ryantm.github.io/nixpkgs/builders/special/mkshell/
# [3]: https://github.com/NixOS/nixpkgs/pull/50881#issuecomment-440794465
