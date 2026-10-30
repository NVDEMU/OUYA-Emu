# OUYA-Emu

**An experiment in building an emulator for a previously un-emulated gaming platform.**

OUYA-Emu is a dedicated OUYA-compatible Android environment for desktop systems. Rather than emulate the Tegra 3 hardware from transistor level, the project starts with an x86_64 Android guest and adds the OUYA-specific launcher, controller behavior, and framework compatibility needed to run original OUYA software.

The current Android base is the BlissOS **Typhoon x86_64** manifest branch. This is a development base, not a claim of full OUYA hardware emulation or game compatibility.

## Current implementation

- [x] Android x86_64 source/build base selected (BlissOS Typhoon).
- [x] OUYA launcher application source added.
- [x] Product integration fragment added to include the launcher in an Android system image.
- [ ] Build and boot a customized Android image.
- [ ] Verify ARM32 native-code translation on the selected guest image.
- [ ] Validate OUYA controller mappings and original game behavior.
- [ ] Implement missing OUYA SDK/framework services.

See [the OUYA guest setup guide](device/ouya/README.md) and [launcher README](packages/apps/OUYALauncher/README.md).

## Build base

The repository is a repo-manifest checkout. Initialize and sync the selected branch:

```bash
repo init -u https://github.com/NVDEMU/OUYA-Emu.git -b typhoon-x86 -m bliss.xml --git-lfs
repo sync -c --force-sync --no-tags --no-clone-bundle -j"$(nproc --all)" --optimized-fetch --prune
```

Follow the upstream BlissOS build prerequisites in its documentation. The source tree is large and needs a Linux build host with substantial disk space. A successful source sync is not the same as a successful OUYA image build.

## Experiment scope

This project aims to run original OUYA Android applications in a desktop-hosted Android environment and recreate the OUYA console experience. It does **not** currently emulate a physical Tegra 3 board, reproduce NVIDIA's proprietary GPU driver, or guarantee compatibility with every OUYA title.

Original firmware, APKs, game data, and other copyrighted materials are not distributed by this repository. Supply files you are legally entitled to use.

## License

See [LICENSE](LICENSE) for the inherited base repository license. New project files are provided under the same license unless otherwise noted.
