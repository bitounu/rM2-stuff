# Toltec package for rM2-stuff Yaft

This directory provides a ready-to-use Toltec `package` recipe that builds
Yaft from the `rM2-stuff` repository. Copy or symlink this folder into the
`package/` directory of the Toltec tree and build it with `opkgbuild`:

```sh
$ ln -s /path/to/rM2-stuff/tools/toltec/yaft /path/to/toltec/package/yaft-rm2-stuff
$ cd /path/to/toltec
$ JUST_BUILD_DIR=build opkgbuild yaft-rm2-stuff
```

The recipe relies on the `release-toltec` CMake preset that is shipped with
`rM2-stuff`. It installs the `yaft` binary, its `yaft_reader` helper, the
compiled terminfo database and Draft launcher assets into `/opt`, matching
Toltec's packaging conventions.
