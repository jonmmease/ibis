pkgs: _:
let
  mkPoetryEnv = { groups, python, extras ? [ "*" ] }: pkgs.poetry2nix.mkPoetryEnv {
    inherit python groups extras;
    projectDir = pkgs.gitignoreSource ../.;
    editablePackageSources = { ibis = pkgs.gitignoreSource ../ibis; };
    overrides = [
      (import ../poetry-overrides.nix)
      pkgs.poetry2nix.defaultPoetryOverrides
    ];
    preferWheels = true;
  };

  mkPoetryDevEnv = python: mkPoetryEnv {
    inherit python;
    groups = [ "dev" "docs" "test" ];
  };
in
{
  ibisTestingData = pkgs.fetchFromGitHub {
    name = "ibis-testing-data";
    owner = "ibis-project";
    repo = "testing-data";
    rev = "b26bd40cf29004372319df620c4bbe41420bb6f8";
    sha256 = "sha256-1fenQNQB+Q0pbb0cbK2S/UIwZDE4PXXG15MH3aVbyLU=";
  };

  ibisCore310 = pkgs.callPackage ./ibis-core.nix { python3 = pkgs.python310; };
  ibisCore311 = pkgs.callPackage ./ibis-core.nix { python3 = pkgs.python311; };
  ibisCore312 = pkgs.callPackage ./ibis-core.nix { python3 = pkgs.python312; };

  ibisLocal310 = pkgs.callPackage ./ibis-local.nix { python3 = pkgs.python310; };
  ibisLocal311 = pkgs.callPackage ./ibis-local.nix { python3 = pkgs.python311; };
  ibisLocal312 = pkgs.callPackage ./ibis-local.nix { python3 = pkgs.python312; };

  ibisDevEnv310 = mkPoetryDevEnv pkgs.python310;
  ibisDevEnv311 = mkPoetryDevEnv pkgs.python311;
  ibisDevEnv312 = mkPoetryDevEnv pkgs.python312;

  ibisSmallDevEnv = mkPoetryEnv {
    python = pkgs.python312;
    groups = [ "dev" ];
    extras = [ ];
  };

  quarto = pkgs.callPackage ./quarto { };

  changelog = pkgs.writeShellApplication {
    name = "changelog";
    runtimeInputs = [ pkgs.nodePackages.conventional-changelog-cli ];
    text = ''
      conventional-changelog --config ./.conventionalcommits.js "$@"
    '';
  };

  check-release-notes-spelling = pkgs.writeShellApplication {
    name = "check-release-notes-spelling";
    runtimeInputs = [ pkgs.changelog pkgs.coreutils pkgs.ibisSmallDevEnv ];
    text = ''
      tmp="$(mktemp)"
      changelog --release-count 1 --output-unreleased --outfile "$tmp"
      if ! codespell "$tmp"; then
        # cat -n to output line numbers
        cat -n "$tmp"
        exit 1
      fi
    '';
  };

  update-lock-files = pkgs.writeShellApplication {
    name = "update-lock-files";
    runtimeInputs = with pkgs; [ just poetry ];
    text = "just lock";
  };

  gen-examples = pkgs.writeShellApplication {
    name = "gen-examples";
    runtimeInputs = [
      pkgs.ibisDevEnv312
      (pkgs.rWrapper.override {
        packages = with pkgs.rPackages; [
          Lahman
          janitor
          palmerpenguins
          stringr
          tidyverse
        ];
      })
      pkgs.google-cloud-sdk
    ];

    text = ''
      python "$PWD/ibis/examples/gen_registry.py" "''${@}"
    '';
  };
}
