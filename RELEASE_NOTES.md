# Release notes

## 2.0.0 (2026-10-24)

The first release of `updatejdk.sh`. It is a new development, based on the ideas of `update_jdk` from the [bashberries](https://github.com/jonelo/bashberries) project. As the last version of `update_jdk` was 1.20.0, the version numbers continue at 2.0.0. It is licensed under the [Apache License 2.0](LICENSE).

From `update_jdk`, it takes the idea of downloading and unpacking JDKs and JREs without a package manager, updating their time zone data by Oracle's tzupdater, a stable symbolic link to the latest installation, keeping the downloaded archive, a dry run and a test by `java -version`. Unlike `update_jdk`, it looks up the releases by the Adoptium and foojay APIs rather than taking a URL, verifies every download by its checksum, knows which version is installed, and handles several distributions, architectures and operating systems.

### Actions
- `-l`, `--list [<variant>|<architecture>]`: lists the variants available for this platform, or for another architecture, or only the given variant, of both types unless one is given, e.g. `-l x64`, `-l 21` or `-l lts:jre:x64`.
  - Without `-a`, it lists the other distributions installed in the directory as well, each in a table of its own, like `-u` updates them. Installations by `-s` are named below the tables.
  - Installed variants are marked with `*` and shown with their version, their path and whether they are up to date, have an update available or are managed by a system package.
  - The `FORMATS` column shows the formats a variant comes in, like `tar.gz pkg`.
  - `-l -a` lists the distributions, or with a `<variant>`, `<architecture>`, `-o` or `-p` only those that have packages for it, e.g. `-l x64 -a`.
  - If a distribution has nothing for the platform, the message names the platforms it has, e.g. "there is no release of redhat for macOS x64, but with --os linux and aarch64, ppc64le or x64; --os windows and x64".
- `-i`, `--install <variant>`: installs a variant, or updates it if it is installed already.
- `-u`, `--update [<variant>]`: updates an installed variant, or all installed variants if `<variant>` is omitted, each from its own source. With `-a`, it updates those of that distribution only. If the variant is installed from another distribution only, the message names it.
- `-g`, `--get <variant>`: downloads and verifies the package of a variant without installing it, to the current directory or the one given by `-d`, along with a `.sha256` (or `.sha1`) file in the format of `shasum`. An existing package with the right checksum is not downloaded again, unless `-f` is given. No root privileges are needed.
- `-h`, `--help`; `-v`, `--version`, which prints the version with the copyright and the license, like GNU tools; `-C`, `--copyright`, which prints the full license notice.

### Variants
- A `<variant>` is `<feature-version>[:jdk|:jre][:<architecture>]`, e.g. `21`, `21:jre` or `21:jre:x64`. The type defaults to `jdk`, the architecture to the one of this machine.
- The `<feature-version>` is a number, `lts` for the most recent LTS release or `latest` for the most recent feature release.
- The architectures are `x64`, `aarch64`, `arm`, `ppc64le`, `s390x` and `riscv64`, with the aliases `x86_64`, `amd64` and `arm64`. Another architecture than this machine's allows e.g. to bundle the JREs for both Intel and Apple Silicon Macs with a universal app.

### Distributions and sources
- Eclipse Temurin is taken from the [Adoptium API](https://api.adoptium.net/), the default.
- `-a`, `--api <distribution>` takes another distribution from the [foojay Disco API](https://api.foojay.io/), e.g. `zulu`, `corretto`, `liberica`, `oracle`, `sap_machine`, `microsoft` or `redhat`. `temurin` and `adoptium` select the Adoptium API.
- `-s`, `--source <url>` installs any `.tar.gz` or `.tar.xz` from a URL as `custom-<version>-<type>`, with its SHA-256 taken from `-S`, `--sha256 <hash>` or from a `.sha256(.txt)` next to the archive. The archive must contain the feature version and type of the `<variant>`. `-u` skips these installations.
- `-g` takes `-o`, `--os <os>` (`mac`, `linux`, `alpine-linux`, `windows`) and `-p`, `--package <format>` (e.g. `tar.gz`, `zip`, `pkg`, `dmg`, `msi`), e.g. `-g 21:jre:x64 -o windows` for the Windows zip. The format defaults to `zip` on Windows and `tar.gz` otherwise. An unavailable format names the available ones. `-l` takes `-o` and `-p` as well.

### Verification
- Every download is verified by its checksum before it is used: the SHA-256 of the Adoptium API, of foojay, of the checksum file foojay points to, or of the `.sha256(.txt)` next to the package. Corretto's SHA-256 comes from its own `latest_sha256` endpoint, so its latest release is installed, which may be newer than the one foojay knows. Liberica only publishes a SHA-1, which is accepted with a note. Without any checksum, the script refuses to install.
- The size is verified as well, if the API provides it.
- If `jq` is not installed, like on macOS before 15, the script downloads a static jq 1.8.2 from GitHub for the run, verified by a SHA-256 in the script, on macOS and Linux for x64 and aarch64.
- A network error, or an HTTP error other than 4xx, stops the script with its cause, rather than being taken for a missing release or checksum.
- Archives with absolute paths or `..` are refused. The Java home is found by its `release` file, also in nested macOS bundles (Zulu) and in macOS archives without bundle structure (Liberica JRE).
- Every archive is checked to be for the requested architecture, by the `OS_ARCH` of its `release` file.
- Installations are made of the `.tar.gz` of a distribution, or of its `.tar.xz` if there is none, like for Red Hat's builds for Linux. On Linux, GNU tar needs `xz` for it.

### Installation
- Installations go to `/Library/Java/JavaVirtualMachines` on macOS and `/usr/lib/jvm` on Linux, or with `-d`, `--dir <path>` to a directory of your own.
- They are named `<distribution>-<version>.<type>` on macOS and `<distribution>-<version>-<type>` on Linux, e.g. `temurin-21.jdk` or `zulu-21-jre`. Those for another architecture than this machine's have it in their name, e.g. `temurin-21-x64.jre`, and can only be installed into a directory of your own.
- The privileges are checked before downloading. `sudo`, or `doas` if there is no `sudo`, is only used if the directory is not writable, and asks for the password right away.
- An old installation is moved aside and only removed once the new one is in place. If that fails, the old one is restored.
- Where an installation is from is recorded in `.updatejdk/<name>` in the directory. The script only replaces directories that contain a Temurin according to their `release` file, or that have such a record.
- On Linux, directories that belong to a system package (checked by `dpkg -S` or `rpm -qf`) are refused by `-i` and skipped by `-u`.

### Linux
- glibc and musl (Alpine) systems are detected.
- Missing commands are named all at once, together with the command that installs them by apt, dnf, yum, zypper or apk, like `sudo apt install curl`, with `doas` rather than `sudo` if only that is there, as on many Alpine systems.
- Installations in `/usr/lib/jvm` for this machine's architecture are registered with `update-alternatives` (`alternatives` on RHEL) for `java`, and for `javac` if it is a JDK, together with the links the distribution attaches to these groups (`keytool`, `jexec`, man pages, …), as far as the installation provides them. The priority equals the feature version, so the distribution's default stays selected in auto mode.

### Options
- `-f`, `--force`: downloads again, and with `-i` or `-u` installs again, even if the variant is up to date.
- `-k`, `--keep`: with `-i` or `-u`, keeps the downloaded archive in the current directory and prints its path at the end.
- `-L`, `--link [<path>]`: with `-i` or `-u`, creates or replaces the relative symbolic link `<path>/latest`, or `<path>` itself if it is neither a directory nor the one given by `-d` (which may not exist yet), or `latest` in the current directory without `<path>`, pointing to the Java home of the installed variant, e.g. `latest -> temurin-21.jdk/Contents/Home`. With `-u` and no `<variant>`, it points to the highest feature version that was updated, Temurin before other distributions, this machine's architecture before others. It is set even if the variant was up to date already. Anything else than a symbolic link at that path is left alone, and the script stops before downloading.
- `-n`, `--dry-run`: with `-i`, `-u` or `-g`, looks up the releases and shows what would be downloaded, installed, linked and updated, without changing anything.
- `-t`, `--test`: with `-i` or `-u`, runs `java -Xmx10m -version` of every variant concerned, even if it was up to date, and fails if it does not run.
- `-z`, `--tzupdater [<jar>]`: with `-i` or `-u`, updates the time zone data of every variant concerned to the latest IANA release by Oracle's `tzupdater.jar`, even if the variant was up to date already, and prints the resulting tzdata version. Without a path, it uses `tzupdater.jar` next to the script. Data that is up to date already counts as success, although the tzupdater reports it as an error.
- `-Z`, `--tzdata <url>`: with `-z`, the tzupdater takes the time zone data from `<url>` rather than from IANA.
- `-O`, `--oracle-vendor`: with `-z`, starts the tzupdater with `-Djava.vendor="Oracle Corporation"`, for tzupdaters that refuse a Java of another vendor.
- `-z` and `-t` skip an installation for another architecture with a warning if its `java` does not run on this machine.

### Tested on
- macOS 27.0.1 Golden Gate (Apple Silicon): Temurin, Zulu, Corretto, Liberica and SapMachine, Oracle by `-s`, another architecture (x64), and `-g` for Windows and Alpine Linux
- macOS 15.8.1 Sequoia (Intel, x64), in a directory of its own by `-d`: Temurin, Zulu, Corretto, Liberica and Oracle (`-a oracle`), installing, `-L`, and `-g` for another architecture (`25:jre:aarch64`)
- macOS 14 Sonoma 14.8.9 (Intel, x64), which has no `jq`, with the one the script downloads: Temurin, Zulu, Corretto, Liberica and Oracle's OpenJDK builds (`oracle_open_jdk`), with `-d` and `-L`
- Ubuntu 26.04 LTS, x64, this release in `/usr/lib/jvm` with `update-alternatives` and in a directory of its own by `-d`: Temurin, Zulu, Corretto, Liberica, SapMachine, Microsoft and Red Hat (`.tar.xz`), Oracle by `-s`, installing, updating, `-f`, `-k`, `-t`, `-L`, `-z`, another architecture (aarch64), and `-g` for Windows, macOS and Alpine Linux
- Ubuntu 26.04.1 LTS, aarch64, in a directory of its own by `-d`: Temurin, Zulu, Corretto, Liberica and Oracle (`-a oracle`), installing and `-l`, and the message with `sudo apt install curl` if `curl` is missing
- Ubuntu, Rocky Linux and Alpine Linux, x64, with Temurin, during development: installing, updating, `update-alternatives` and the coexistence with the Temurin RPM

This release has not been tested yet on Rocky Linux and Alpine Linux, or running on Linux for other architectures than x64 and aarch64.
