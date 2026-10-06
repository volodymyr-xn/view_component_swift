import ViewComponent

/// Collects the stylesheets and scripts sitting next to each component's
/// template.
///
/// This lives in the example, not the library: view-component-swift does no
/// asset pipeline work. It only needs `colocatedAssets`, which the build tool
/// plugin fills in from what it found next to the sidecar — so the manifest
/// costs nothing at run time beyond joining the lists.
func assetManifest(_ components: [any ViewComponent.Type]) -> [String] {
    var assets: [String] = []

    for component in components {
        for asset in component.colocatedAssets where !assets.contains(asset) {
            assets.append(asset)
        }
    }

    return assets
}
