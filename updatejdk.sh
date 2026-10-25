#!/bin/bash
#
# Lists, installs, updates and downloads JDKs and JREs on macOS and Linux.
# Eclipse Temurin is taken from the Adoptium API, other distributions like
# Zulu, Corretto or Liberica from the foojay Disco API, any other tarball from
# a URL. The binaries are verified by their checksums and unpacked into the
# system's JVM directory
# (/Library/Java/JavaVirtualMachines on macOS, /usr/lib/jvm on Linux).
# On Linux, glibc and musl (Alpine) systems are supported, and installations
# in the default directory are registered with update-alternatives.
#
# https://github.com/jonelo/updatejdk
#
# Copyright (c) 2026 Johann N. Löfflmann, <https://johann.loefflmann.net>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

VERSION="2.0.0"
COPYRIGHT="Copyright (c) 2026 Johann N. Löfflmann, <https://johann.loefflmann.net>"
HOME_PAGE="https://github.com/jonelo/updatejdk"
ADOPTIUM_API="https://api.adoptium.net/v3"
FOOJAY_API="https://api.foojay.io/disco/v3.0"
JVM_IMPL="hotspot"
VENDOR="eclipse"
ARCHS="x64 aarch64 arm ppc64le s390x riscv64"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TZUPDATER_URL="https://www.oracle.com/java/technologies/javase-tzupdater-downloads.html"
# fetched if jq is not installed, like on macOS before 15
JQ_VERSION="1.8.2"
JQ_URL="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}"


#---------------------------------------------------------------
function usage {
#---------------------------------------------------------------
local name
name="$(basename "$0")"
# continuation lines of the usage start below the first option
local pad
pad="$(printf "%*s" $((${#name} + 8)) "")"
cat << EOL
Usage: ${name} -l|--list [<variant>|<architecture>]
${pad}[-a|--api [<distribution>]]
       ${name} -i|--install <variant> [-a|--api <distribution>]
${pad}[<options>]
       ${name} -i|--install <variant> -s|--source <url>
${pad}[-S|--sha256 <hash>] [<options>]
       ${name} -u|--update [<variant>] [-a|--api <distribution>]
${pad}[<options>]
       ${name} -g|--get <variant> [-a|--api <distribution>]
${pad}[-o|--os <os>] [-p|--package <format>] [-d <path>]
       ${name} -h|--help
       ${name} -v|--version
       ${name} -C|--copyright

Lists, installs, updates and downloads JDKs and JREs of Eclipse Temurin and
other distributions.

Actions:
  -l, --list [<variant>|<architecture>]
                           list all variants that are available for this
                           platform, or for the architecture, or only the
                           variant, of both types unless one is given,
                           installed ones are marked with * and shown with
                           their path, without -a also the variants of the
                           other distributions installed, like -u
  -i, --install <variant>  install a variant, or update it if it is
                           installed already
  -u, --update [<variant>] update an installed variant, or all installed
                           variants if <variant> is omitted
  -g, --get <variant>      download the package of a variant and its checksum
                           to the current directory or the one given by -d,
                           but do not install it

Options:
  -a, --api <distribution> temurin or adoptium (the default) for Eclipse
                           Temurin by the Adoptium API, or a distribution of
                           the foojay Disco API like zulu, corretto,
                           liberica, oracle, sap_machine or microsoft,
                           with -l, and with -u and no <variant>, only that
                           distribution, with -l and no <distribution> list
                           them all, or those for the <variant>,
                           <architecture>, -o and -p of -l
  -C, --copyright          print the copyright and the license and exit
  -d, --dir <path>         the JVM directory, defaults to
                           /Library/Java/JavaVirtualMachines on macOS and
                           /usr/lib/jvm on Linux, with -g the directory to
                           save the package to
  -f, --force              download again, and with -i or -u install again,
                           even if the variant is up to date
  -h, --help               print this help and exit
  -k, --keep               with -i or -u, keep the downloaded archive in
                           the current directory
  -L, --link [<path>]      with -i or -u, create or replace the relative
                           symbolic link <path>/latest, or <path> itself if
                           it is neither a directory nor the one of -d, or
                           latest in the current directory without <path>,
                           pointing to the installed variant (to its
                           Contents/Home on macOS), with -u and no <variant>
                           to the highest feature version
  -n, --dry-run            with -i, -u or -g, look up the releases and show what
                           would be done, but do not change anything
  -o, --os <os>            with -l or -g, the operating system: mac, linux,
                           alpine-linux or windows, defaults to this one
  -O, --oracle-vendor      with -z, start the tzupdater with java.vendor
                           "Oracle Corporation", for tzupdaters that refuse
                           a Java of another vendor
  -p, --package <format>   with -l or -g, the format of the package like
                           tar.gz, zip, pkg, dmg or msi, defaults to zip on
                           windows and tar.gz otherwise, -l shows which
                           formats there are
  -s, --source <url>       with -i, install the .tar.gz or .tar.xz at <url>,
                           the <variant> must name its feature version and
                           type
  -S, --sha256 <hash>      with -s, the SHA-256 of the archive, required if
                           there is no <url>.sha256 or <url>.sha256.txt
  -t, --test               with -i or -u, test the installed variants by
                           java -version, even if they were up to date
  -v, --version            print the version, the copyright and the license
                           and exit
  -z, --tzupdater [<jar>]  with -i or -u, update the time zone data of the
                           installed variants to the latest IANA release by
                           Oracle's tzupdater.jar, which defaults to
                           tzupdater.jar next to this script
  -Z, --tzdata <url>       with -z, take the time zone data from <url>
                           rather than from IANA

On Linux, variants installed in /usr/lib/jvm are registered with
update-alternatives at a low priority, select one by
update-alternatives --config java

<variant> is <feature-version>[:jdk|:jre][:<architecture>], the type
defaults to jdk, the architecture to the one of this machine.
<feature-version> is a number like 21, or "lts" for the most recent LTS
release, or "latest" for the most recent feature release.
<architecture> is one of x64 (or x86_64, amd64), aarch64 (or arm64), arm,
ppc64le, s390x and riscv64. Another one than this machine's can only be
installed into a directory of your own by -d, its name contains the
architecture, like temurin-21-x64.jre.

Examples:
  $(basename "$0") -l
  $(basename "$0") -l -a
  $(basename "$0") -l x64 -a -o windows
  $(basename "$0") -l -a zulu
  $(basename "$0") -i lts
  $(basename "$0") -i 21:jre
  $(basename "$0") -i 21 -a corretto
  $(basename "$0") -i 21 -k
  $(basename "$0") -i lts -L ~/jvm
  $(basename "$0") -i 21 -s https://example.com/jdk-21_linux-x64.tar.gz
  $(basename "$0") -l x64
  $(basename "$0") -l 21
  $(basename "$0") -l lts:jre:x64
  $(basename "$0") -d build/jre -i 21:jre:x64
  $(basename "$0") -d build/jre -i 21:jre:aarch64
  $(basename "$0") -g 21:jre:x64 -o windows
  $(basename "$0") -g 21:jre -p pkg -d ~/Downloads
  $(basename "$0") -u -n
  $(basename "$0") -u -t
  $(basename "$0") -u
  $(basename "$0") -u -z ~/Downloads/tzupdater.jar

Home page and issues: <${HOME_PAGE}>
EOL
}


# prints the version with the copyright and the license in short, like GNU
#---------------------------------------------------------------
function version {
#---------------------------------------------------------------
cat << EOL
$(basename "$0") ${VERSION}
${COPYRIGHT}
License Apache-2.0: <https://www.apache.org/licenses/LICENSE-2.0>, see -C.
EOL
}


# prints the copyright and the license
#---------------------------------------------------------------
function copyright {
#---------------------------------------------------------------
cat << EOL
$(basename "$0") ${VERSION}
${COPYRIGHT}

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
EOL
}


#---------------------------------------------------------------
function fail {
#---------------------------------------------------------------
  printf >&2 "FATAL: %s Exit.\n" "$1"
  exit 1
}


# prints sudo, or doas if there is no sudo, as on many Alpine systems, or
# nothing if there is neither
#---------------------------------------------------------------
function rootCommand {
#---------------------------------------------------------------
  if command -v sudo > /dev/null 2>&1; then
    printf "sudo"
  elif command -v doas > /dev/null 2>&1; then
    printf "doas"
  fi
}


# params: commands
# prints the command that installs them by the package manager of this
# system, or nothing if there is none it knows
#---------------------------------------------------------------
function installHint {
#---------------------------------------------------------------
  local install="" cmd package packages=""
  if [ "$OS" = "alpine-linux" ]; then
    install="apk add"
  elif command -v apt-get > /dev/null 2>&1; then
    install="apt install"
  elif command -v dnf > /dev/null 2>&1; then
    install="dnf install"
  elif command -v yum > /dev/null 2>&1; then
    install="yum install"
  elif command -v zypper > /dev/null 2>&1; then
    install="zypper install"
  fi
  [ -n "$install" ] && [ "$OS" != "mac" ] || return 0
  local as_root=""
  if [ "$(id -u)" -ne 0 ]; then
    if [ -n "$SUDO" ]; then
      install="${SUDO} ${install}"
    else
      as_root=" as root"
    fi
  fi
  for cmd in "$@"; do
    case "$cmd" in
      xz) package="xz"; [ "$install" = "${install%apt install}" ] || package="xz-utils" ;;
      sha256sum|sha1sum) package="coreutils" ;;
      *) package="$cmd" ;;
    esac
    [[ " $packages " == *" $package "* ]] || packages="${packages:+$packages }${package}"
  done
  printf "%s %s%s" "$install" "$packages" "$as_root"
}


# params: the commands that are required
# fails with all of them that are missing and how to install them
#---------------------------------------------------------------
function checkPrerequisites {
#---------------------------------------------------------------
  local cmd missing=()
  for cmd in "$@"; do
    command -v "$cmd" > /dev/null 2>&1 || missing+=("$cmd")
  done
  [ ${#missing[@]} -gt 0 ] || return 0
  local hint names
  hint="$(installHint "${missing[@]}")"
  if [ ${#missing[@]} -eq 1 ]; then
    fail "$(printf "the command %s is required, but it is not installed%s." "${missing[0]}" \
                   "${hint:+, install it by: $hint}")"
  fi
  # like "curl, tar and xz"
  names="$(printf "%s, " "${missing[@]}")"
  names="${names%, }"
  names="${names%, *} and ${names##*, }"
  fail "$(printf "the commands %s are required, but they are not installed%s." "$names" \
                 "${hint:+, install them by: $hint}")"
}


# params: URL, target file
#---------------------------------------------------------------
function fetch_json {
#---------------------------------------------------------------
  curl -fsS --retry 3 -o "$2" "$1" ||
    fail "$(printf "could not query %s." "$1")"
}


# params: URL, target file
# like fetch_json, but follows redirects and returns 1 if the server rejects
# the request by an HTTP 4xx error, as for something it does not offer, and
# fails on anything else
#---------------------------------------------------------------
function try_fetch {
#---------------------------------------------------------------
  local code
  code="$(curl -sSL --retry 3 -o "$2" -w '%{http_code}' "$1" 2>"${TMP_DIR}/curl.err")" ||
    fail "$(printf "could not query %s: %s." "$1" "$(sed 's/^curl: //' "${TMP_DIR}/curl.err")")"
  case "$code" in
    2??) return 0 ;;
    4??) return 1 ;;
    *) fail "$(printf "could not query %s: HTTP %s." "$1" "$code")" ;;
  esac
}


# downloads the static jq of JQ_VERSION for this platform into TMP_DIR,
# verifies it by its SHA-256 and puts it first in the PATH for this run,
# fails if there is none for this platform
#---------------------------------------------------------------
function fetchJq {
#---------------------------------------------------------------
  local asset checksum
  # the checksums are the ones of sha256sum.txt of the release
  case "${OS}-${ARCH}" in
    mac-aarch64) asset="jq-macos-arm64"
      checksum="2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e" ;;
    mac-x64) asset="jq-macos-amd64"
      checksum="e94b266e3c26690550006abe63152b782280f4e14374accdf04cbde844f00bc0" ;;
    # the Linux binaries are static, they run on glibc and musl alike
    *linux-x64) asset="jq-linux-amd64"
      checksum="b1c22172dd303f3be49e935aa56aa48a8b7a46e0bc838b4997d3bb451495870f" ;;
    *linux-aarch64) asset="jq-linux-arm64"
      checksum="8b85c817833814ddca00a144c33705546355afccf0cf39b188f3cdb48b852309" ;;
    *) checkPrerequisites jq ;;
  esac
  printf "Note: jq is not installed, using jq %s from https://github.com/jqlang/jq for this run.\n" "$JQ_VERSION"
  mkdir -p "${TMP_DIR}/bin" || fail "$(printf "could not create %s." "${TMP_DIR}/bin")"
  local jq="${TMP_DIR}/bin/jq"
  try_fetch "${JQ_URL}/${asset}" "$jq" ||
    fail "$(printf "could not download %s." "${JQ_URL}/${asset}")"
  local actual
  actual="$(sha256 "$jq")"
  [ "$actual" = "$checksum" ] ||
    fail "$(printf "checksum mismatch for %s:\n  expected %s\n  actual   %s" "$asset" "$checksum" "$actual")"
  chmod +x "$jq" || fail "$(printf "could not make %s executable." "$jq")"
  PATH="${TMP_DIR}/bin:${PATH}"
}


# params: file
# prints the SHA-256 of the file
#---------------------------------------------------------------
function sha256 {
#---------------------------------------------------------------
  $SHA_CMD "$1" | cut -d' ' -f1
}


# params: file
# prints the SHA-1 of the file
#---------------------------------------------------------------
function sha1 {
#---------------------------------------------------------------
  $SHA1_CMD "$1" | cut -d' ' -f1
}


# params: URL of a checksum file
# prints the first word of the file, or nothing if there is none
#---------------------------------------------------------------
function fetchChecksum {
#---------------------------------------------------------------
  local file="${TMP_DIR}/checksum.txt"
  try_fetch "$1" "$file" || return 0
  head -1 "$file" | awk '{ print tolower($1) }'
}


# params: URL of a package
# prints the SHA-256 published next to the package as <url>.sha256,
# <url>.sha256.txt or <url without its extension>.sha256.txt, or nothing
#---------------------------------------------------------------
function checksumNextTo {
#---------------------------------------------------------------
  local url checksum base="${1%.tar.[gx]z}"
  [ "$base" != "$1" ] || base="${1%.*}"
  for url in "${1}.sha256" "${1}.sha256.txt" "${base}.sha256.txt"; do
    checksum="$(fetchChecksum "$url")" || exit 1
    [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] && { printf "%s" "$checksum"; return; }
  done
  return 0
}


# sets OS, ARCH, SHA_CMD, SHA1_CMD, OWNER, ALTERNATIVES and the default
# TARGET_DIR
#---------------------------------------------------------------
function detectPlatform {
#---------------------------------------------------------------
  ALTERNATIVES=""
  case "$(uname -s)" in
    Darwin)
      OS="mac"
      SHA_CMD="shasum -a 256"
      SHA1_CMD="shasum -a 1"
      OWNER="root:wheel"
      DEFAULT_DIR="/Library/Java/JavaVirtualMachines"
      ;;
    Linux)
      OS="linux"
      # glibc binaries do not run on musl based systems like Alpine
      if [ -f /etc/alpine-release ] || ldd --version 2>&1 | grep -qi musl; then
        OS="alpine-linux"
      fi
      SHA_CMD="sha256sum"
      SHA1_CMD="sha1sum"
      OWNER="root:root"
      DEFAULT_DIR="/usr/lib/jvm"
      if command -v update-alternatives > /dev/null 2>&1; then
        ALTERNATIVES="update-alternatives"
      elif command -v alternatives > /dev/null 2>&1; then
        ALTERNATIVES="alternatives"
      fi
      ;;
    *) fail "$(printf "the operating system %s is not supported." "$(uname -s)")" ;;
  esac

  ARCH="$(normalizeArch "$(uname -m)")" ||
    fail "$(printf "the architecture %s is not supported." "$(uname -m)")"

  [ -n "$TARGET_DIR" ] || TARGET_DIR="$DEFAULT_DIR"
}


# params: architecture like x64, x86_64, aarch64 or arm64
# prints the name of the architecture the APIs use, fails if it is unknown
#---------------------------------------------------------------
function normalizeArch {
#---------------------------------------------------------------
  case "$1" in
    x64|x86_64|amd64) printf "x64" ;;
    aarch64|arm64) printf "aarch64" ;;
    arm|armv7l|armv8l) printf "arm" ;;
    ppc64le|s390x|riscv64) printf "%s" "$1" ;;
    *) return 1 ;;
  esac
}


# params: operating system like mac, linux, alpine-linux or windows
# sets PKG_OS, PKG_FOOJAY_OS and PKG_LIBC, the platform of the packages to
# look up, PKG_OS_NAME to its name for messages, and PKG_FORMAT to its archive
# format unless -p is given, fails if the operating system is unknown
#---------------------------------------------------------------
function setPackagePlatform {
#---------------------------------------------------------------
  case "$1" in
    mac|macos) PKG_OS="mac" PKG_FOOJAY_OS="macos" PKG_LIBC="" PKG_OS_NAME="macOS" ;;
    linux) PKG_OS="linux" PKG_FOOJAY_OS="linux" PKG_LIBC="glibc" PKG_OS_NAME="Linux" ;;
    alpine-linux|alpine)
      PKG_OS="alpine-linux" PKG_FOOJAY_OS="linux" PKG_LIBC="musl" PKG_OS_NAME="Alpine Linux" ;;
    windows) PKG_OS="windows" PKG_FOOJAY_OS="windows" PKG_LIBC="" PKG_OS_NAME="Windows" ;;
    *) fail "$(printf "\"%s\" is not one of the operating systems mac, linux, alpine-linux and windows." "$1")" ;;
  esac
  if [ -z "$FORMAT_ARG" ]; then
    PKG_FORMAT="tar.gz"
    [ "$PKG_OS" = "windows" ] && PKG_FORMAT="zip"
  else
    PKG_FORMAT="$FORMAT_ARG"
  fi
}


# params: file name of a package
# prints its format, the extension like tar.gz, zip, pkg or msi
#---------------------------------------------------------------
function formatOf {
#---------------------------------------------------------------
  case "$1" in
    *.tar.gz) printf "tar.gz" ;;
    *.tar.xz) printf "tar.xz" ;;
    *.*) printf "%s" "${1##*.}" ;;
  esac
}


# queries the available Temurin releases once and caches them in TMP_DIR
#---------------------------------------------------------------
function releasesJson {
#---------------------------------------------------------------
  local json="${TMP_DIR}/releases.json"
  [ -s "$json" ] || fetch_json "${ADOPTIUM_API}/info/available_releases" "$json"
  printf "%s" "$json"
}


# params: distribution
# fails if the foojay Disco API does not know the distribution
#---------------------------------------------------------------
function checkFoojayDistro {
#---------------------------------------------------------------
  local json="${TMP_DIR}/distributions.json"
  fetch_json "${FOOJAY_API}/distributions?include_versions=false" "$json"
  jq -e --arg d "$1" '.result[] | select(.api_parameter == $d)' "$json" > /dev/null ||
    fail "$(printf "the distribution %s is unknown, list them by -l -a." "$1")"
}


# params: width
# prints a line of that many dashes, to separate the header of a table
#---------------------------------------------------------------
function ruler {
#---------------------------------------------------------------
  local line
  printf -v line "%*s" "$1" ""
  printf "%s" "${line// /-}"
}


# lists all values of -a, the distributions of the foojay Disco API and
# temurin and adoptium for the Adoptium API, if LIST_FILTERED is 1 only those
# that have packages for PKG_OS and LIST_ARCH, and LIST_FEATURE, LIST_TYPE
# and FORMAT_ARG if they are set
#---------------------------------------------------------------
function listDistros {
#---------------------------------------------------------------
  local json="${TMP_DIR}/distributions.json" offered=""
  if [ $LIST_FILTERED -eq 1 ]; then
    local filter="${LIST_FEATURE:+$LIST_FEATURE }${LIST_TYPE:+$LIST_TYPE }"
    local query="operating_system=${PKG_FOOJAY_OS}&architecture=${LIST_ARCH}"
    query="${query}&latest=available&release_status=ga&directly_downloadable=true"
    [ -z "$PKG_LIBC" ] || query="${query}&lib_c_type=${PKG_LIBC}"
    [ -z "$LIST_FEATURE" ] || query="${query}&version=${LIST_FEATURE}"
    [ -z "$LIST_TYPE" ] || query="${query}&package_type=${LIST_TYPE}"
    [ -z "$FORMAT_ARG" ] || query="${query}&archive_type=${FORMAT_ARG}"
    printf "Asking %s for the distributions with %sreleases for %s %s%s ...\n\n" "$FOOJAY_API" "$filter" \
           "$PKG_OS_NAME" "$LIST_ARCH" "${FORMAT_ARG:+ as $FORMAT_ARG}"
    # foojay rejects an unknown version rather than finding nothing
    try_fetch "${FOOJAY_API}/packages?${query}" "${TMP_DIR}/offered.json" &&
      offered=" $(jq -r '[.result[].distribution] | unique | join(" ")' "${TMP_DIR}/offered.json") "
    [ -n "${offered// /}" ] ||
      fail "$(printf "there is no distribution with %sreleases for %s %s%s." "$filter" \
                     "$PKG_OS_NAME" "$LIST_ARCH" "${FORMAT_ARG:+ as $FORMAT_ARG}")"
  else
    printf "Asking %s for distributions ...\n\n" "$FOOJAY_API"
  fi
  fetch_json "${FOOJAY_API}/distributions?include_versions=false" "$json"
  printf "  %-20s %-24s %s\n" "-a" "NAME" "API"
  printf "  %s %s %s\n" "$(ruler 20)" "$(ruler 24)" "$(ruler 23)"
  [ -z "$offered" ] || [[ "$offered" == *" temurin "* ]] &&
    printf "  %-20s %-24s %s\n" "temurin, adoptium" "Eclipse Temurin" "Adoptium (default)"
  jq -r --arg offered "$offered" \
     '.result | sort_by(.api_parameter)[] | select(.api_parameter != "temurin")
      | select(.api_parameter as $d | $offered == "" or ($offered | contains(" " + $d + " ")))
      | [.api_parameter, .name, (if .maintained then "" else " (not maintained)" end)] | @tsv' "$json" |
    while IFS=$'\t' read -r param name maintained; do
      printf "  %-20s %-24s %s%s\n" "$param" "$name" "foojay" "$maintained"
    done
  printf "\nAdoptium = %s, foojay = %s\n" "$ADOPTIUM_API" "$FOOJAY_API"
}


# params: distribution, architecture
# queries the latest packages of the distribution for PKG_OS and the
# architecture once, keeps the one with the highest Java version per feature
# version, type and format, caches them in TMP_DIR and prints the path of the file
#---------------------------------------------------------------
function foojayPackagesJson {
#---------------------------------------------------------------
  local json="${TMP_DIR}/foojay_${1}_${PKG_OS}_${2}.json"
  if [ ! -s "$json" ]; then
    local query="distro=${1}&operating_system=${PKG_FOOJAY_OS}&architecture=${2}"
    query="${query}&latest=available&release_status=ga"
    query="${query}&javafx_bundled=false&directly_downloadable=true"
    [ -z "$PKG_LIBC" ] || query="${query}&lib_c_type=${PKG_LIBC}"
    fetch_json "${FOOJAY_API}/packages?${query}" "${json}.raw"
    jq '[.result | group_by([.major_version, .package_type, .archive_type])[]
         | sort_by(.java_version | [scan("[0-9]+") | tonumber]) | last]' "${json}.raw" > "$json" ||
      fail "$(printf "could not read the packages of %s." "$1")"
  fi
  printf "%s" "$json"
}


# params: distribution, operating system and architecture to leave out
#         in the names of --os
# prints how to choose the platforms the distribution has packages for,
# like "--os linux and aarch64 or x64; --os windows and x64", or nothing if
# it has packages for the platform to leave out
#---------------------------------------------------------------
function foojayPlatforms {
#---------------------------------------------------------------
  local json="${TMP_DIR}/foojay_${1}_platforms.json"
  curl -fsS --retry 3 -o "$json" \
    "${FOOJAY_API}/packages?distro=${1}&latest=available&release_status=ga&directly_downloadable=true" ||
    return 0
  jq -r --arg archs " $ARCHS " --arg os "$2" --arg arch "$3" \
     'def words: if length > 1 then (.[:-1] | join(", ")) + " or " + last else join("") end;
      [.result[]
       | select(.architecture as $a | $archs | contains(" " + $a + " "))
       | {os: (if .operating_system == "macos" then "mac"
               elif .operating_system == "linux" and .lib_c_type == "musl" then "alpine-linux"
               else .operating_system end),
          arch: .architecture}]
      | unique
      | if any(.[]; .os == $os and .arch == $arch) then empty
        else group_by(.os) | map("--os \(.[0].os) and " + (map(.arch) | words)) | join("; ") end' "$json"
}


# params: distribution, lts|latest, architecture
# prints the most recent (LTS) feature version of the distribution
#---------------------------------------------------------------
function recentFeature {
#---------------------------------------------------------------
  local json
  if [ "$1" = "temurin" ]; then
    json="$(releasesJson)" || exit 1
    case "$2" in
      lts) jq -r .most_recent_lts "$json" ;;
      latest) jq -r .most_recent_feature_release "$json" ;;
    esac
  else
    json="$(foojayPackagesJson "$1" "$3")" || exit 1
    jq -r --arg w "$2" --arg a " $PKG_FORMATS " \
       '[.[] | select((.archive_type as $x | $a | contains(" " + $x + " "))
                      and ($w == "latest" or .term_of_support == "lts")) | .major_version]
        | max // empty' "$json"
  fi
}


# params: distribution, <feature-version>[:jdk|:jre][:<architecture>]
# sets FEATURE, TYPE and VARIANT_ARCH, which defaults to this machine's,
# and TYPE_GIVEN to 1 if the type is given
#---------------------------------------------------------------
function parseVariant {
#---------------------------------------------------------------
  local arg="$2" rest="" second="" third="" arch=""
  FEATURE="${arg%%:*}"
  TYPE="jdk"
  TYPE_GIVEN=0
  VARIANT_ARCH="$ARCH"
  if [ "$arg" != "$FEATURE" ]; then
    rest="${arg#*:}"
    second="${rest%%:*}"
    [ "$rest" != "$second" ] && third="${rest#*:}"
  fi
  # the second field is the type, or the architecture if the type is omitted
  case "$second" in
    jdk|jre) TYPE="$second"; TYPE_GIVEN=1; arch="$third" ;;
    "") arch="$third" ;;
    *)
      [ -z "$third" ] ||
        fail "$(printf "\"%s\" is not a valid type, use jdk or jre." "$second")"
      arch="$second" ;;
  esac
  if [ -n "$arch" ]; then
    VARIANT_ARCH="$(normalizeArch "$arch")" || {
      [ -n "$third" ] ||
        fail "$(printf "\"%s\" is neither jdk, jre nor one of the architectures %s." "$arch" "$ARCHS")"
      fail "$(printf "\"%s\" is not one of the architectures %s." "$arch" "$ARCHS")"
    }
  fi

  case "$FEATURE" in
    lts|latest) FEATURE="$(recentFeature "$1" "$FEATURE" "$VARIANT_ARCH")" || exit 1 ;;
  esac

  case "$FEATURE" in
    ""|*[!0-9]*) fail "$(printf "\"%s\" is not a valid Java feature version." "$FEATURE")" ;;
  esac
}


# params: distribution, feature version, type, [architecture]
# prints the installation directory of that variant, its name contains the
# architecture only if it is not the one of this machine
#---------------------------------------------------------------
function installDirOf {
#---------------------------------------------------------------
  local name="$1-$2"
  [ -z "$4" ] || [ "$4" = "$ARCH" ] || name="${name}-$4"
  if [ "$OS" = "mac" ]; then
    printf "%s/%s.%s" "${TARGET_DIR%/}" "$name" "$3"
  else
    printf "%s/%s-%s" "${TARGET_DIR%/}" "$name" "$3"
  fi
}


# params: installation directory
# prints the distribution of the installation, taken from its name
#---------------------------------------------------------------
function distroOf {
#---------------------------------------------------------------
  local name
  name="$(basename "$1")"
  printf "%s" "${name%%-[0-9]*}"
}


# params: installation directory
# prints the path of the release file, on macOS inside the bundle unless the
# installation has no bundle structure
#---------------------------------------------------------------
function releaseFileOf {
#---------------------------------------------------------------
  if [ "$OS" = "mac" ] && { [ -d "$1/Contents" ] || [ ! -f "$1/release" ]; }; then
    printf "%s/Contents/Home/release" "$1"
  else
    printf "%s/release" "$1"
  fi
}


# params: installation directory
# prints the path of the marker file that records where the installation is from
#---------------------------------------------------------------
function markerOf {
#---------------------------------------------------------------
  printf "%s/.updatejdk/%s" "$(dirname "$1")" "$(basename "$1")"
}


# params: release or marker file, key
# prints the value of the key
#---------------------------------------------------------------
function releaseValue {
#---------------------------------------------------------------
  sed -n "s/^$2=\"\(.*\)\"$/\1/p" "$1" 2>/dev/null | head -1
}


# params: installation directory
# prints the installed version, in the format of the Adoptium API's
# openjdk_version for Temurin, or nothing if there is no installation of
# this script: a Temurin, or a directory that has a marker file
#---------------------------------------------------------------
function installedVersion {
#---------------------------------------------------------------
  local release
  release="$(releaseFileOf "$1")"
  [ -f "$release" ] || return
  if [ "$(distroOf "$1")" = "temurin" ]; then
    [ "$(releaseValue "$release" IMPLEMENTOR)" = "Eclipse Adoptium" ] || return
  else
    [ -f "$(markerOf "$1")" ] || return
  fi
  local version
  version="$(releaseValue "$release" FULL_VERSION)"
  [ -n "$version" ] || version="$(releaseValue "$release" JAVA_RUNTIME_VERSION)"
  [ -n "$version" ] || version="$(releaseValue "$release" JAVA_VERSION)"
  printf "%s" "$version"
}


# params: directory
# prints the name of the system package that owns the directory,
# or nothing if it is not managed by a package manager
#---------------------------------------------------------------
function packageOwner {
#---------------------------------------------------------------
  [ "$OS" = "mac" ] && return
  if command -v dpkg > /dev/null 2>&1; then
    dpkg -S "$1" 2>/dev/null | head -1 | cut -d: -f1
  elif command -v rpm > /dev/null 2>&1; then
    # rpm prints "... is not owned by any package" to stdout, so check the exit code
    local owner
    owner="$(rpm -qf "$1" 2>/dev/null)" && printf "%s" "${owner%%$'\n'*}"
  fi
}


# params: [distribution]
# prints the installed variants as
# <distribution>:<feature-version>:<type>:<architecture>, one per line,
# only those of the distribution if it is given
#---------------------------------------------------------------
function listInstalled {
#---------------------------------------------------------------
  local dir name distro feature type arch
  local pattern="^([a-z][a-z0-9_]*)-([0-9]+)(-(${ARCHS// /|}))?[.-](jdk|jre)$"
  for dir in "${TARGET_DIR}"/*; do
    [ -d "$dir" ] || continue
    name="$(basename "$dir")"
    [[ "$name" =~ $pattern ]] || continue
    distro="${BASH_REMATCH[1]}" feature="${BASH_REMATCH[2]}"
    arch="${BASH_REMATCH[4]:-$ARCH}" type="${BASH_REMATCH[5]}"
    [ -z "$1" ] || [ "$distro" = "$1" ] || continue
    [ "$(installDirOf "$distro" "$feature" "$type" "$arch")" = "$dir" ] || continue
    [ -n "$(installedVersion "$dir")" ] || continue
    # installations of the package manager are updated by the package manager
    [ -z "$(packageOwner "$dir")" ] &&
      printf "%s:%s:%s:%s\n" "$distro" "$feature" "$type" "$arch"
  done | sort -t: -k2,2n -k1,1 -k3,3 -k4,4
}


# params: version, other version
# succeeds if the numbers of the version are greater than the other's
#---------------------------------------------------------------
function versionNewer {
#---------------------------------------------------------------
  jq -en --arg a "$1" --arg b "$2" \
     '($a | [scan("[0-9]+") | tonumber]) > ($b | [scan("[0-9]+") | tonumber])' > /dev/null
}


# params: label, type, latest release, formats, latest version or file name,
#         installation directory or nothing, key of the marker to compare
# prints one line of the list, marks the variant if it is installed
#---------------------------------------------------------------
function listLine {
#---------------------------------------------------------------
  local label="$1" type="$2" release="$3" formats="$4" latest="$5" dir="$6" key="$7"
  local installed="" owner status current
  [ -z "$dir" ] || installed="$(installedVersion "$dir")"
  if [ -z "$installed" ]; then
    printf "  %-9s %-5s %-20s %s\n" "$label" "$type" "$release" "$formats"
    return
  fi
  owner="$(packageOwner "$dir")"
  current="$installed"
  [ -z "$key" ] || current="$(releaseValue "$(markerOf "$dir")" "$key")"
  if [ -n "$owner" ]; then
    status="managed by package $owner"
  elif [ "$current" = "$latest" ]; then
    status="up to date"
  elif [ -n "$key" ] && versionNewer "$installed" "$release"; then
    # foojay may lag behind the vendor, like for Corretto
    status="up to date"
  else
    status="update available"
  fi
  printf "%s* %-9s %-5s %-20s %-16s %s (%s) %s%s\n" "$BOLD" "$label" "$type" "$release" \
         "$formats" "$installed" "$status" "$dir" "$NORMAL"
}


# params: distribution, 1 if it may have no release
# lists all variants of the distribution available for PKG_OS and LIST_ARCH,
# only those of LIST_FEATURE, LIST_TYPE and FORMAT_ARG if they are set,
# marks installed ones if PKG_OS is this machine's, adds the number of lines
# to LISTED, fails if there is none unless it may have none
#---------------------------------------------------------------
function listAvailable {
#---------------------------------------------------------------
  local distro="$1" optional="$2"
  local feature type label release version formats dir count=0
  local types="${LIST_TYPE:-jdk jre}"
  # installations exist for this machine's operating system only
  local here=1
  [ "$PKG_OS" = "$OS" ] || here=0
  # like "21 jre " to name what is asked for
  local filter="${LIST_FEATURE:+$LIST_FEATURE }${LIST_TYPE:+$LIST_TYPE }"

  if [ "$distro" = "temurin" ]; then
    local json
    json="$(releasesJson)" || exit 1
    local releases
    releases="$(jq -r '.available_releases[]' "$json" | sort -n)"
    [ -z "$LIST_FEATURE" ] || releases="$LIST_FEATURE"
    local lts
    lts=" $(jq -r '.available_lts_releases | join(" ")' "$json") "
    local assets
    printf "Asking %s for Temurin %sreleases for %s %s ...\n\n" "$ADOPTIUM_API" "$filter" "$PKG_OS_NAME" "$LIST_ARCH"
    listHeader
    for feature in $releases; do
      assets="${TMP_DIR}/assets_${feature}.json"
      try_fetch \
        "${ADOPTIUM_API}/assets/latest/${feature}/${JVM_IMPL}?os=${PKG_OS}&architecture=${LIST_ARCH}&vendor=${VENDOR}" \
        "$assets" || continue
      label="$feature"
      case "$lts" in
        *" $feature "*) label="$feature LTS" ;;
      esac
      for type in $types; do
        release="$(jq -r --arg t "$type" '[.[] | select(.binary.image_type == $t)][0].release_name // empty' "$assets")"
        [ -n "$release" ] || continue
        version="$(jq -r --arg t "$type" '[.[] | select(.binary.image_type == $t)][0].version.openjdk_version // empty' "$assets")"
        formats="$(jq -r --arg t "$type" '[.[] | select(.binary.image_type == $t)][0].binary
                                          | [.package.name, .installer.name // empty] | .[]' "$assets" |
                   while read -r name; do formatOf "$name"; printf " "; done)"
        formats="${formats% }"
        [ -z "$FORMAT_ARG" ] || [[ " $formats " == *" $FORMAT_ARG "* ]] || continue
        dir=""
        [ $here -eq 0 ] || dir="$(installDirOf temurin "$feature" "$type" "$LIST_ARCH")"
        listLine "$label" "$type" "$release" "$formats" "$version" "$dir" ""
        count=$((count + 1))
      done
    done
  else
    printf "Asking %s for %s %sreleases for %s %s ...\n\n" "$FOOJAY_API" "$distro" "$filter" \
           "$PKG_OS_NAME" "$LIST_ARCH"
    local packages
    packages="$(foojayPackagesJson "$distro" "$LIST_ARCH")" || exit 1
    listHeader
    local lts filename
    # one line per feature version and type, with the formats it comes in
    # and the tar.gz or tar.xz that an installation is made of
    while IFS=$'\t' read -r feature type lts release formats filename; do
      label="$feature"
      [ "$lts" = "lts" ] && label="$feature LTS"
      dir=""
      [ $here -eq 0 ] || dir="$(installDirOf "$distro" "$feature" "$type" "$LIST_ARCH")"
      listLine "$label" "$type" "$release" "$formats" "$filename" "$dir" filename
      count=$((count + 1))
    done < <(jq -r --arg f "$LIST_FEATURE" --arg t "$LIST_TYPE" --arg a "$FORMAT_ARG" \
               'group_by([.major_version, .package_type])[]
                | select(($f == "" or (.[0].major_version | tostring) == $f) and ($t == "" or .[0].package_type == $t))
                | select($a == "" or any(.[]; .archive_type == $a))
                | [.[0].major_version, .[0].package_type, .[0].term_of_support,
                   (map(.java_version) | max_by([scan("[0-9]+") | tonumber])),
                   (map(.archive_type) | unique | join(" ")),
                   ((map(select(.archive_type == "tar.gz") | .filename) | first)
                    // (map(select(.archive_type == "tar.xz") | .filename) | first) // "")] | @tsv' \
               "$packages")
  fi

  LISTED=$((LISTED + count))
  if [ $count -eq 0 ]; then
    # name the platforms only if the distribution has none for this one
    local platforms="" message
    [ "$distro" = "temurin" ] || platforms="$(foojayPlatforms "$distro" "$PKG_OS" "$LIST_ARCH")"
    message="$(printf "there is no release of %s %sfor %s %s%s%s." "$distro" "$filter" "$PKG_OS_NAME" "$LIST_ARCH" \
                      "${FORMAT_ARG:+ as $FORMAT_ARG}" "${platforms:+, but with $platforms}")"
    [ "$optional" = "1" ] || fail "$message"
    printf "  %s\n" "$message"
    [ -n "$LIST_EMPTY" ] || LIST_EMPTY="$message"
  fi
}


# lists the variants of DISTRO by listAvailable, without -a like -u those of
# the other distributions installed in TARGET_DIR as well, each in a table of
# its own, and names the installations by -s
#---------------------------------------------------------------
function listVariants {
#---------------------------------------------------------------
  BOLD="" NORMAL=""
  if [ -t 1 ] && command -v tput > /dev/null 2>&1; then
    BOLD="$(tput bold 2>/dev/null)"
    NORMAL="$(tput sgr0 2>/dev/null)"
  fi
  # installations exist for this machine's operating system only
  local here=1
  [ "$PKG_OS" = "$OS" ] || here=0
  # the distributions to list with their feature version, - for all
  local lists="${DISTRO}:${LIST_FEATURE:--}" installed="" word="" d feature type arch
  if [ $DISTRO_GIVEN -eq 0 ] && [ $here -eq 1 ]; then
    installed="$(listInstalled | awk -F: -v a="$LIST_ARCH" '$4 == a')"
    # lts and latest depend on the distribution
    case "${LIST_ARG%%:*}" in
      lts|latest) word="${LIST_ARG%%:*}" ;;
    esac
    for d in $(printf "%s\n" "$installed" | cut -d: -f1 | sort -u); do
      [ "$d" != "$DISTRO" ] && [ "$d" != "custom" ] || continue
      feature="$LIST_FEATURE"
      if [ -n "$word" ]; then
        feature="$(recentFeature "$d" "$word" "$LIST_ARCH")" || exit 1
        [ -n "$feature" ] || continue
      fi
      # only if one of its installations is among what is asked for
      printf "%s\n" "$installed" |
        grep -q "^${d}:${feature:-[0-9]*}:${LIST_TYPE:-[a-z]*}:" || continue
      lists="${lists} ${d}:${feature:--}"
    done
  fi

  # with several tables, one of them may be empty
  local optional=0 entry first=1 asked="$LIST_FEATURE"
  [ "$lists" = "${lists%% *}" ] || optional=1
  LISTED=0 LIST_EMPTY=""
  for entry in $lists; do
    [ $first -eq 1 ] || printf "\n"
    first=0
    LIST_FEATURE="${entry#*:}"
    [ "$LIST_FEATURE" != "-" ] || LIST_FEATURE=""
    listAvailable "${entry%%:*}" "$optional"
  done
  LIST_FEATURE="$asked"
  [ $LISTED -gt 0 ] || fail "$LIST_EMPTY"

  # an installation by -s has no source to list it by
  local custom dir
  custom="$(printf "%s\n" "$installed" | grep "^custom:${LIST_FEATURE:-[0-9]*}:${LIST_TYPE:-[a-z]*}:")"
  if [ -n "$custom" ]; then
    printf "\nInstalled by -s, not updated by -u:\n"
    while IFS=: read -r d feature type arch; do
      dir="$(installDirOf custom "$feature" "$type" "$arch")"
      printf "%s* %s (%s)%s\n" "$BOLD" "$dir" "$(installedVersion "$dir")" "$NORMAL"
    done <<< "$custom"
  fi
  [ $here -eq 0 ] || printf "\n* = installed in %s\n" "$TARGET_DIR"
}


# prints the header of the list of variants
#---------------------------------------------------------------
function listHeader {
#---------------------------------------------------------------
  printf "  %-9s %-5s %-20s %-16s %s\n" "VERSION" "TYPE" "LATEST" "FORMATS" "INSTALLED"
  printf "  %s %s %s %s %s\n" "$(ruler 9)" "$(ruler 5)" "$(ruler 20)" "$(ruler 16)" "$(ruler 9)"
}


# params: feature version, type, architecture
# sets the PKG_* variables from the Adoptium API
#---------------------------------------------------------------
function lookupAdoptium {
#---------------------------------------------------------------
  local json="${TMP_DIR}/asset_${PKG_OS}_${1}_${2}_${3}.json"
  local query="os=${PKG_OS}&architecture=${3}&image_type=${2}&vendor=${VENDOR}"
  printf "\nLooking up the Temurin %s %s for %s %s ...\n" "$2" "$1" "$PKG_OS_NAME" "$3"
  fetch_json "${ADOPTIUM_API}/assets/latest/${1}/${JVM_IMPL}?${query}" "$json"

  # the archive is the package, pkg and msi are the installer
  local field="" kind formats=""
  for kind in package installer; do
    local format
    format="$(formatOf "$(jq -r --arg k "$kind" '.[0].binary[$k].name // empty' "$json")")"
    [ -n "$format" ] || continue
    formats="${formats:+$formats or }${format}"
    [ "$format" = "$PKG_FORMAT" ] && field="$kind"
  done
  [ -n "$formats" ] ||
    fail "$(printf "the Adoptium API does not offer a %s %s %s of Java %s." "$PKG_OS_NAME" "$3" "$2" "$1")"
  [ -n "$field" ] ||
    fail "$(printf "Temurin %s %s for %s %s is available as %s, not %s." "$1" "$2" "$PKG_OS_NAME" "$3" "$formats" "$PKG_FORMAT")"

  PKG_NAME="$(jq -r --arg k "$field" '.[0].binary[$k].name // empty' "$json")"
  PKG_LINK="$(jq -r --arg k "$field" '.[0].binary[$k].link // empty' "$json")"
  PKG_SHA256="$(jq -r --arg k "$field" '.[0].binary[$k].checksum // empty' "$json")"
  PKG_SHA1=""
  PKG_SIZE="$(jq -r --arg k "$field" '.[0].binary[$k].size // empty' "$json")"
  PKG_RELEASE="$(jq -r '.[0].release_name // empty' "$json")"
  PKG_VERSION="$(jq -r '.[0].version.openjdk_version // empty' "$json")"

  if [ -z "$PKG_NAME" ] || [ -z "$PKG_LINK" ] || [ -z "$PKG_SHA256" ]; then
    fail "$(printf "the Adoptium API does not offer a %s %s %s of Java %s." "$PKG_OS_NAME" "$3" "$2" "$1")"
  fi
}


# params: distribution, feature version, type, architecture
# sets the PKG_* variables from the foojay Disco API
#---------------------------------------------------------------
function lookupFoojay {
#---------------------------------------------------------------
  local distro="$1" feature="$2" type="$3" arch="$4"
  printf "\nLooking up the %s %s %s for %s %s ...\n" "$distro" "$type" "$feature" \
         "$PKG_OS_NAME" "$arch"
  local packages
  packages="$(foojayPackagesJson "$distro" "$arch")" || exit 1
  local formats
  formats="$(jq -r --argjson f "$feature" --arg t "$type" \
                   '[.[] | select(.major_version == $f and .package_type == $t) | .archive_type]
                    | unique | if length > 1 then (.[:-1] | join(", ")) + " or " + last else join("") end' \
                   "$packages")"
  [ -n "$formats" ] ||
    fail "$(printf "the foojay Disco API does not offer a %s %s %s %s of Java %s." \
                   "$distro" "$PKG_OS_NAME" "$arch" "$type" "$feature")"
  # the first of the accepted formats that is available, tar.gz before tar.xz
  local id="" format
  for format in $PKG_FORMATS; do
    id="$(jq -r --argjson f "$feature" --arg t "$type" --arg a "$format" \
          '.[] | select(.major_version == $f and .package_type == $t and .archive_type == $a) | .id' "$packages")"
    [ -z "$id" ] || break
  done
  [ -n "$id" ] ||
    fail "$(printf "%s %s %s for %s %s is available as %s, not %s." \
                   "$distro" "$feature" "$type" "$PKG_OS_NAME" "$arch" "$formats" "${PKG_FORMATS// / or }")"
  PKG_NAME="$(jq -r --arg i "$id" '.[] | select(.id == $i) | .filename' "$packages")"
  PKG_RELEASE="$(jq -r --arg i "$id" '.[] | select(.id == $i) | .java_version' "$packages")"
  PKG_VERSION="$PKG_NAME"
  PKG_SIZE="$(jq -r --arg i "$id" '.[] | select(.id == $i) | .size | select(. > 0) // empty' "$packages")"

  local json="${TMP_DIR}/foojay_id_${id}.json"
  fetch_json "${FOOJAY_API}/ids/${id}" "$json"
  PKG_LINK="$(jq -r '.result[0].direct_download_uri // empty' "$json")"
  [ -n "$PKG_LINK" ] || fail "$(printf "the foojay Disco API does not offer a download link of %s." "$PKG_NAME")"

  local checksum
  checksum="$(jq -r '.result[0].checksum // empty | ascii_downcase' "$json")"
  local checksum_type
  checksum_type="$(jq -r '.result[0].checksum_type // empty' "$json")"
  local checksum_uri
  checksum_uri="$(jq -r '.result[0].checksum_uri // empty' "$json")"
  if [ "$distro" = "corretto" ]; then
    # Corretto publishes the SHA-256 of its latest release only, by its own
    # endpoint, so download that release, which may be newer than foojay's
    local os="$PKG_FOOJAY_OS" latest location
    [ "$PKG_LIBC" = "musl" ] && os="alpine-linux"
    latest="amazon-corretto-${feature}-${arch}-${os}-${type}.${format}"
    location="$(curl -sSI --retry 3 -o /dev/null -w '%{http_code} %{redirect_url}' \
                "https://corretto.aws/downloads/latest/${latest}" 2>"${TMP_DIR}/curl.err")" ||
      fail "$(printf "could not query %s: %s." "https://corretto.aws/downloads/latest/${latest}" \
                     "$(sed 's/^curl: //' "${TMP_DIR}/curl.err")")"
    # a redirect to the latest release, or foojay's release if there is none
    case "$location" in
      3??\ ?*) location="${location#* }" ;;
      [234]??\ *) location="" ;;
      *) fail "$(printf "could not query %s: HTTP %s." "https://corretto.aws/downloads/latest/${latest}" "${location%% *}")" ;;
    esac
    if [ -n "$location" ]; then
      if [ "${location##*/}" != "$PKG_NAME" ]; then
        PKG_NAME="${location##*/}"
        PKG_VERSION="$PKG_NAME"
        PKG_RELEASE="$(printf "%s" "$PKG_NAME" | sed -n 's/^amazon-corretto-\([0-9.]*\)-.*/\1/p')"
        PKG_SIZE=""
        printf "Note: Corretto's latest release is newer than the one foojay knows.\n"
      fi
      PKG_LINK="$location"
      checksum="$(fetchChecksum "https://corretto.aws/downloads/latest_sha256/${latest}")" || exit 1
      checksum_type=""
    fi
  fi
  if [ -z "$checksum" ] && [ -n "$checksum_uri" ]; then
    checksum="$(fetchChecksum "$checksum_uri")" || exit 1
    checksum_type=""
  fi
  if [ -z "$checksum" ]; then
    checksum="$(checksumNextTo "$PKG_LINK")" || exit 1
    checksum_type=""
  fi

  PKG_SHA256=""
  PKG_SHA1=""
  if [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] && [ "${checksum_type:-sha256}" = "sha256" ]; then
    PKG_SHA256="$checksum"
  elif [[ "$checksum" =~ ^[0-9a-f]{40}$ ]] && [ "${checksum_type:-sha1}" = "sha1" ]; then
    PKG_SHA1="$checksum"
    printf "Note: %s publishes a SHA-1 only, not a SHA-256.\n" "$distro"
  else
    fail "$(printf "%s does not publish a SHA-256 or SHA-1 of %s, refusing to install it." "$distro" "$PKG_NAME")"
  fi
}


# sets the PKG_* variables for the archive at SOURCE_URL
#---------------------------------------------------------------
function lookupUrl {
#---------------------------------------------------------------
  PKG_LINK="$SOURCE_URL"
  PKG_NAME="${SOURCE_URL%%[?#]*}"
  PKG_NAME="${PKG_NAME##*/}"
  case "$PKG_NAME" in
    *.tar.gz|*.tgz|*.tar.xz|*.txz) ;;
    *) fail "$(printf "%s is not a .tar.gz or .tar.xz file." "$SOURCE_URL")" ;;
  esac
  PKG_RELEASE="$PKG_NAME"
  PKG_VERSION=""
  PKG_SIZE=""
  PKG_SHA1=""
  PKG_SHA256="$SHA256_ARG"
  printf "\nLooking up the checksum of %s ...\n" "$SOURCE_URL"
  [ -n "$PKG_SHA256" ] || PKG_SHA256="$(checksumNextTo "$PKG_LINK")" || exit 1
  [ -n "$PKG_SHA256" ] ||
    fail "$(printf "there is no %s.sha256 or .sha256.txt, pass the SHA-256 by -S." "$SOURCE_URL")"
}


# params: directory the archive was extracted to
# prints the directory to install: the folder that contains the release file,
# on macOS the bundle that contains Contents/Home/release if there is one
#---------------------------------------------------------------
function findHome {
#---------------------------------------------------------------
  local found=""
  if [ "$OS" = "mac" ]; then
    # some archives like Zulu's put the .jdk bundle into another folder
    found="$(find "$1" -maxdepth 5 -path '*/Contents/Home/release' -type f)"
  fi
  # others like Liberica's JRE for macOS have no bundle structure at all
  [ -n "$found" ] || found="$(find "$1" -maxdepth 3 -name release -type f)"
  local release count=0 home=""
  while IFS= read -r release; do
    [ -n "$release" ] || continue
    [ -x "$(dirname "$release")/bin/java" ] || continue
    home="$(dirname "$release")"
    case "$home" in
      */Contents/Home) home="$(dirname "$(dirname "$home")")" ;;
    esac
    count=$((count + 1))
  done <<< "$found"
  [ $count -eq 1 ] && printf "%s" "$home"
}


# params: file
# prints the SHA-256 of the file, or its SHA-1 if the package that was
# looked up has a SHA-1 only
#---------------------------------------------------------------
function checksumOf {
#---------------------------------------------------------------
  if [ -n "$PKG_SHA256" ]; then
    sha256 "$1"
  else
    sha1 "$1"
  fi
}


# params: file
# downloads the package that was looked up to the file, verifies its
# checksum and size
#---------------------------------------------------------------
function downloadVerified {
#---------------------------------------------------------------
  local checksum="${PKG_SHA256:-$PKG_SHA1}"
  printf "Downloading %s ...\n" "$PKG_LINK"
  curl -fL --retry 3 --progress-bar -o "$1" "$PKG_LINK" ||
    fail "$(printf "could not download %s." "$PKG_LINK")"

  if [ -n "$PKG_SHA256" ]; then
    printf "Verifying SHA-256 ...\n"
  else
    printf "Verifying SHA-1 ...\n"
  fi
  local actual
  actual="$(checksumOf "$1")"
  if [ "$actual" != "$checksum" ]; then
    fail "$(printf "checksum mismatch for %s:\n  expected %s\n  actual   %s" "$PKG_NAME" "$checksum" "$actual")"
  fi
  local actual_size
  actual_size="$(wc -c < "$1" | tr -d ' ')"
  if [ -n "$PKG_SIZE" ] && [ "$actual_size" != "$PKG_SIZE" ]; then
    fail "$(printf "size mismatch for %s: expected %s bytes, got %s bytes." "$PKG_NAME" "$PKG_SIZE" "$actual_size")"
  fi
}


# params: distribution, feature version, type, architecture
# looks up a variant for PKG_OS and PKG_FORMAT and downloads it to GET_DIR,
# along with a file of its checksum
#---------------------------------------------------------------
function getVariant {
#---------------------------------------------------------------
  local distro="$1" feature="$2" type="$3" arch="$4"
  case "$distro" in
    temurin) lookupAdoptium "$feature" "$type" "$arch" ;;
    *) lookupFoojay "$distro" "$feature" "$type" "$arch" ;;
  esac
  local file="${GET_DIR}/${PKG_NAME}" checksum="${PKG_SHA256:-$PKG_SHA1}"
  local sum_file="${file}.sha256"
  [ -n "$PKG_SHA256" ] || sum_file="${file}.sha1"
  printf "Release: %s (%s)\n" "$PKG_RELEASE" "$PKG_NAME"

  if [ $FORCE -eq 0 ] && [ -f "$file" ] && [ "$(checksumOf "$file")" = "$checksum" ]; then
    printf "Up to date: %s\n" "$file"
  elif [ $DRYRUN -eq 1 ]; then
    printf "Would download %s\n" "$PKG_LINK"
    printf "Would save it as %s\n" "$file"
    return 0
  else
    downloadVerified "${TMP_DIR}/${PKG_NAME}"
    mv -f "${TMP_DIR}/${PKG_NAME}" "$file" ||
      fail "$(printf "could not move the package to %s." "$file")"
    printf "Saved %s\n" "$file"
  fi
  # in the format of shasum and sha256sum, to check it by -c
  if [ $DRYRUN -eq 0 ] && [ "$(cat "$sum_file" 2>/dev/null)" != "${checksum}  ${PKG_NAME}" ]; then
    printf "%s  %s\n" "$checksum" "$PKG_NAME" > "$sum_file" ||
      fail "$(printf "could not write %s." "$sum_file")"
  fi
  GOT+=("$file" "$sum_file")
}


# params: distribution, feature version, type, architecture
# looks up, downloads, verifies and installs a variant, replaces an older
# installation
#---------------------------------------------------------------
function installVariant {
#---------------------------------------------------------------
  local distro="$1" feature="$2" type="$3" arch="$4"
  local dest
  dest="$(installDirOf "$distro" "$feature" "$type" "$arch")"
  local marker
  marker="$(markerOf "$dest")"

  # another architecture in the system's directory would confuse java_home
  # and update-alternatives, and might not even run
  [ "$arch" = "$ARCH" ] || [ "$TARGET_DIR" != "$DEFAULT_DIR" ] ||
    fail "$(printf "a %s for %s can only be installed into a directory of your own, use -d." "$type" "$arch")"

  case "$distro" in
    temurin) lookupAdoptium "$feature" "$type" "$arch" ;;
    custom) lookupUrl ;;
    *) lookupFoojay "$distro" "$feature" "$type" "$arch" ;;
  esac
  local name="$PKG_NAME" link="$PKG_LINK"
  local checksum="${PKG_SHA256:-$PKG_SHA1}"
  printf "Release: %s (%s)\n" "$PKG_RELEASE" "$name"

  local installed
  installed="$(installedVersion "$dest")"
  if [ -n "$installed" ]; then
    printf "Installed: %s in %s\n" "$installed" "$dest"
    local owner
    owner="$(packageOwner "$dest")"
    [ -z "$owner" ] ||
      fail "$(printf "%s is managed by the package %s, refusing to replace it." "$dest" "$owner")"
    local current
    case "$distro" in
      temurin) [ "$installed" = "$PKG_VERSION" ] && current=1 ;;
      custom) [ "$(releaseValue "$marker" checksum)" = "$checksum" ] && current=1 ;;
      *) [ "$(releaseValue "$marker" filename)" = "$name" ] && current=1 ;;
    esac
    if [ $FORCE -eq 0 ] && [ -n "$current" ]; then
      printf "Up to date.\n"
      return
    fi
  elif [ -e "$dest" ]; then
    fail "$(printf "%s exists, but it is not an installation of this script, refusing to replace it." "$dest")"
  fi

  if [ $DRYRUN -eq 1 ]; then
    printf "Would download %s\n" "$link"
    printf "Would install it in %s%s\n" "$dest" "${installed:+, replacing $installed}"
    return 0
  fi

  # check the privileges before the download rather than failing after it
  # a directory that does not exist yet is created in the nearest one that does
  local sudo=""
  if [ ! -w "$(existingAncestor "$TARGET_DIR")" ]; then
    [ -n "$SUDO" ] ||
      fail "$(printf "root privileges are required to write to %s, run as root." "$TARGET_DIR")"
    sudo="$SUDO"
    printf "Root privileges are required to write to %s.\n" "$TARGET_DIR"
    # asks for the password now rather than after the download
    $sudo true || fail "$(printf "could not obtain root privileges to write to %s." "$TARGET_DIR")"
  fi
  [ $KEEP -eq 0 ] || [ -w "$PWD" ] ||
    fail "$(printf "cannot keep the archive, %s is not writable." "$PWD")"
  # GNU tar unpacks .tar.xz by the xz command, BusyBox and macOS tar by themselves
  local compression="z"
  case "$name" in
    *.tar.xz|*.txz)
      compression="J"
      if [ "$OS" != "mac" ] && ! command -v xz > /dev/null 2>&1 && ! tar --version 2>&1 | grep -qi busybox; then
        local hint
        hint="$(installHint xz)"
        fail "$(printf "the command xz is required to unpack %s, but it is not installed%s." "$name" \
                       "${hint:+, install it by: $hint}")"
      fi ;;
  esac

  downloadVerified "${TMP_DIR}/${name}"

  local entries
  entries="$(tar "-t${compression}f" "${TMP_DIR}/${name}" 2>/dev/null)" ||
    fail "$(printf "%s is not a valid archive." "$name")"
  ! grep -qE '^/|(^|/)\.\.(/|$)' <<< "$entries" ||
    fail "$(printf "%s contains absolute paths or .., refusing to unpack it." "$name")"

  local extract="${TMP_DIR}/extract_${distro}_${feature}_${type}_${arch}"
  { mkdir -p "$extract" && tar "-x${compression}f" "${TMP_DIR}/${name}" -C "$extract"; } ||
    fail "$(printf "could not unpack %s." "$name")"
  if [ $KEEP -eq 1 ]; then
    if mv "${TMP_DIR}/${name}" "${PWD}/${name}"; then
      KEPT+=("${PWD}/${name}")
    else
      printf >&2 "WARNING: could not keep %s in %s.\n" "$name" "$PWD"
    fi
  else
    rm -f "${TMP_DIR}/${name}"
  fi
  local home
  home="$(findHome "$extract")"
  [ -n "$home" ] ||
    fail "$(printf "%s does not contain exactly one Java with a release file." "$name")"
  local os_arch found_arch
  os_arch="$(releaseValue "$(releaseFileOf "$home")" OS_ARCH)"
  if [ -n "$os_arch" ]; then
    found_arch="$(normalizeArch "$os_arch")" || found_arch="$os_arch"
    [ "$found_arch" = "$arch" ] ||
      fail "$(printf "%s contains a Java for %s rather than %s." "$name" "$found_arch" "$arch")"
  fi

  if [ "$distro" = "custom" ]; then
    # nothing but the archive tells what an arbitrary URL contains
    local release
    release="$(releaseFileOf "$home")"
    local java_version found
    java_version="$(releaseValue "$release" JAVA_VERSION)"
    case "$java_version" in
      1.*) found="${java_version#1.}"; found="${found%%[!0-9]*}" ;;
      *) found="${java_version%%[!0-9]*}" ;;
    esac
    [ "$found" = "$feature" ] ||
      fail "$(printf "%s contains Java %s rather than %s." "$name" "${java_version:-?}" "$feature")"
    local found_type="jre"
    [ -x "$(dirname "$release")/bin/javac" ] && found_type="jdk"
    [ "$found_type" = "$type" ] ||
      fail "$(printf "%s contains a %s rather than a %s, use -i %s:%s." "$name" "$found_type" "$type" "$feature" "$found_type")"
  fi

  $sudo mkdir -p "$TARGET_DIR" "$(dirname "$marker")" ||
    fail "$(printf "could not create %s." "$TARGET_DIR")"

  local backup="${dest}.old.$$"
  if [ -e "$dest" ]; then
    $sudo mv "$dest" "$backup" ||
      fail "$(printf "could not move %s out of the way." "$dest")"
  fi
  if ! $sudo mv "$home" "$dest"; then
    [ -e "$backup" ] && $sudo mv "$backup" "$dest"
    fail "$(printf "could not move the new installation to %s." "$dest")"
  fi
  [ -n "$sudo" ] && $sudo chown -R "$OWNER" "$dest"
  if [ -e "$backup" ]; then
    $sudo rm -rf "$backup" && printf "Removed the previous installation %s\n" "$installed"
  fi
  local source="foojay"
  case "$distro" in
    temurin) source="adoptium" ;;
    custom) source="url" ;;
  esac
  printf 'source="%s"\ndistro="%s"\narch="%s"\nfilename="%s"\nurl="%s"\nchecksum="%s"\n' \
         "$source" "$distro" "$arch" "$name" "$link" "$checksum" | $sudo tee "$marker" > /dev/null ||
    printf >&2 "WARNING: could not write %s.\n" "$marker"

  printf "Installed %s in %s\n" "$(installedVersion "$dest")" "$dest"
  [ "$arch" = "$ARCH" ] || return 0
  if [ "$OS" = "mac" ] && [ "$TARGET_DIR" = "$DEFAULT_DIR" ]; then
    # java_home finds bundles only, not archives without bundle structure
    if [ -f "${dest}/Contents/Info.plist" ]; then
      printf "Use it by: export JAVA_HOME=\$(/usr/libexec/java_home -v %s)\n" "$feature"
    else
      printf "Use it by: export JAVA_HOME=%s\n" "$(dirname "$(releaseFileOf "$dest")")"
    fi
  fi
  if [ "$OS" != "mac" ]; then
    printf "Use it by: export JAVA_HOME=%s\n" "$dest"
    registerAlternatives "$feature" "$type" "$dest"
  fi
  return 0
}


# params: alternatives group like java
# prints "<name>\t<link>" for each follower of the group, read from the
# admin file which has the same layout on Debian and RHEL: mode, master link,
# pairs of follower name and follower link, an empty line, the alternatives
#---------------------------------------------------------------
function alternativesFollowers {
#---------------------------------------------------------------
  local file
  for file in "/var/lib/alternatives/$1" "/var/lib/dpkg/alternatives/$1"; do
    [ -f "$file" ] || continue
    awk 'NR > 2 { if ($0 == "") exit; print }' "$file" | paste - -
    return
  done
}


# params: feature version, type, installation directory
# registers java (and javac of a jdk) with the alternatives system on Linux,
# the low priority keeps the distribution's default in auto mode
#---------------------------------------------------------------
function registerAlternatives {
#---------------------------------------------------------------
  [ -n "$ALTERNATIVES" ] && [ "$TARGET_DIR" = "$DEFAULT_DIR" ] || return 0
  local feature="$1" type="$2" dest="$3"
  local sudo=""
  if [ "$(id -u)" -ne 0 ]; then
    [ -n "$SUDO" ] || {
      printf >&2 "WARNING: root privileges are required to register %s with %s.\n" "$dest" "$ALTERNATIVES"
      return 0
    }
    sudo="$SUDO"
  fi

  # RHEL's alternatives calls them followers, Debian's update-alternatives slaves
  local option="--slave"
  "$ALTERNATIVES" --help 2>&1 | grep -q -- "--follower" && option="--follower"

  local tools="java" tool name link file candidate followers missing
  [ "$type" = "jdk" ] && tools="java javac"
  for tool in $tools; do
    [ -x "${dest}/bin/${tool}" ] || continue
    # an alternative without the group's followers would remove their links
    # once it is selected, so provide every follower this installation has
    followers=()
    missing=""
    while IFS=$'\t' read -r name link; do
      [ -n "$name" ] || continue
      file=""
      for candidate in "${dest}/bin/${name}" "${dest}/lib/${name}" \
                       "${dest}/man/man1/$(basename "$link")"; do
        [ -f "$candidate" ] && { file="$candidate"; break; }
      done
      if [ -n "$file" ]; then
        followers+=("$option" "$link" "$name" "$file")
      else
        missing="${missing} ${name}"
      fi
    done < <(alternativesFollowers "$tool")

    if $sudo "$ALTERNATIVES" --install "/usr/bin/${tool}" "$tool" "${dest}/bin/${tool}" "$feature" \
         "${followers[@]}" > /dev/null; then
      printf "Registered %s with %s\n" "${dest}/bin/${tool}" "$ALTERNATIVES"
      [ -z "$missing" ] ||
        printf "  not provided by this installation:%s\n" "$missing"
    else
      printf >&2 "WARNING: could not register %s with %s.\n" "${dest}/bin/${tool}" "$ALTERNATIVES"
    fi
  done
  printf "Select it by: %s%s --config java\n" "${sudo:+$sudo }" "$ALTERNATIVES"
  return 0
}


# params: installation directory
# updates the time zone data of the installation to the latest IANA release,
# or to the one at TZDATA_URL, by Oracle's tzupdater, which always updates
# the java it is started with
#---------------------------------------------------------------
function updateTzdata {
#---------------------------------------------------------------
  if [ $DRYRUN -eq 1 ]; then
    printf "Would update the time zone data of %s by %s\n" "$1" "$TZUPDATER"
    return 0
  fi
  local home
  home="$(dirname "$(releaseFileOf "$1")")"
  local java="${home}/bin/java"
  [ -x "$java" ] || fail "$(printf "%s does not contain an executable java." "$1")"

  local sudo=""
  if [ ! -w "${home}/lib" ]; then
    [ -n "$SUDO" ] ||
      fail "$(printf "root privileges are required to update the time zone data of %s, run as root." "$1")"
    sudo="$SUDO"
  fi

  # with -O, pretend to be Oracle's java for tzupdaters that check the vendor
  local args=()
  [ $ORACLE_VENDOR -eq 1 ] && args+=("-Djava.vendor=Oracle Corporation")
  args+=(-jar "$TZUPDATER" -l)
  [ -z "$TZDATA_URL" ] || args+=("$TZDATA_URL")

  printf "Updating the time zone data of %s ...\n" "$1"
  local output status
  output="$($sudo "$java" "${args[@]}" 2>&1)"
  status=$?
  [ -z "$output" ] || printf "%s\n" "$output"
  # the tzupdater also fails if the time zone data is up to date already
  case "$status:$output" in
    0:*|*"has the same version"*) ;;
    *) fail "$(printf "could not update the time zone data of %s." "$1")" ;;
  esac
  "$java" -jar "$TZUPDATER" -V 2>/dev/null | grep "JRE tzdata version"
  return 0
}


# params: installation directory
# tests whether the java of the installation runs
#---------------------------------------------------------------
function testJava {
#---------------------------------------------------------------
  local java
  java="$(dirname "$(releaseFileOf "$1")")/bin/java"
  if [ $DRYRUN -eq 1 ]; then
    printf "Would execute \"%s -Xmx10m -version\"\n" "$java"
    return 0
  fi
  printf "Executing \"%s -Xmx10m -version\" ...\n" "$java"
  # a small heap keeps Java's ergonomics from reserving much memory on large systems
  "$java" -Xmx10m -version || fail "$(printf "%s does not run." "$java")"
}


# params: distribution, feature version, type, architecture
# installs a variant, updates its time zone data if -z is given and tests it
# if -t is given
#---------------------------------------------------------------
function installVariantAndTzdata {
#---------------------------------------------------------------
  installVariant "$1" "$2" "$3" "$4"
  local dir
  dir="$(installDirOf "$1" "$2" "$3" "$4")"
  # a Java of another architecture may run, like x64 by Rosetta 2 on macOS
  if [ "$4" != "$ARCH" ] && [ $DRYRUN -eq 0 ] && { [ -n "$TZUPDATER" ] || [ $TEST -eq 1 ]; } &&
     ! "$(dirname "$(releaseFileOf "$dir")")/bin/java" -version > /dev/null 2>&1; then
    printf >&2 "WARNING: the %s java of %s does not run on this machine, skipping -z and -t.\n" "$4" "$dir"
    return 0
  fi
  [ -z "$TZUPDATER" ] || updateTzdata "$dir"
  [ $TEST -eq 0 ] || testJava "$dir"
}


# sets LINK_PATH from LINK: an existing symbolic link is replaced, a directory
# or the directory of -d gets a link named latest, any other path is the name
# of the link
#---------------------------------------------------------------
function resolveLinkPath {
#---------------------------------------------------------------
  # check -L before -d, a link to a directory is a directory to -d
  if [ -L "$LINK" ]; then
    LINK_PATH="$LINK"
  elif [ -d "$LINK" ]; then
    LINK_PATH="${LINK%/}/latest"
  elif [ -n "$TARGET_DIR" ] && [ "$(physicalPath "$LINK")" = "$(physicalPath "$TARGET_DIR")" ]; then
    # the directory of -d is created by the installation
    LINK_PATH="${LINK%/}/latest"
    return
  else
    LINK_PATH="$LINK"
  fi
  [ -d "$(dirname "$LINK_PATH")" ] ||
    fail "$(printf "%s is not a directory." "$(dirname "$LINK_PATH")")"
  [ ! -e "$LINK_PATH" ] || [ -L "$LINK_PATH" ] ||
    fail "$(printf "%s exists, but it is not a symbolic link, refusing to replace it." "$LINK_PATH")"
}


# params: absolute directory, absolute path, both without symbolic links
# prints the path relative to the directory
#---------------------------------------------------------------
function relativePath {
#---------------------------------------------------------------
  local common="$1" to="$2" up="" rest
  while [ "$common" != "/" ] && [ "$to" != "$common" ] && [ "${to#"$common"/}" = "$to" ]; do
    common="$(dirname "$common")"
    up="../${up}"
  done
  if [ "$to" = "$common" ]; then
    rest=""
  elif [ "$common" = "/" ]; then
    rest="${to#/}"
  else
    rest="${to#"$common"/}"
  fi
  rest="${up}${rest}"
  rest="${rest%/}"
  printf "%s" "${rest:-.}"
}


# params: path
# prints the nearest directory of the path that exists, the path itself if it
# is a directory
#---------------------------------------------------------------
function existingAncestor {
#---------------------------------------------------------------
  local dir="$1"
  while [ ! -d "$dir" ]; do
    dir="$(dirname "$dir")"
  done
  printf "%s" "$dir"
}


# params: path, which does not need to exist
# prints the absolute path without symbolic links, as far as it exists
#---------------------------------------------------------------
function physicalPath {
#---------------------------------------------------------------
  local dir rest=""
  dir="$(existingAncestor "$1")"
  if [ "$dir" != "$1" ]; then
    # dirname ends at . for a relative path, which is not its prefix
    if [ "$dir" = "." ] && [ "${1#./}" = "$1" ]; then
      rest="$1"
    else
      rest="${1#"$dir"}"
    fi
  fi
  rest="/${rest#/}"
  local base
  base="$(cd "$dir" && pwd -P)"
  [ "$rest" = "/" ] && { printf "%s" "$base"; return; }
  printf "%s%s" "${base%/}" "$rest"
}


# params: installation directory
# points the symbolic link LINK_PATH to the java home of the installation
#---------------------------------------------------------------
function createLink {
#---------------------------------------------------------------
  [ -n "$1" ] || { printf >&2 "WARNING: no variant was updated, %s is unchanged.\n" "$LINK_PATH"; return 0; }
  local home
  home="$(dirname "$(releaseFileOf "$1")")"
  [ $DRYRUN -eq 1 ] || [ -d "$home" ] || fail "$(printf "%s does not exist." "$home")"
  # a relative target keeps the link valid if both are moved together, in a
  # dry run the installation may not exist yet
  local link_dir
  link_dir="$(physicalPath "$(dirname "$LINK_PATH")")"
  local target
  target="$(relativePath "$link_dir" "$(physicalPath "$home")")"
  if [ $DRYRUN -eq 1 ]; then
    printf "Would link %s -> %s\n" "$LINK_PATH" "$target"
    return 0
  fi

  local sudo=""
  if [ ! -w "$link_dir" ]; then
    [ -n "$SUDO" ] ||
      fail "$(printf "root privileges are required to create %s, run as root." "$LINK_PATH")"
    sudo="$SUDO"
  fi
  # -n replaces a link to a directory rather than creating a link inside of it
  $sudo ln -sfn "$target" "$LINK_PATH" ||
    fail "$(printf "could not create the symbolic link %s." "$LINK_PATH")"
  printf "Linked %s -> %s\n" "$LINK_PATH" "$target"
}


# params: [<variant>]
# updates the given installed variant, or all installed variants (of the
# distribution if -a is given), sets LINK_DIR to the given one, or to the one
# of the highest feature version, Temurin first, this machine's architecture
# first, a jdk before a jre
#---------------------------------------------------------------
function updateVariants {
#---------------------------------------------------------------
  if [ -n "$1" ]; then
    parseVariant "$DISTRO" "$1"
    LINK_DIR="$(installDirOf "$DISTRO" "$FEATURE" "$TYPE" "$VARIANT_ARCH")"
    if [ -z "$(installedVersion "$LINK_DIR")" ]; then
      # name the distributions that have this variant installed, if any
      local variant distro feature type arch others=""
      for variant in $(listInstalled); do
        IFS=: read -r distro feature type arch <<< "$variant"
        [ "$feature:$type:$arch" = "$FEATURE:$TYPE:$VARIANT_ARCH" ] && [ "$distro" != "custom" ] &&
          others="${others:+$others, }${distro}"
      done
      [ -z "$others" ] ||
        fail "$(printf "there is no %s %s %s for %s in %s, but one from %s, use -a %s." \
                       "$DISTRO" "$TYPE" "$FEATURE" "$VARIANT_ARCH" "$TARGET_DIR" "$others" "${others%%,*}")"
      fail "$(printf "%s %s %s for %s is not installed in %s, use -i to install it." \
                     "$DISTRO" "$TYPE" "$FEATURE" "$VARIANT_ARCH" "$TARGET_DIR")"
    fi
    installVariantAndTzdata "$DISTRO" "$FEATURE" "$TYPE" "$VARIANT_ARCH"
    return
  fi

  local filter=""
  [ $DISTRO_GIVEN -eq 0 ] || filter="$DISTRO"
  local variants
  variants="$(listInstalled "$filter")"
  [ -n "$variants" ] ||
    fail "$(printf "there is no %s installed in %s, use -i to install one." "${filter:-variant}" "$TARGET_DIR")"
  local variant distro feature type arch rank arch_rank updated=""
  for variant in $variants; do
    IFS=: read -r distro feature type arch <<< "$variant"
    if [ "$distro" = "custom" ]; then
      printf "\nSkipping %s, it was installed from a URL, update it by -i %s:%s%s -s <url>\n" \
             "$(installDirOf "$distro" "$feature" "$type" "$arch")" "$feature" "$type" \
             "$([ "$arch" = "$ARCH" ] || printf ":%s" "$arch")"
      continue
    fi
    installVariantAndTzdata "$distro" "$feature" "$type" "$arch"
    # sortable by feature version, Temurin first, this machine's architecture
    # first, distribution and type
    [ "$distro" = "temurin" ] && rank=0 || rank=1
    [ "$arch" = "$ARCH" ] && arch_rank=0 || arch_rank=1
    updated="${updated}${feature}:${rank}:${arch_rank}:${distro}:${type}:${arch}"$'\n'
  done
  variant="$(printf "%s" "$updated" | sort -t: -k1,1nr -k2,2n -k3,3n -k4,4 -k5,5 | head -1)"
  [ -z "$variant" ] && return
  IFS=: read -r feature rank arch_rank distro type arch <<< "$variant"
  LINK_DIR="$(installDirOf "$distro" "$feature" "$type" "$arch")"
}


# params: action
#---------------------------------------------------------------
function setAction {
#---------------------------------------------------------------
  [ -z "$ACTION" ] || { usage >&2; fail "only one of -l, -i, -u and -g can be given."; }
  ACTION="$1"
}


#---------------------------------------------------------------
function main {
#---------------------------------------------------------------
  FORCE=0
  ORACLE_VENDOR=0
  KEEP=0
  TEST=0
  KEPT=()
  GOT=()
  OS_ARG=""
  FORMAT_ARG=""
  DRYRUN=0
  ACTION=""
  VARIANT=""
  LIST_ARG=""
  TARGET_DIR=""
  TZUPDATER=""
  TZDATA_URL=""
  LINK=""
  LINK_DIR=""
  DISTRO="temurin"
  DISTRO_GIVEN=0
  SOURCE_URL=""
  SHA256_ARG=""

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -l|--list)
        setAction list
        if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then LIST_ARG="$2"; shift; fi ;;
      -i|--install)
        setAction install
        [ -n "$2" ] && [ "${2#-}" = "$2" ] || { usage >&2; fail "$(printf "%s requires a variant." "$1")"; }
        VARIANT="$2"; shift ;;
      -g|--get)
        setAction get
        [ -n "$2" ] && [ "${2#-}" = "$2" ] || { usage >&2; fail "$(printf "%s requires a variant." "$1")"; }
        VARIANT="$2"; shift ;;
      -o|--os)
        [ -n "$2" ] || { usage >&2; fail "$(printf "%s requires an operating system." "$1")"; }
        OS_ARG="$(printf "%s" "$2" | tr '[:upper:]' '[:lower:]')"; shift ;;
      -p|--package)
        [ -n "$2" ] || { usage >&2; fail "$(printf "%s requires a format." "$1")"; }
        FORMAT_ARG="$(printf "%s" "$2" | tr '[:upper:]' '[:lower:]')"; FORMAT_ARG="${FORMAT_ARG#.}"; shift ;;
      -u|--update)
        setAction update
        if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then VARIANT="$2"; shift; fi ;;
      -a|--api)
        DISTRO_GIVEN=1
        if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
          DISTRO="$(printf "%s" "$2" | tr '[:upper:]' '[:lower:]')"; shift
          [ "$DISTRO" = "adoptium" ] && DISTRO="temurin"
        else
          # without a distribution, -l lists the distributions
          DISTRO=""
        fi ;;
      -s|--source)
        [ -n "$2" ] || { usage >&2; fail "$(printf "%s requires a URL." "$1")"; }
        SOURCE_URL="$2"; shift ;;
      -S|--sha256)
        [ -n "$2" ] || { usage >&2; fail "$(printf "%s requires a hash." "$1")"; }
        SHA256_ARG="$(printf "%s" "$2" | tr '[:upper:]' '[:lower:]')"; shift
        [[ "$SHA256_ARG" =~ ^[0-9a-f]{64}$ ]] ||
          fail "$(printf "%s is not a SHA-256, it needs 64 hex digits." "$SHA256_ARG")" ;;
      -d|--dir)
        [ -n "$2" ] || { usage >&2; fail "$(printf "%s requires a path." "$1")"; }
        TARGET_DIR="$2"; [ "$TARGET_DIR" = "/" ] || TARGET_DIR="${TARGET_DIR%/}"; shift ;;
      -n|--dry-run) DRYRUN=1 ;;
      -f|--force) FORCE=1 ;;
      -O|--oracle-vendor) ORACLE_VENDOR=1 ;;
      -k|--keep) KEEP=1 ;;
      -t|--test) TEST=1 ;;
      -L|--link)
        if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
          LINK="$2"; [ "$LINK" = "/" ] || LINK="${LINK%/}"; shift
        else
          # without a path, the link is latest in the current directory, which
          # must not be taken for a link to replace if entered by a link
          LINK="$(pwd -P)"
        fi ;;
      -z|--tzupdater)
        if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
          TZUPDATER="$2"; shift
        else
          TZUPDATER="${SCRIPT_DIR}/tzupdater.jar"
          [ -f "$TZUPDATER" ] ||
            fail "$(printf "%s does not exist, download it from %s or pass its path to %s." \
                           "$TZUPDATER" "$TZUPDATER_URL" "$1")"
        fi ;;
      -Z|--tzdata)
        [ -n "$2" ] || { usage >&2; fail "$(printf "%s requires a URL." "$1")"; }
        TZDATA_URL="$2"; shift ;;
      -h|--help) usage; exit 0 ;;
      -v|--version) version; exit 0 ;;
      -C|--copyright) copyright; exit 0 ;;
      *) usage >&2; fail "$(printf "unknown argument %s." "$1")" ;;
    esac
    shift
  done
  [ -n "$ACTION" ] || { usage >&2; fail "one of -l, -i, -u and -g is required."; }
  [ -n "$DISTRO" ] || [ "$ACTION" = "list" ] ||
    { usage >&2; fail "-a requires a distribution, list them by -l -a."; }
  local option
  if [ "$ACTION" = "list" ] || [ "$ACTION" = "get" ]; then
    for option in "$KEEP:-k" "$TEST:-t" "${LINK:+1}:-L" "${TZUPDATER:+1}:-z"; do
      case "$option" in
        1:*) usage >&2; fail "$(printf "%s can only be used with -i and -u." "${option#1:}")" ;;
      esac
    done
  fi
  [ $DRYRUN -eq 0 ] || [ "$ACTION" != "list" ] || { usage >&2; fail "-n can only be used with -i, -u and -g."; }
  [ $FORCE -eq 0 ] || [ "$ACTION" != "list" ] || { usage >&2; fail "-f can only be used with -i, -u and -g."; }
  if [ "$ACTION" = "install" ] || [ "$ACTION" = "update" ]; then
    for option in "${OS_ARG:+1}:-o" "${FORMAT_ARG:+1}:-p"; do
      case "$option" in
        1:*) usage >&2; fail "$(printf "%s can only be used with -l and -g." "${option#1:}")" ;;
      esac
    done
  fi
  # -g saves to the current directory, or to the one given by -d
  GET_DIR="${TARGET_DIR:-$PWD}"
  if [ "$ACTION" = "get" ]; then
    [ -d "$GET_DIR" ] && [ -w "$GET_DIR" ] || fail "$(printf "%s is not a writable directory." "$GET_DIR")"
  fi
  [ -z "$TZDATA_URL" ] || [ -n "$TZUPDATER" ] || { usage >&2; fail "-Z can only be used with -z."; }
  [ $ORACLE_VENDOR -eq 0 ] || [ -n "$TZUPDATER" ] || { usage >&2; fail "-O can only be used with -z."; }
  [ -z "$SHA256_ARG" ] || [ -n "$SOURCE_URL" ] || { usage >&2; fail "-S can only be used with -s."; }
  if [ -n "$SOURCE_URL" ]; then
    [ "$ACTION" = "install" ] || { usage >&2; fail "-s can only be used with -i."; }
    [ $DISTRO_GIVEN -eq 0 ] || { usage >&2; fail "-s and -a cannot be used together."; }
    case "${VARIANT%%:*}" in
      ""|*[!0-9]*) usage >&2; fail "with -s, the variant needs a feature version like 21, not lts or latest." ;;
    esac
    DISTRO="custom"
  fi
  if [ -n "$TZUPDATER" ]; then
    [ -f "$TZUPDATER" ] && [ -r "$TZUPDATER" ] ||
      fail "$(printf "%s is not a readable file." "$TZUPDATER")"
    # an absolute path is unambiguous under sudo or doas as well
    TZUPDATER="$(cd "$(dirname "$TZUPDATER")" && pwd)/$(basename "$TZUPDATER")"
  fi
  [ -z "$LINK" ] || resolveLinkPath

  detectPlatform
  SUDO="$(rootCommand)"
  checkPrerequisites curl tar "${SHA_CMD%% *}"
  setPackagePlatform "${OS_ARG:-$OS}"
  # the formats to look for, an installation can be made of tar.gz and tar.xz
  PKG_FORMATS="$PKG_FORMAT"
  [ "$ACTION" = "install" ] || [ "$ACTION" = "update" ] && PKG_FORMATS="tar.gz tar.xz"

  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/updatejdk.XXXXXX")" || fail "could not create a temporary directory."
  trap 'rm -rf "$TMP_DIR"' EXIT
  command -v jq > /dev/null 2>&1 || fetchJq

  case "$DISTRO" in
    temurin|custom|"") ;;
    *) checkFoojayDistro "$DISTRO" ;;
  esac
  # the argument of -l is an architecture, or a variant to list only that
  LIST_ARCH="$ARCH"
  LIST_FEATURE=""
  LIST_TYPE=""
  # -l -a lists only the distributions for the platform if any is given
  LIST_FILTERED=0
  [ -z "$LIST_ARG$OS_ARG$FORMAT_ARG" ] || LIST_FILTERED=1
  if [ -n "$LIST_ARG" ]; then
    if [ -z "$DISTRO" ]; then
      case "${LIST_ARG%%:*}" in
        lts|latest) usage >&2; fail "$(printf "%s depends on the distribution, -l -a needs a feature version like 21." "${LIST_ARG%%:*}")" ;;
      esac
    fi
    if ! LIST_ARCH="$(normalizeArch "$LIST_ARG")"; then
      parseVariant "$DISTRO" "$LIST_ARG"
      LIST_FEATURE="$FEATURE"
      [ $TYPE_GIVEN -eq 0 ] || LIST_TYPE="$TYPE"
      LIST_ARCH="$VARIANT_ARCH"
    fi
  fi

  case "$ACTION" in
    list) if [ -n "$DISTRO" ]; then listVariants; else listDistros; fi ;;
    install)
      parseVariant "$DISTRO" "$VARIANT"
      installVariantAndTzdata "$DISTRO" "$FEATURE" "$TYPE" "$VARIANT_ARCH"
      LINK_DIR="$(installDirOf "$DISTRO" "$FEATURE" "$TYPE" "$VARIANT_ARCH")" ;;
    update) updateVariants "$VARIANT" ;;
    get)
      parseVariant "$DISTRO" "$VARIANT"
      getVariant "$DISTRO" "$FEATURE" "$TYPE" "$VARIANT_ARCH" ;;
  esac
  [ -z "$LINK" ] || createLink "$LINK_DIR"
  if [ ${#KEPT[@]} -gt 0 ]; then
    printf "\nKept the downloaded archive(s):\n"
    printf "  %s\n" "${KEPT[@]}"
  fi
  if [ ${#GOT[@]} -gt 0 ] && [ $DRYRUN -eq 0 ]; then
    printf "\nFiles:\n"
    printf "  %s\n" "${GOT[@]}"
  fi
  [ $DRYRUN -eq 0 ] || printf "\nDry run, nothing was changed.\n"
  printf "Done.\n"
}

main "$@"
