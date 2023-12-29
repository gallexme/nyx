# Conventions:
# - Sort packages in alphabetic order.
# - If the recipe uses `override` or `overrideAttrs`, then use callOverride,
#   otherwise use `final`.
# - Composed names are separated with minus: `input-leap`
# - Versions/patches are suffixed with an underline: `mesa_git`, `libei_0_5`, `linux_hdr`
# - Use `inherit (final) nyxUtils` since someone might want to override our utils

# NOTE:
# - `*_next` packages will be removed once merged into nixpkgs-unstable.

{ flakes, nixpkgs ? flakes.nixpkgs, self ? flakes.self, selfOverlay ? self.overlays.default }:
final: prev:
let
  # Required to load version files and warning.
  inherit (final.lib.trivial) importJSON warn;

  # Our utilities/helpers.
  nyxUtils = import ../shared/utils.nix { inherit (final) lib; nyxOverlay = selfOverlay; };
  inherit (nyxUtils) dropAttrsUpdateScript dropUpdateScript multiOverride multiOverrides overrideDescription;

  # Helps when calling .nix that will override packages.
  callOverride = path: attrs: import path ({ inherit final flakes nyxUtils prev gitOverride; } // attrs);

  # Helps when calling .nix that will override i686-packages.
  callOverride32 = path: attrs: import path ({
    inherit flakes nyxUtils gitOverride;
    final = final.pkgsi686Linux;
    final64 = final;
    prev = prev.pkgsi686Linux;
  } // attrs);

  # Magic helper for _git packages.
  gitOverride = import ../shared/git-override.nix {
    inherit (final) lib callPackage fetchFromGitHub fetchFromGitLab;
    nyx = self;
    fetchRevFromGitHub = final.callPackage ../shared/github-rev-fetcher.nix { };
    fetchRevFromGitLab = final.callPackage ../shared/gitlab-rev-fetcher.nix { };
  };

  # Too much variations
  cachyosPackages = callOverride ../pkgs/linux-cachyos/all-packages.nix { };

  # Microarch stuff
  makeMicroarch = lvl: with final;
    if stdenv.hostPlatform.isx86 then import "${nixpkgs}"
      {
        config.allowUnfree = true;
        overlays = [
          selfOverlay
          (_final': prev': {
            libuv = prev'.libuv.overrideAttrs (_prevattrs: { doCheck = false; });
          })
          (_final': prev': {
            "pkgsx86_64_${lvl}" = prev';
          })
        ] ++ overlays;
        ${if stdenv.hostPlatform == stdenv.buildPlatform
        then "localSystem" else "crossSystem"} = {
          parsed = stdenv.hostPlatform.parsed // {
            cpu = lib.systems.parse.cpuTypes.x86_64;
          };
          gcc = stdenv.hostPlatform.gcc // {
            arch = "x86-64-${lvl}";
          };
        };
      } // {
      recurseForDerivations = false;
      _description = "Nixpkgs + Chaotic_nyx packages built for the x86-64-${lvl} microarchitecture.";
    }
    else throw "x86_64_${lvl} package set can only be used with the x86 family.";

  # Common stuff for scx-schedulers
  scx-common = final.callPackage ../pkgs/scx/common.nix { };

  # Required for 32-bit packages
  has32 = final.stdenv.hostPlatform.isLinux && final.stdenv.hostPlatform.isx86;
in
{
  inherit nyxUtils;

  nyx-generic-git-update = final.callPackage ../pkgs/nyx-generic-git-update { };

  alacritty_git = callOverride ../pkgs/alacritty-git { };

  ananicy-cpp-rules = final.callPackage ../pkgs/ananicy-cpp-rules { };

  applet-window-appmenu = final.libsForQt5.callPackage ../pkgs/applet-window-appmenu { };

  applet-window-title = final.callPackage ../pkgs/applet-window-title { };

  appmenu-gtk3-module = final.callPackage ../pkgs/appmenu-gtk3-module { };

  beautyline-icons = final.callPackage ../pkgs/beautyline-icons { };

  blurredwallpaper = final.callPackage ../pkgs/blurredwallpaper { };

  busybox_appletless = multiOverride
    prev.busybox
    { enableAppletSymlinks = false; }
    (overrideDescription (old: old + " (without applets' symlinks)"));

  bytecode-viewer_git = final.callPackage ../pkgs/bytecode-viewer-git { };

  # Waiting for nixpkgs#272823 needed for mesa_git
  directx-headers_1_611 = callOverride ../pkgs/mesa-git/directx-headers-pin.nix { };
  directx-headers32_1_611 =
    if has32 then callOverride32 ../pkgs/mesa-git/directx-headers-pin.nix { }
    else throw "No directx-headers32_1_611 for non-x86";

  discord-krisp = callOverride ../pkgs/discord-krisp { };

  dr460nized-kde-theme = final.callPackage ../pkgs/dr460nized-kde-theme { };

  droid-sans-mono-nerdfont = multiOverrides
    final.nerdfonts
    { fonts = [ "DroidSansMono" ]; }
    [
      dropUpdateScript
      (overrideDescription (_prevDesc: "Provides \"DroidSansM Nerd Font\" font family."))
    ];

  extra-cmake-modules_git = callOverride ../pkgs/extra-cmake-modules-git/latest.nix { };

  firedragon-unwrapped = final.callPackage ../pkgs/firedragon { };

  firedragon = final.wrapFirefox final.firedragon-unwrapped {
    inherit (final.firedragon-unwrapped) extraPrefsFiles extraPoliciesFiles;
    libName = "firedragon";
  };

  firefox-unwrapped_nightly = final.callPackage ../pkgs/firefox-nightly { };
  firefox_nightly = final.wrapFirefox final.firefox-unwrapped_nightly { };

  gamescope_git = callOverride ../pkgs/gamescope-git { };

  # Used by telegram-desktop_git
  glib_git = callOverride ../pkgs/glib-git { };
  glibmm_git = callOverride ../pkgs/glibmm-git { };

  input-leap_git = callOverride ../pkgs/input-leap-git {
    inherit (final.libsForQt5.qt5) qttools;
  };

  kf6coreaddons_git = callOverride ../pkgs/kf6coreaddons-git/latest.nix { };

  latencyflex-vulkan = final.callPackage ../pkgs/latencyflex-vulkan { };

  libdrm_git = callOverride ../pkgs/libdrm-git { };

  linuxPackages_cachyos = cachyosPackages.cachyos;
  linuxPackages_cachyos-sched-ext = cachyosPackages.cachyos-sched-ext;
  linuxPackages_cachyos-server = cachyosPackages.cachyos-server;
  linuxPackages_cachyos-hardened = cachyosPackages.cachyos-hardened;
  linuxPackages-hardened_cachyos = warn
    "`linuxPackages-hardened_cachyos` was renamed to `linuxPackages_cachyos-hardened`"
    (final.linuxPackages_cachyos-hardened // { recurseForDerivations = false; });

  luxtorpeda = final.callPackage ../pkgs/luxtorpeda {
    luxtorpedaVersion = importJSON ../pkgs/luxtorpeda/version.json;
  };

  # You should not need "mangohud32_git" since it's embedded in "mangohud_git"
  mangohud_git = callOverride ../pkgs/mangohud-git { };
  mangohud32_git =
    if has32 then callOverride32 ../pkgs/mangohud-git { }
    else throw "No mangohud32_git for non-x86";

  mesa_git = callOverride ../pkgs/mesa-git { gbmDriver = true; };
  mesa32_git =
    if has32 then callOverride32 ../pkgs/mesa-git { }
    else throw "No mesa32_git for non-x86";

  # Waiting for nixpkgs#268583 needed for mesa_git
  meson_1_3 = callOverride ../pkgs/mesa-git/meson-pin.nix { };
  meson32_1_3 =
    if has32 then callOverride32 ../pkgs/mesa-git/meson-pin.nix { }
    else throw "No headers32_1_3 for non-x86";

  mpv-vapoursynth = (final.wrapMpv
    (final.mpv-unwrapped.override { vapoursynthSupport = true; })
    {
      extraMakeWrapperArgs = [
        "--prefix"
        "LD_LIBRARY_PATH"
        ":"
        "${final.vapoursynth-mvtools}/lib/vapoursynth"
      ];
    }
  ).overrideAttrs (overrideDescription (old: old + " (includes vapoursynth)"));

  nix-flake-schemas_git = callOverride ../pkgs/nix-flake-schemas-git { };

  nixfmt_rfc166 = callOverride ../pkgs/nixfmt-rfc166 { };

  nordvpn = final.callPackage ../pkgs/nordvpn { };

  nss_git = callOverride ../pkgs/nss-git { };

  openmohaa = final.callPackage ../pkgs/openmohaa {
    openmohaaVersion = importJSON ../pkgs/openmohaa/version.json;
  };
  openmohaa_git = callOverride ../pkgs/openmohaa-git { };

  pkgsx86_64_v2 = makeMicroarch "v2";
  pkgsx86_64_v3 = makeMicroarch "v3";
  pkgsx86_64_v4 = makeMicroarch "v4";

  pkgsx86_64_v3-core = dropAttrsUpdateScript (import ../shared/core-tier.nix final.pkgsx86_64_v3);

  proton-ge-custom = final.callPackage ../pkgs/proton-ge-custom {
    protonGeTitle = "Proton-GE";
    protonGeVersions = importJSON ../pkgs/proton-ge-custom/versions.json;
  };

  qtile_git = with final; python311Packages.toPythonApplication qtile-module_git;
  qtile-module_git = callOverride ../pkgs/qtile-git { };
  qtile-extras_git = callOverride ../pkgs/qtile-extras-git { };

  river_git = callOverride ../pkgs/river-git { };

  scx = final.callPackage ../pkgs/scx {
    inherit scx-common;
    scx-layered = final.callPackage ../pkgs/scx/layered { inherit scx-common; };
    scx-rusty = final.callPackage ../pkgs/scx/rusty { inherit scx-common; };
  };

  sway-unwrapped_git = callOverride ../pkgs/sway-unwrapped-git { };
  sway_git = prev.sway.override {
    sway-unwrapped = final.sway-unwrapped_git;
  };

  swaylock-plugin_git = callOverride ../pkgs/swaylock-plugin-git { };

  telegram-desktop_git = callOverride ../pkgs/telegram-desktop-git { };
  tg-owt_git = callOverride ../pkgs/tg-owt-git { };

  # You should not need "mangohud32_git" since it's embedded in "mangohud_git"
  vkshade_git = callOverride ../pkgs/vkshade-git { };
  vkshade32_git =
    if has32 then callOverride32 ../pkgs/vkshade-git { }
    else throw "No vkshade32_git for non-x86";

  vulkanPackages_latest = callOverride ../pkgs/vulkan-versioned
    { vulkanVersions = importJSON ../pkgs/vulkan-versioned/latest.json; };

  xdg-desktop-portal-wlr_git = callOverride ../pkgs/portal-wlr-git { };

  wayland_git = callOverride ../pkgs/wayland-git { };
  wayland-protocols_git = callOverride ../pkgs/wayland-protocols-git { };
  wayland-scanner_git = final.wayland_git.bin;

  waynergy_git = callOverride ../pkgs/waynergy-git { };

  wlroots_git = callOverride ../pkgs/wlroots-git { };

  yt-dlp_git = callOverride ../pkgs/yt-dlp-git { };

  yuzu-early-access_git = callOverride ../pkgs/yuzu-ea-git { };
}
