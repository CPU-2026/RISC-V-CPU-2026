#!/usr/bin/env bash
#
# Fetch and pin the ASAP7 7.5T NLDM timing libraries used for area mapping.
#
# Provenance is pinned to a single OpenROAD-flow-scripts commit and every
# artifact is verified by SHA-256 twice: once on the downloaded file and once
# on the decompressed Liberty file. Nothing is replaced until both checks pass.
#
# The script is idempotent:
#   * a library already present in build/asap7/ with the pinned SHA-256 is left
#     alone and does not touch the network;
#   * a cached download in build/asap7/cache/ is reused offline;
#   * run with --force to re-download, or --verify to check without changing
#     anything.
#
# Usage: scripts/fetch_asap7.sh [--force|--verify] [--out DIR]
set -euo pipefail

readonly ORFS_COMMIT=3dd5892cd1d7559b1c9a1efadd25adde5b6c2820
readonly NLDM_SUBDIR=flow/platforms/asap7/lib/NLDM
readonly BASE_URL="https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/${ORFS_COMMIT}/${NLDM_SUBDIR}"

# RVT / TT corner. Fields: artifact name | artifact sha256 | Liberty sha256.
#
# Four of the five groups ship gzipped; SEQ RVT TT ships as a plain .lib, so
# decompression is applied only where the artifact is actually compressed.
# Note: the INVBUF file is named ..._220122 but its own Liberty header still
# reads asap7sc7p5t_INVBUF_RVT_TT_nldm_211120; that mismatch is upstream's.
readonly -a LIB_SPECS=(
  "asap7sc7p5t_AO_RVT_TT_nldm_211120.lib.gz|fe9f1c18e88ab129d63ad82adc256f3a85c7e38e47dabbe0a96749b41087dea1|b1ece108c0a2acd8d01c05cee6daee2834425037b1d9aad625d6f1dd640f1940"
  "asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.lib.gz|8d6db2c2f83c3c162be54a5e102b2d379fcaaaef2db5f0b1d4152c395d01fea1|a4ceb32e418e1aac8667e28fbd8e9e46baf520180be4db075598a4d7c681a56e"
  "asap7sc7p5t_OA_RVT_TT_nldm_211120.lib.gz|bbe6d904d58c7367de1ed7639e4eae386c65fa0a5af26ae62dc5e4e2ec52b08b|6529c6c72465cd133dfbfb03952327ab2774bb6aa4be866d78fd7bc6c58c9f6f"
  "asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.lib.gz|073ac4b6b08f272b6953b0ad54d1d9743767a7d15a0e2964ed86cf44c3dbe00e|fa92e6ab1481810602811b1eea54bc016a341f11fb5188d7512c026599adf038"
  "asap7sc7p5t_SEQ_RVT_TT_nldm_220123.lib|57a0b403485b99ebd676942af4673ac086b86c7c75fbdc3e5c0038501dd22ba3|57a0b403485b99ebd676942af4673ac086b86c7c75fbdc3e5c0038501dd22ba3"
)

mode=fetch
root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="$root/build/asap7"

while [ $# -gt 0 ]; do
  case "$1" in
    --force)  mode=force ;;
    --verify) mode=verify ;;
    --out)    out_dir="$2"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

cache_dir="$out_dir/cache"
stamp="$out_dir/.fetch-asap7.stamp"

die() { printf 'fetch_asap7: %s\n' "$*" >&2; exit 1; }

sha256_of() {
  # sha256sum prints "<hash>  <path>"; keep the hash only.
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  else
    die "no sha256sum or shasum available"
  fi
}

verify_sha() {
  local path="$1" expect="$2" actual
  [ -f "$path" ] || return 1
  actual="$(sha256_of "$path")"
  [ "$actual" = "$expect" ] || {
    printf 'fetch_asap7: checksum mismatch for %s\n  expected %s\n  actual   %s\n' \
      "$(basename "$path")" "$expect" "$actual" >&2
    return 1
  }
}

lib_name_of() {
  case "$1" in
    *.gz) printf '%s' "${1%.gz}" ;;
    *)    printf '%s' "$1" ;;
  esac
}

[ "$mode" = verify ] || mkdir -p "$cache_dir"

printf 'ASAP7 NLDM (RVT/TT) -> %s\n' "${out_dir#"$root"/}"
printf '  source: OpenROAD-flow-scripts@%s\n' "${ORFS_COMMIT:0:12}"

missing=0
stale=0
for spec in "${LIB_SPECS[@]}"; do
  IFS='|' read -r artifact artifact_sha lib_sha <<<"$spec"
  lib="$(lib_name_of "$artifact")"
  target="$out_dir/$lib"
  cached="$cache_dir/$artifact"

  if [ "$mode" != force ] && verify_sha "$target" "$lib_sha"; then
    printf '  %-46s ok (already pinned)\n' "$lib"
    continue
  fi
  stale=$((stale + 1))

  if [ "$mode" = verify ]; then
    printf '  %-46s MISSING/STALE\n' "$lib"
    missing=$((missing + 1))
    continue
  fi

  if [ "$mode" = fetch ] && verify_sha "$cached" "$artifact_sha"; then
    printf '  %-46s using cached download\n' "$lib"
  else
    printf '  %-46s downloading %s\n' "$lib" "$artifact"
    command -v curl >/dev/null 2>&1 || die "curl is required to download $artifact"
    rm -f "$cached.part"
    curl -fsSL --max-time 300 -o "$cached.part" "$BASE_URL/$artifact" \
      || die "download failed for $BASE_URL/$artifact"
    verify_sha "$cached.part" "$artifact_sha" \
      || die "downloaded artifact failed verification: $artifact"
    mv "$cached.part" "$cached"
  fi

  rm -f "$target.part"
  case "$artifact" in
    *.gz)
      command -v gzip >/dev/null 2>&1 || die "gzip is required to unpack $artifact"
      gzip -dc "$cached" > "$target.part" || die "gunzip failed for $artifact"
      ;;
    *) cp "$cached" "$target.part" ;;
  esac
  verify_sha "$target.part" "$lib_sha" \
    || die "decompressed Liberty failed verification: $lib"
  mv "$target.part" "$target"
  printf '  %-46s %s bytes verified\n' "$lib" "$(stat -c%s "$target")"
done

if [ "$mode" = verify ]; then
  if [ "$missing" -ne 0 ]; then
    printf 'fetch_asap7: %d of %d libraries missing or stale\n' \
      "$missing" "${#LIB_SPECS[@]}" >&2
    exit 1
  fi
  printf 'fetch_asap7: all %d libraries pinned\n' "${#LIB_SPECS[@]}"
  exit 0
fi

{
  printf '# ASAP7 NLDM RVT/TT libraries pinned by scripts/fetch_asap7.sh\n'
  printf '# source: https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts@%s\n' "$ORFS_COMMIT"
  printf '# subdir: %s\n' "$NLDM_SUBDIR"
  for spec in "${LIB_SPECS[@]}"; do
    IFS='|' read -r artifact artifact_sha lib_sha <<<"$spec"
    printf '%s %s\n' "$lib_sha" "$(lib_name_of "$artifact")"
  done
} > "$stamp"

printf 'fetch_asap7: %d libraries ready, %d (re)verified\n' \
  "${#LIB_SPECS[@]}" "$stale"
