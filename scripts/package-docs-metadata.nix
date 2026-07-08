# Extract documentation metadata from flake packages.
{ packages }:
let
  packageNames = builtins.attrNames packages;

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
          pkg = packages.${name} or null;
          metadata = if pkg != null then extractMetadata pkg else null;
        in
        # Hide only packages explicitly opting out via passthru.hideFromDocs.
        if metadata != null && !metadata.hideFromDocs then metadata else null;
    }) packageNames
  );
in
results
