# glib-ndk-builder

Cross-compile **[GLib](https://gitlab.gnome.org/GNOME/glib)** + dependencies (libffi, gettext) for **Android aarch64** using the **Android NDK** Clang toolchain.

## Output

| File | Description |
|---|---|
| `glib-<version>-aarch64-linux-android.tar.gz` | GLib + libffi + libintl, installed under a single prefix |

Download from [GitHub Pages](https://zishuowang696.github.io/glib-ndk-builder/):

```bash
wget https://zishuowang696.github.io/glib-ndk-builder/glib-2.82.5-aarch64-linux-android.tar.gz
tar xzf glib-2.82.5-aarch64-linux-android.tar.gz -C /path/to/project/jni/prefix
```

## Components

| Component | Version | Purpose |
|---|---|---|
| GLib | 2.82.5 | Core utility library (GObject, GIO, GThread) |
| libffi | 3.4.7 | Foreign function interface (GObject dependency) |
| gettext (libintl) | 0.23.1 | Internationalization (optional, enables NLS) |
| NDK | r28 | Cross-compilation toolchain |

## Build locally

Requires: `wget`, `unzip`, `make`, `python3-pip`, `ninja-build`, `pkg-config`

```bash
git clone https://github.com/zishuowang696/glib-ndk-builder.git
cd glib-ndk-builder
bash build-glib.sh
```

The tarball will be in `output/`.

## Target

- Architecture: aarch64 (arm64-v8a)
- Android API level: 21
- C library: bionic (Android's native libc)
- Toolchain: NDK r28 LLVM/Clang
