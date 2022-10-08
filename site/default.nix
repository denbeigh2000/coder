{ pkgs, version, ... }:

let
  inherit (pkgs) nodePackages;
  inherit (pkgs.stdenv) mkDerivation;
  inherit (pkgs.yarn2nix-moretea) importOfflineCache mkYarnNix fixup_yarn_lock linkNodeModulesHook;

  # Mostly cribbed from yarn2nix/mkYarnModules, except using package.json
  # directly instead of via a workspace.
  # https://github.com/NixOS/nixpkgs/blob/c8554deb5003c55a197effbad4b515420415e7b4/pkgs/development/tools/yarn2nix-moretea/yarn2nix/default.nix#L64
  modules =
    let
      yarnLock = ./yarn.lock;
      yarnNix = mkYarnNix { inherit yarnLock; };
      offlineCache = importOfflineCache yarnNix;

    in
    mkDerivation {
      pname = "coder-site-deps";
      inherit version;

      src = ./.;

      # NOTE: Skipping installation avoids needing to provide the
      # dependencies from the below URL as build inputs to compile some C
      # programs. It's unclear why this dependency is required, but the
      # web app seems to build and run without them just fine.
      # https://www.npmjs.com/package/canvas#user-content-compiling
      dontInstall = true;
      # Avoid this because otherwise nix tries to patch all the canvas binaries
      # of the wrong ELF type.
      dontFixup = true;
      buildInputs = with pkgs; [ yarn nodejs git ];
      nativeBuildInputs = with pkgs; [ yarn nodejs git ];

      configurePhase = ''
        export HOME="$PWD/yarn_home"
        # https://github.com/NixOS/nixpkgs/blob/6221ec58af5b7b1b9a71d6ceacf1135285a10263/pkgs/development/node-packages/overrides.nix#L324-L329
        export npm_config_nodedir=${pkgs.nodejs}
      '';

      buildPhase = ''
        chmod +w ./yarn.lock
        yarn config --offline set yarn-offline-mirror ${offlineCache}

        ${fixup_yarn_lock}/bin/fixup_yarn_lock yarn.lock
        chmod -w ./yarn.lock

        NEW_PATH="$PWD/node_modules/.bin:$PATH"
        PATH=$NEW_PATH ${pkgs.yarn}/bin/yarn install --frozen-lockfile --verbose --ignore-scripts

        mkdir $out
        mv node_modules $out
        patchShebangs $out
      '';
    };

  package = mkDerivation {
    pname = "coder-site";
    inherit version;
    dontInstall = true;

    src = ./.;

    buildPhase = ''
      ln -s ${modules}/node_modules node_modules
      export PATH="$PWD/node_modules/.bin:$PATH"
      echo $PATH
      # Because this is kept in source control, copying it from the source folder
      # keeps nix's read-only permissions.
      chmod -R ugo+rw out
      ${pkgs.yarn}/bin/yarn run build

      mkdir $out
      mv out/* $out/
    '';
  };

in
{
  inherit package;
  shellHook = ''
    node_modules=${modules}/node_modules
    pushd $(git rev-parse --show-toplevel)/site >/dev/null
    ${linkNodeModulesHook}
    popd >/dev/null
  '';
}
