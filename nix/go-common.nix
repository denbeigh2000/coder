{ version, agpl }:

let
  versionTag = "github.com/coder/coder/buildinfo.tag=${version}";

in
{
  # NOTE: This must change when we make update our dependencies, so nix can
  # invalidate its' cache.
  vendorSha256 = "sha256-2JJQQcZ9OTLMxdd40z0uD+MY4JtbweE1VYSH/p6ORD4=";

  ldflags = "-s -w -X '${versionTag}'";
  cmdPath = if agpl then "./cmd/coder" else "./enterprise/cmd/coder";

  GCO_ENABLED = 0;
}
