# updatejdk

`updatejdk.sh` lists, installs, updates and downloads JDKs and JREs on macOS and Linux: [Eclipse Temurin](https://adoptium.net/) by default, other distributions like Zulu, Corretto or Liberica on request, and any other `.tar.gz` or `.tar.xz` from a URL. It can also just download the packages for other operating systems and architectures, e.g. to bundle them with an application.

The binaries are taken from the [Adoptium API](https://api.adoptium.net/) or the [foojay Disco API](https://api.foojay.io/), verified by their checksum, and unpacked into the system's JVM directory. No package manager is needed, and you can keep several feature versions and distributions side by side and bring them all up to date with one command.

## Requirements

- `bash`, `curl`, `jq`, `tar`
- `jq` comes with macOS from version 15 on. If it is not installed, the script downloads jq 1.8.2 from [GitHub](https://github.com/jqlang/jq) for each run, verified by its SHA-256, on macOS and Linux for x64 and aarch64.
- `shasum` (macOS) or `sha256sum` and `sha1sum` (Linux)
- `xz` on Linux, only to install a `.tar.xz` like Red Hat's builds with GNU tar
- root privileges to write to the JVM directory, either by running as root or via `sudo`, or `doas` if there is no `sudo`, as on many Alpine systems

| Platform | Architectures | JVM directory |
|---|---|---|
| macOS | x64, aarch64 (Apple Silicon) | `/Library/Java/JavaVirtualMachines` |
| Linux (glibc) | x64, aarch64, arm, ppc64le, s390x, riscv64 | `/usr/lib/jvm` |
| Linux (musl, e.g. Alpine) | x64, aarch64 | `/usr/lib/jvm` |

Which feature versions exist for an architecture depends on what the distribution offers. `-l` shows it.

On Linux, install the requirements by
- `sudo apt install curl jq` on Debian and Ubuntu, where `curl` is not installed by default,
- `sudo dnf install curl jq` on RHEL, Rocky Linux and Fedora,
- `apk add bash curl jq` on Alpine.

`jq` may be left out, the script downloads it if it is missing (see above). If a command is missing, the script names the command that installs it.

## Installation

`updatejdk.sh` is a single file. Download it and make it executable:

```sh
curl -fsSL -o updatejdk.sh https://bit.ly/updatejdk
chmod +x updatejdk.sh
```

Report bugs and wishes as [issues](https://github.com/jonelo/updatejdk/issues).

## Usage

```
updatejdk.sh -l|--list [<variant>|<architecture>]
             [-a|--api [<distribution>]]
updatejdk.sh -i|--install <variant> [-a|--api <distribution>]
             [<options>]
updatejdk.sh -i|--install <variant> -s|--source <url>
             [-S|--sha256 <hash>] [<options>]
updatejdk.sh -u|--update [<variant>] [-a|--api <distribution>]
             [<options>]
updatejdk.sh -g|--get <variant> [-a|--api <distribution>]
             [-o|--os <os>] [-p|--package <format>] [-d <path>]
updatejdk.sh -h|--help
updatejdk.sh -v|--version
updatejdk.sh -C|--copyright
```

| Action | Description |
|---|---|
| `-l`, `--list [<variant>\|<architecture>]` | list all variants that are available for this platform, or for another architecture, or only the given variant, of both types unless one is given; installed ones are marked with `*` and shown with their path; without `-a`, also those of the other distributions installed, each in a table of its own, like `-u` updates them |
| `-i`, `--install <variant>` | install a variant, or update it if it is installed already |
| `-u`, `--update [<variant>]` | update an installed variant, or all installed variants if `<variant>` is omitted |
| `-g`, `--get <variant>` | download the package of a variant and its checksum, but do not install it, see [Downloading packages with -g](#downloading-packages-with--g) |

| Option | Description |
|---|---|
| `-a`, `--api <distribution>` | `temurin` or `adoptium` (the default), or a distribution of the foojay Disco API, see [Other distributions](#other-distributions). `-l -a` without a distribution lists all of them, `-l x64 -a` only those for x64 |
| `-C`, `--copyright` | print the copyright and the license and exit |
| `-d`, `--dir <path>` | use another JVM directory instead of the default, with `-g` the directory to save the package to |
| `-f`, `--force` | download again, and with `-i` or `-u` install again, even if the variant is up to date |
| `-h`, `--help` | print the help and exit |
| `-k`, `--keep` | with `-i` or `-u`, keep the downloaded archive in the current directory, its path is printed at the end |
| `-L`, `--link [<path>]` | with `-i` or `-u`, create or replace a relative symbolic link to the installed variant, see [A stable path with -L](#a-stable-path-with--l) |
| `-n`, `--dry-run` | with `-i`, `-u` or `-g`, look up the releases and show what would be done, but do not change anything |
| `-o`, `--os <os>` | with `-l` or `-g`, the operating system: `mac`, `linux`, `alpine-linux` or `windows`, defaults to this one |
| `-O`, `--oracle-vendor` | with `-z`, start the tzupdater with `java.vendor` "Oracle Corporation", for tzupdaters that refuse a Java of another vendor |
| `-p`, `--package <format>` | with `-l` or `-g`, the format of the package like `tar.gz`, `zip`, `pkg`, `dmg` or `msi`, defaults to `zip` on Windows and `tar.gz` otherwise |
| `-s`, `--source <url>` | with `-i`, install the `.tar.gz` or `.tar.xz` at `<url>`, see [Any tarball with -s](#any-tarball-with--s) |
| `-S`, `--sha256 <hash>` | with `-s`, the SHA-256 of the archive |
| `-t`, `--test` | with `-i` or `-u`, run `java -Xmx10m -version` of the variants concerned, even if they were up to date; the script fails if it does not run |
| `-v`, `--version` | print the version, the copyright and the license and exit |
| `-z`, `--tzupdater [<jar>]` | with `-i` or `-u`, update the time zone data of the installed variants by Oracle's `tzupdater.jar`, see [Time zone data](#time-zone-data) |
| `-Z`, `--tzdata <url>` | with `-z`, take the time zone data from `<url>` rather than from IANA |

A `<variant>` is `<feature-version>[:jdk|:jre][:<architecture>]`. The type defaults to `jdk`, the architecture to the one of this machine, see [Other architectures](#other-architectures). The `<feature-version>` is either:
- a number like `21`,
- `lts` for the most recent LTS release, or
- `latest` for the most recent feature release.

### Examples

```sh
updatejdk.sh -l            # what is available, what is installed?
updatejdk.sh -l 21         # the same for Java 21 only, JDK and JRE
updatejdk.sh -l lts:jre:x64   # the JRE of the most recent LTS for x64
updatejdk.sh -l -a         # which distributions are there?
updatejdk.sh -l -a zulu    # what is available of Azul Zulu?
updatejdk.sh -l -d ~/jvm   # everything installed in ~/jvm, by distribution
updatejdk.sh -i lts        # install the most recent LTS JDK
updatejdk.sh -i 21:jre     # install the Java 21 JRE
updatejdk.sh -i 21 -a corretto   # install the Amazon Corretto 21 JDK
updatejdk.sh -i 21 -k      # install the Java 21 JDK and keep the archive
updatejdk.sh -u -n         # which updates are there?
updatejdk.sh -u            # update everything that is installed
updatejdk.sh -u -t         # ... and check that every java runs
updatejdk.sh -u 21         # update the Temurin 21 JDK only
updatejdk.sh -u -a zulu    # update the Zulu installations only
updatejdk.sh -d ~/jvm -i 25   # install into a directory of your own, no root needed
updatejdk.sh -d ~/jvm -i lts -L ~/jvm   # ... and point ~/jvm/latest to it
updatejdk.sh -i 25 -s https://download.oracle.com/java/25/latest/jdk-25_macos-aarch64_bin.tar.gz
updatejdk.sh -d build/jre -i 21:jre:x64       # the x64 JRE, e.g. for a universal macOS app
updatejdk.sh -u -z ~/Downloads/tzupdater.jar   # update everything, including the time zone data
```

Sample output of `-l`:

```
Asking https://api.adoptium.net/v3 for Temurin releases for macOS aarch64 ...

  VERSION   TYPE  LATEST               FORMATS          INSTALLED
  --------- ----- -------------------- ---------------- ---------
* 21 LTS    jdk   jdk-21.0.13+9        tar.gz pkg       21.0.13+9-LTS (up to date) /Library/Java/JavaVirtualMachines/temurin-21.jdk
  21 LTS    jre   jdk-21.0.13+9        tar.gz pkg
  25 LTS    jdk   jdk-25.0.5+11        tar.gz pkg
  ...

Asking https://api.foojay.io/disco/v3.0 for zulu releases for macOS aarch64 ...

  VERSION   TYPE  LATEST               FORMATS          INSTALLED
  --------- ----- -------------------- ---------------- ---------
  ...
* 21 LTS    jdk   21.0.12.1+1          dmg tar.gz zip   21.0.12.1+1-LTS (up to date) /Library/Java/JavaVirtualMachines/zulu-21.jdk
  21 LTS    jre   21.0.12.1+1          dmg tar.gz zip
  ...

* = installed in /Library/Java/JavaVirtualMachines
```

Without `-a`, `-l` lists Temurin and every other distribution that is installed in the directory, each in a table of its own, just as `-u` updates them all.

## What it does

1. It looks up the latest release of the variant through the API. If the installed release is the same, it stops here (unless `-f` is given). With `-n`, it shows what it would download and install, and stops as well.
2. It checks the privileges for the JVM directory **before** downloading. If root is needed, `sudo` (or `doas`) asks for the password right away. Without either, the script stops with a hint to run it as root. `doas` asks again for each step unless `persist` is set in `doas.conf`.
3. It downloads the archive, verifies its checksum and size, refuses archives with absolute paths or `..`, and unpacks it.
4. It moves the old installation aside, puts the new one in place, and removes the old one only after that succeeded.
5. With `-t`, it runs `java -Xmx10m -version` of the installation.

Installations are named:
- `<distribution>-<version>.<type>` on macOS, e.g. `temurin-21.jdk`, `zulu-21.jre`
- `<distribution>-<version>-<type>` on Linux, e.g. `temurin-21-jdk`, `corretto-21-jdk`

Where each installation is from is recorded in `.updatejdk/<name>` in the JVM directory. The script only ever replaces a directory that contains a Temurin according to its `release` file, or that has such a record.

## Other distributions

With `-a <distribution>`, `-l`, `-i` and `-u` use the [foojay Disco API](https://api.foojay.io/) instead of Adoptium. It knows about 30 distributions, among them `zulu`, `corretto`, `liberica`, `oracle`, `sap_machine`, `microsoft`, `graalvm_community`, `semeru` and `dragonwell`. `-l -a` without a name lists all of them, with a note on those that are no longer maintained. Given a `<variant>` or `<architecture>`, `--os` or `--package`, it lists only the distributions that have packages for it, e.g. `-l x64 -a` for this operating system on x64, `-l 21:jre -a --os windows` or `-l -a --os linux --package tar.xz`. `-a temurin` and `-a adoptium` always use the Adoptium API.

`-u` without a `<variant>` updates all installations, each from its own source. With `-a`, it updates those of that distribution only. `-u <variant>` updates the variant of the distribution given by `-a`, Temurin by default.

The script requires a checksum, but not every distribution publishes one in the same way:

| Distribution | Checksum |
|---|---|
| Temurin | SHA-256 by the Adoptium API |
| Zulu | SHA-256 by the foojay Disco API |
| Oracle, Microsoft, SapMachine | SHA-256 from the file the foojay Disco API points to, or the `.sha256(.txt)` next to the archive |
| Corretto | SHA-256 by Corretto's own `latest_sha256` endpoint. As this covers the latest release only, the script downloads Corretto's latest release, which may be newer than the one foojay knows |
| Liberica | SHA-1 only, the script says so |

Without any checksum, the script refuses to install.

An installation is made of the `.tar.gz` of a distribution, or of its `.tar.xz` if there is no `.tar.gz`, like for Red Hat's builds for Linux. To unpack a `.tar.xz`, GNU tar needs the `xz` command, the script checks for it before downloading. BusyBox and macOS tar unpack it by themselves.

## Any tarball with -s

`-s <url>` installs any `.tar.gz` or `.tar.xz` that contains a JDK or JRE, e.g. from [jdk.java.net](https://jdk.java.net/) or Oracle:
- The SHA-256 is taken from `<url>.sha256`, `<url>.sha256.txt` or the `.sha256.txt` without `.tar.gz`. If there is none, pass it by `-S`, `--sha256 <hash>`.
- The `<variant>` must give the feature version as a number, e.g. `-i 25` or `-i 25:jre`. After unpacking, the script checks that the archive contains exactly that, according to its `release` file and whether it has a `javac`.
- The installation is named `custom-<version>-<type>` (`custom-<version>.<type>` on macOS).
- Running the same command again does nothing if the checksum has not changed. `-u` skips these installations, because a URL does not tell whether there is something newer.

## Other architectures

A variant can name another architecture than the one of this machine, e.g. to bundle the JREs for both Intel and Apple Silicon Macs with a universal app:

```sh
updatejdk.sh -d build/jre -i 21:jre:aarch64   # -> build/jre/temurin-21.jre on Apple Silicon
updatejdk.sh -d build/jre -i 21:jre:x64       # -> build/jre/temurin-21-x64.jre
updatejdk.sh -d build/jre -u                  # updates both later
```

- `<architecture>` is one of `x64`, `aarch64`, `arm`, `ppc64le`, `s390x` and `riscv64`. `x86_64` and `amd64` are accepted for `x64`, `arm64` for `aarch64`. The type may be omitted, as in `21:x64`.
- Only installations for another architecture have it in their name, e.g. `temurin-21-x64.jre` or `zulu-21-aarch64-jdk`. Those of this machine's architecture keep their usual name.
- Another architecture can only be installed into a directory of your own by `-d`, so that it does not get in the way of `java_home` or `update-alternatives`. It is not registered with `update-alternatives` either.
- After unpacking, the script checks that the archive is for the requested architecture, according to the `OS_ARCH` of its `release` file. This also applies to `-s`.
- `-z` and `-t` need to run the `java` of the installation. If it does not run on this machine, e.g. an x64 Java on Apple Silicon without Rosetta 2, the script skips both for it with a warning.
- `-l x64` shows what is available for x64 and marks the x64 installations. `-l 21:x64` or `-l 21:jre:x64` narrows it down to a variant.
- With `-u` and no `<variant>`, `-L` prefers this machine's architecture.

## Downloading packages with -g

`-g <variant>` downloads the package of a variant, verifies it like an installation, and saves it with its checksum to the current directory, or to the one given by `-d`. Nothing is installed, so no root privileges are needed, and any operating system and architecture can be chosen, e.g. to bundle JREs with an application:

```sh
updatejdk.sh -g 21:jre:x64 --os windows                # OpenJDK21U-jre_x64_windows_hotspot_….zip
updatejdk.sh -g 21:jre:x64 --os windows --package msi   # the installer instead
updatejdk.sh -g 21:jre --package pkg -d ~/Downloads     # the macOS installer
updatejdk.sh -g 21:jre:x64 --os linux -a zulu          # Zulu for Linux x64
```

- `--os` is `mac`, `linux`, `alpine-linux` or `windows`, this machine's by default.
- `--package` defaults to the archive of the operating system: `zip` on Windows, `tar.gz` otherwise. Which formats there are, `-l` shows in its `FORMATS` column, also for another operating system, e.g. `-l 21 --os windows`. With `--package`, `-l` lists only the variants that come in it. Temurin offers the archive and an installer (`pkg` on macOS, `msi` on Windows), foojay distributions may offer more, like `dmg`, `deb` or `rpm`.
- Next to the package, the script writes `<package>.sha256` (`.sha1` for Liberica) in the format of `shasum` and `sha256sum`, so you can check it later by `shasum -a 256 -c <package>.sha256`.
- If the package is there already with the right checksum, it is not downloaded again, unless `-f` is given. `-n` shows what would be downloaded.

## Using an installed JDK

**macOS**

```sh
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

**Linux**

```sh
export JAVA_HOME=/usr/lib/jvm/temurin-21-jdk
```

On Linux, installations in the default directory `/usr/lib/jvm` are also registered with `update-alternatives` (`alternatives` on RHEL) for `java`, and for `javac` if it is a JDK.
- The links the distribution attaches to these groups (`keytool`, `jexec`, man pages, …) are registered as well, as far as the installation provides them. The script prints the ones it can't provide.
- The priority equals the feature version (e.g. 21). This is deliberately low, so the distribution's default stays selected in auto mode. To use an installation system-wide, select it explicitly:

```sh
sudo update-alternatives --config java
```

### A stable path with -L

With `-L [<path>]`, the script creates a symbolic link after `-i` or `-u`, so that `JAVA_HOME` can stay the same across updates:
- If `<path>` is a directory, or the directory given by `-d` even if it does not exist yet, the link is `<path>/latest`. Otherwise `<path>` is the name of the link itself, e.g. `-L ~/jvm/java21`.
- Without `<path>`, the link is `latest` in the current directory.
- An existing symbolic link is replaced. Anything else that exists at that path is left alone, and the script stops before downloading.
- The link points to the Java home of the variant: the installation directory on Linux, its `Contents/Home` on macOS. It is relative, e.g. `latest -> temurin-21.jdk/Contents/Home`, so it stays valid if the link and the installation are moved together.
- With `-u` and no `<variant>`, it points to the highest feature version that was updated: Temurin before other distributions, the JDK before the JRE.
- The link is set even if the variant was up to date already.

```sh
updatejdk.sh -i lts -L ~/jvm
export JAVA_HOME=~/jvm/latest

cd ~/jvm && updatejdk.sh -i lts -L   # the same, from within ~/jvm
```

## Time zone data

A Java release ships the time zone data that was current when it was built. To get newer data without waiting for the next release, pass Oracle's tzupdater with `-z`:
- Download it from [Oracle](https://www.oracle.com/java/technologies/javase-tzupdater-downloads.html). Its license does not allow redistribution, so the script does not download it itself.
- `-z` without a path uses `tzupdater.jar` next to the script.
- After each `-i` or `-u`, the script runs `java -jar tzupdater.jar -l` with the `java` of every variant concerned, even if the variant was up to date already. This fetches the latest release from [IANA](https://www.iana.org/time-zones), so access to iana.org is needed.
- With `-Z <url>`, the tzupdater takes the data from `<url>` instead, e.g. a mirror or a `file://` URL of a `tzdata*.tar.gz`.
- With `-O`, the script starts the tzupdater with `-Djava.vendor="Oracle Corporation"`, for tzupdater versions that refuse a Java of another vendor.
- An update replaces `lib/tzdb.dat` with the one of the new release, so pass `-z` on every `-u`.

## Coexistence with package managers

On Linux, the script refuses to touch a directory that belongs to a system package (checked by `dpkg -S` or `rpm -qf`).
- The Temurin RPM installs to `/usr/lib/jvm/java-21-temurin-jdk` and adds a symlink `temurin-21-jdk`, which is exactly the script's own name for that version. `-l` shows such variants as `managed by package <name>`.
- `-i` refuses to replace them.
- `-u` skips them, because they are updated by `dnf`/`apt`.

## Tested on

- macOS (Apple Silicon), including Zulu, Corretto, Liberica, SapMachine and Oracle by `-s`
- macOS 15.8.1 Sequoia (Intel, x64), including Zulu, Corretto, Liberica and Oracle
- Ubuntu 26.04 LTS, x64, including `update-alternatives`, Zulu, Corretto, Liberica, SapMachine, Microsoft, Red Hat and Oracle by `-s`
- Ubuntu 26.04.1 LTS, aarch64, including Zulu, Corretto, Liberica and Oracle
- Rocky Linux, x64
- Alpine Linux, x64

On Rocky Linux and Alpine Linux, only Temurin has been tested.

## Release notes

See [RELEASE_NOTES.md](RELEASE_NOTES.md).

## Author and license

Copyright (c) 2026 Johann N. Löfflmann, <https://johann.loefflmann.net>

Licensed under the [Apache License 2.0](LICENSE). `-C` prints the copyright and the license notice.

## Trademarks

`updatejdk` is an independent project. It is not affiliated with, endorsed or sponsored by Oracle, the Eclipse Foundation or any vendor of the distributions it installs. It only downloads their published builds.

Oracle, Java and OpenJDK are trademarks or registered trademarks of Oracle and/or its affiliates. Eclipse Temurin and Adoptium are trademarks of the Eclipse Foundation. Other names may be trademarks of their respective owners.
