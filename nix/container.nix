{ pkgs, coder, tag }:
let
  inherit (pkgs) bash;
  etcPasswd = pkgs.writeTextDir "etc/passwd" ''
    coder:x:1000:1000::/home/coder:${bash}/bin/bash
  '';
  etcGroup = pkgs.writeTextDir "etc/group" ''
    coder:x:1000:coder
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "coder";
  tag = "v${tag}";

  fakeRootCommands = ''
    mkdir -p ./home/coder
    chown -R 1000:1000 ./home/coder

    mkdir tmp
    chmod 1777 tmp
  '';

  # cacert => validating https
  # libstdcxx5 => for postgres
  # bash/coreutils => nice for humans
  contents = [ coder etcPasswd etcGroup ] ++ (with pkgs; [ cacert libstdcxx5 bash coreutils ]);

  config = {
    Entrypoint = [ "${coder}/bin/coder" "server" ];
    Environment = {
      HOME = "/home/coder";
      SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    };
    Labels = {
      "org.opencontainers.image.title" = "Coder";
      "org.opencontainers.image.description" = "A tool for provisioning self-hosted development environments with Terraform.";
      "org.opencontainers.image.url" = "https://github.com/coder/coder";
      "org.opencontainers.image.source" = "https://github.com/coder/coder";
      "org.opencontainers.image.version" = tag;
      "org.opencontainers.image.licenses" = "AGPL-3.0";
    };
    User = "1000:1000";
    WorkingDir = "/home/coder";
  };
}
