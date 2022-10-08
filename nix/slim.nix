{ pkgs
, version
, agpl ? false
, ...
}:

let
  common = import ./go-common.nix { inherit agpl version; };

  mkBinary = { GOOS, GOARCH, GOARM ? "" }:
    let
      suffix = if GOOS == "windows" then ".exe" else "";
    in
    pkgs.buildGo119Module {
      pname = "coder-slim";
      inherit version;

      doCheck = false;

      src = ./..;

      inherit (common) ldflags vendorSha256 CGO_ENABLED;

      # NOTE: These get overridden if not manually specified in preBuild
      inherit GOOS GOARCH GOARM;


      preBuild = ''
        export GOOS="${GOOS}"
        export GOARCH="${GOARCH}"
        export GOARM="${GOARM}"
        subPackages="${common.cmdPath}"
      '';

      postInstall = ''
        FILE_NAME=coder-$GOOS-$GOARCH
        if [[ "$GOARM" != "" ]]
        then
          FILE_NAME="''${FILE_NAME}v$GOARM"
        fi
        OUT_FILE="$out/bin/''${FILE_NAME}${suffix}"
        find $out/bin -type f | xargs -I{} mv {} $OUT_FILE
        find $out -mindepth 2 -type d | xargs rm -rf
      '';
    };

  mkGroup = paths:
    pkgs.symlinkJoin {
      name = "coder-slim-all";
      inherit paths;
    };

  mkTarball = group:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "coder-tarball";
      inherit version;
      dontUnpack = true;
      dontInstall = true;
      dontFixup = true;

      buildInputs = [ pkgs.zstd pkgs.gnutar ];

      buildPhase = ''
        mkdir $out
        cd ${group}/bin
        tar \
          --use-compress-program "zstd -T0 -22 --ultra" \
          --create \
          --keep-old-files \
          --dereference \
          --file=$out/coder-slim_${version}.tar.zst \
          ./*
      '';
    };

  mkChecksum = group:
    pkgs.stdenvNoCC.mkDerivation {
      name = "slim-tarball-checksum";
      buildInputs = [ group ];

      dontUnpack = true;
      dontInstall = true;

      src = group;

      buildPhase = ''
        mkdir $out
        cd ${group}/bin
        ${pkgs.openssl}/bin/openssl dgst -r -sha1 coder* > $out/coder.sha1
      '';
    };

  group = mkGroup [
    (mkBinary { GOOS = "linux"; GOARCH = "amd64"; })
    (mkBinary { GOOS = "linux"; GOARCH = "arm64"; })
    (mkBinary { GOOS = "linux"; GOARCH = "arm"; GOARM = "7"; })
    (mkBinary { GOOS = "darwin"; GOARCH = "amd64"; })
    (mkBinary { GOOS = "darwin"; GOARCH = "arm64"; })
    (mkBinary { GOOS = "windows"; GOARCH = "amd64"; })
    (mkBinary { GOOS = "windows"; GOARCH = "arm64"; })
  ];
in
{
  checksum = mkChecksum group;
  tarball = mkTarball group;
}
