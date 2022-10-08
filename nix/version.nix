{ self, pkgs, tag }:

# NOTE: The standard release tooling uses git state to determine the current
# tag/commit hash, and returns a tag that varies if the repo is precisely at a
# tag.
# Because we are only able to get the current commit if state is clean, we
# depend on the tag being hardcoded in flake.nix, and only return:
#  - vX.Y.Z-[sha] (if git is clean)
#  - vX.Y.Z-devel (if git is dirty)

let
  inherit (builtins) substring;

  # NOTE: One can't currently access a git tag from flakes.
  sha = substring 0 7 self.rev or "devel";
  version = if sha == "devel" then "${tag}+devel" else "${tag}+${sha}";
in
{
  inherit tag sha version;
}
