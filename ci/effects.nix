# Hercules-style effects consumed by nixbot.
{ nixpkgs }:
{ primaryRepo, ... }:
let
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  inherit (pkgs) lib;

  repoName = primaryRepo.name or "mulatta/bioinformatics-toolkits";
  repoUrl = primaryRepo.remoteHttpUrl or "https://github.com/${repoName}";
  mkRepoEffect =
    name: script:
    pkgs.runCommand "effect-${name}"
      {
        nativeBuildInputs = [
          pkgs.cacert
          pkgs.coreutils
          pkgs.gh
          pkgs.git
          pkgs.gnused
          pkgs.jq
          pkgs.nix
          pkgs.openssh
          pkgs.python3
        ];
        secretsMap = builtins.toJSON { git.type = "GitToken"; };
        HOME = "/build/home";
      }
      ''
        set -euo pipefail

        export NIX_CONFIG="experimental-features = nix-command flakes"
        mkdir -p "$HOME"

        token=$(jq -r '.git.data.token' "$HERCULES_CI_SECRETS_JSON")
        export GH_TOKEN="$token"
        remote=$(printf '%s' ${lib.escapeShellArg repoUrl} \
          | sed "s#https://#https://x-access-token:$token@#")

        git config --global user.email "nixbot@users.noreply.github.com"
        git config --global user.name "nixbot"
        git config --global safe.directory '*'

        git clone "$remote" repo
        cd repo
        ${script}
      '';

  pushBranchAndPr =
    {
      branch,
      commitMessage,
      title,
      body,
    }:
    ''
      git add -A
      git commit -m ${lib.escapeShellArg commitMessage}
      git push -f origin ${lib.escapeShellArg branch}

      if ! gh pr list \
        --head ${lib.escapeShellArg branch} \
        --state open \
        --json number \
        --jq '.[0].number // empty' \
        | grep -q .; then
        gh pr create \
          --base main \
          --head ${lib.escapeShellArg branch} \
          --title ${lib.escapeShellArg title} \
          --body ${lib.escapeShellArg body} \
          --label auto-merge
      fi
    '';

  updateReadme = mkRepoEffect "update-readme" ''
    branch=update/readme
    git switch -C "$branch" origin/main

    ./scripts/generate-package-docs.py

    if [ -z "$(git status --porcelain)" ]; then
      echo "README package docs already up to date"
      exit 0
    fi

    ${pushBranchAndPr {
      branch = "update/readme";
      commitMessage = "docs: regenerate README package list";
      title = "docs: regenerate README package list";
      body = "Automated README regeneration from package metadata.";
    }}
  '';

  updatePackages = mkRepoEffect "update-packages" ''
    nix run .#updater -- --pr
  '';
in
{
  onPush.default.outputs.effects = lib.optionalAttrs (primaryRepo.branch or null == "main") {
    update-readme = updateReadme;
  };

  onSchedule.update-readme = {
    when = {
      hour = 17;
      minute = 0;
    };
    outputs.effects.update-readme = updateReadme;
  };

  onSchedule.update-packages = {
    when = {
      hour = 18;
      minute = 0;
    };
    outputs.effects.update-packages = updatePackages;
  };
}
