# Platform fix: iOS deployment target 15.0

cactus + ditto_live both require iOS 15.0+. Default Flutter scaffold sets
the deployment target to 12.0, which fails at link time on these libraries.
This commit bumps the Podfile minimum and the Xcode project target.

Original commit:
- qypvoztu (fix(ios): bump deployment target to 15.0 for cactus + ditto_live)

Kept as its own commit because platform deploy-targets are a "set once,
forget" thing that doesn't belong mixed with feature work.
