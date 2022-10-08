{ pkgs, drpc }:

with pkgs; let
  drpc-bin = drpc.defaultPackage.${pkgs.stdenv.hostPlatform.system};

  common = [
    bash
    bat
    exa
    getopt
    git
    jq
    openssh
    openssl
    ripgrep
    typos
    zip
    zstd
  ];

  backend = [
    drpc-bin
    go-migrate
    go_1_19
    golangci-lint
    gopls
    gotestsum
    nfpm
    postgresql
    protoc-gen-go
    shellcheck
    shfmt
    sqlc
    terraform
  ];

  frontend = [
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodejs
    yarn
  ];
in
{
  frontend = common ++ frontend;
  backend = common ++ backend;
  all = common ++ frontend ++ backend;
}
