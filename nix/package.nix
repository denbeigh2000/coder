{ pkgs
, version
, agpl ? false
, ...
}:

let
  inherit (pkgs) buildGo119Module lib zstd;
  inherit (pkgs.lib.licenses) agpl3Only;
  inherit (pkgs.stdenv) hostPlatform targetPlatform;

  frontend = (import ../site { inherit pkgs version; }).package;
  slim = import ./slim.nix { inherit pkgs version agpl; };

  common = import ./go-common.nix { inherit agpl version; };

  suffix = if targetPlatform.isWindows then ".exe" else "";

  enterpriseLicense = {
    fullName = "Coder Enterprise License";
    url = "https://github.com/coder/coder/blob/main/LICENSE.enterprise";
    free = false;
  };

  extraLicenses = if !agpl then [ enterpriseLicense ] else [ ];

  meta = {
    homepage = "https://www.coder.com";
    description = "An application for running development environments on your infrastructure";
    downloadPage = "https://github.com/coder/coder/releases";
    license = [ agpl3Only ] ++ extraLicenses;
  };
in
buildGo119Module {
  pname = "coder";
  inherit version meta;

  # Tests depend on having home directories etc.
  doCheck = false;

  src = ./..;

  inherit (common) ldflags vendorSha256 CGO_ENABLED;

  tags = [ "embed" ];

  # NOTE: We can't improve compilation re-use by building both enterprise
  # and non-enterprise here, because they both output binaries called "coder",
  # and one overwrites the other.
  preBuild = ''
    subPackages="${common.cmdPath}"
    rm -rf site/out
    mkdir -p site/out/bin
    cp -r ${frontend}/* site/out/
    cp ${slim.tarball}/coder-slim_${version}.tar.zst site/out/bin/coder.tar.zst
    cp ${slim.checksum}/coder.sha1 site/out/bin/coder.sha1
    goos=$(go env GOOS)
    goarch=$(go env GOARCH)
    goarm=$(go env GOARM)
  '';

  postInstall = ''
    OUT_FILE=$out/bin/coder_${version}_$goos_$goarch${suffix}
    find $out/bin -type f | xargs -I{} mv {} $OUT_FILE
    ${pkgs.openssl}/bin/openssl dgst -r -sha1 > $OUT_FILE.sha1
    ln -s $OUT_FILE $out/bin/coder
  '';
}
