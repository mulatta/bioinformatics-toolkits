# Extract documentation metadata for every package in the flake.
# Evaluated via `nix eval --json` by generate-package-docs.py.
# Uses x86_64-linux purely for meta evaluation; no build is performed, so the
# host platform is irrelevant.
let
  flake = builtins.getFlake (toString ./..);
  packages = builtins.attrNames flake.packages.x86_64-linux;

  formatLicense =
    l:
    if builtins.isAttrs l && l ? spdxId then
      l.spdxId
    else if builtins.isAttrs l && l ? shortName then
      l.shortName
    else if builtins.isAttrs l && l ? fullName then
      l.fullName
    else if builtins.isString l then
      l
    else
      "Check package";

  extractMetadata =
    pkg:
    let
      license = pkg.meta.license or null;
      licenseStr =
        if license == null then
          "Check package"
        else if builtins.isList license then
          builtins.concatStringsSep " / " (builtins.map formatLicense license)
        else
          formatLicense license;
    in
    {
      description = pkg.meta.description or "No description available";
      license = licenseStr;
      homepage = pkg.meta.homepage or null;
      mainProgram = pkg.meta.mainProgram or null;
      category = pkg.passthru.category or "Uncategorized";
      hideFromDocs = pkg.passthru.hideFromDocs or false;
    };

  results = builtins.listToAttrs (
    builtins.map (name: {
      inherit name;
      value =
        let
          pkg = flake.packages.x86_64-linux.${name} or null;
          metadata = if pkg != null then extractMetadata pkg else null;
        in
        # Hide only packages explicitly opting out via passthru.hideFromDocs.
        if metadata != null && !metadata.hideFromDocs then metadata else null;
    }) packages
  );
in
results
