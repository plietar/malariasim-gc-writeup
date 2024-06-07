{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    reside = {
      url = "github:plietar/reside.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    malariasimulation = {
      url = "path:/home/pl2113/Work/Malaria/malariasimulation";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, reside, malariasimulation }:
    let
      overlay = reside.lib.rPackagesOverlay
        (pkgs: _: prev: {
          malariasimulation = prev.malariasimulation.overrideAttrs {
            # src = malariasimulation;
            src = pkgs.fetchFromGitHub {
              owner = "mrc-ide";
              repo = "malariasimulation";
              rev = "fdd7c68d9e299fe806d2273a207d284f02b22abe";
              hash = "sha256-Fxq7wr2cyPa+o7lM++MOfyf2lDfF/AoBWoFU7lxfreI=";
            };
          };
        });

      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [
          (_: prev: {
            R-patched = prev.R.overrideAttrs (old: {
              patches = old.patches ++ [ ./r-source.diff ];
            });
          })
          reside.overlays.default
          overlay
        ];
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        PKG_BUILD_EXTRA_FLAGS = "false";
        buildInputs = [
          pkgs.R-patched
          (pkgs.rstudio.override { R = pkgs.R-patched; })

          pkgs.rPackages.malariasimulation
          pkgs.rPackages.tidyverse
          pkgs.rPackages.devtools
          pkgs.rPackages.jointprof
          pkgs.rPackages.proffer
          pkgs.rPackages.zoo
          pkgs.rPackages.bench
          pkgs.pandoc
          pkgs.pprof
          pkgs.gperftools
          pkgs.pdf2svg
          pkgs.texlive.combined.scheme-full
          pkgs.nodejs
        ];
      };
    };
}
