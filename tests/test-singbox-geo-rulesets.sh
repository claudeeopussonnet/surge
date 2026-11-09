#!/usr/bin/env bash
# Offline GeoIP/GeoSite downloads, failed builds and process-group interruption.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export VLESS_TEST_CFG="$TMP/etc"
export VLESS_TEST_SYSTEMD_DIR="$TMP/systemd"
export VLESS_TEST_OPENRC_DIR="$TMP/openrc"
export GEO_TEST_TMP="$TMP" GEO_TEST_MODE=ok
mkdir -p "$TMP/bin" "$VLESS_TEST_CFG" "$VLESS_TEST_SYSTEMD_DIR" "$VLESS_TEST_OPENRC_DIR"
source "$ROOT/vless-server.sh"
svc() { printf 'unexpected service operation\n' >&2; return 1; }

# A real executable is needed because the builder calls curl from Python.
cat >"$TMP/bin/curl" <<'PY'
#!/usr/bin/env python3
import json, os, signal, sys, time
from pathlib import Path
root = Path(os.environ['GEO_TEST_TMP'])
mode = os.environ['GEO_TEST_MODE']
args = sys.argv[1:]
assert args[:5] == ['-fsSL', '--connect-timeout', '10', '--max-time', '30'], args
url = args[-1]
with (root / 'downloads').open('a') as out:
    out.write(url + '\n')
if mode == 'timeout':
    print('curl: (28) Operation timed out', file=sys.stderr)
    sys.exit(28)
if mode == 'interrupt':
    (root / 'ready').touch()
    signal.signal(signal.SIGINT, lambda *_: sys.exit(130))
    time.sleep(10)
    sys.exit(1)
if mode == 'empty':
    sys.exit(0)
if mode == 'invalid':
    print('<html>invalid source</html>')
elif '/geoip/release/text/' in url:
    print('# fixture\n192.0.2.0/24\n2001:db8::/32')
elif url.endswith('/google'):
    print('include:fixture\ninclude:fixture\nfull:exact.example\nkeyword:search\nregexp:^chat[0-9]+\\.example$\ndomain:google.example @fixture')
elif url.endswith('/fixture'):
    print('include:google\nfixture.example')
elif url.endswith('/category-public-tracker'):
    print('public-tracker.example')
elif url.endswith('/category-pt'):
    print('private-tracker.example')
else:
    raise SystemExit('unexpected URL: ' + url)
PY
cat >"$TMP/bin/compiler" <<'SH'
#!/usr/bin/env bash
set -eu
[[ "$1" == rule-set && "$2" == compile && "$4" == -o ]]
printf '%s\n' "$3" >>"$GEO_TEST_TMP/compiles"
jq -e '.version==3 and (.rules|length)>0' "$3" >/dev/null
if [[ "$GEO_TEST_MODE" == compile-fail ]]; then
    printf 'partial output\n' >"$5"
    exit 1
fi
cp "$3" "$5"
SH
chmod +x "$TMP/bin/curl" "$TMP/bin/compiler"
export PATH="$TMP/bin:$PATH"
export SINGBOX_CONFIG_BINARY="$TMP/bin/compiler"

assert_clean() {
    [[ -z "$(find "$CFG/ruleset" "$CFG/ruleset-src" -name '.*' -type f -print)" ]]
}
_build_singbox_geoip_ruleset geoip-google
jq -e '.rules==[{ip_cidr:["192.0.2.0/24","2001:db8::/32"]}]' "$CFG/ruleset-src/geoip-google.json" >/dev/null
_build_singbox_geosite_ruleset geosite-google
jq -e '.rules[0] | .domain==["exact.example"] and
    .domain_suffix==["fixture.example","google.example"] and
    .domain_keyword==["search"] and .domain_regex==["^chat[0-9]+\\.example$"]' \
    "$CFG/ruleset-src/geosite-google.json" >/dev/null
[[ $(wc -l <"$TMP/downloads") == 3 ]]
_build_singbox_geosite_ruleset geosite-tracker
jq -e '.rules[0].domain_suffix==["private-tracker.example","public-tracker.example"]' \
    "$CFG/ruleset-src/geosite-tracker.json" >/dev/null
[[ $(stat -c %a "$CFG/ruleset/geoip-google.srs") == 600 ]]
[[ $(stat -c %a "$CFG/ruleset-src/geoip-google.json") == 600 ]]
assert_clean
printf '%s\n' 'ok - bounded curl flags, IPv4/IPv6 conversion, recursive includes, deduplication, tracker union and permissions'

cp "$CFG/ruleset-src/geoip-google.json" "$TMP/previous.json"
cp "$CFG/ruleset/geoip-google.srs" "$TMP/previous.srs"
for GEO_TEST_MODE in timeout empty invalid compile-fail; do
    before=$(wc -l <"$TMP/compiles")
    if _build_singbox_geoip_ruleset geoip-google >"$TMP/output" 2>&1; then
        printf 'unexpected success: %s\n' "$GEO_TEST_MODE" >&2
        exit 1
    fi
    cmp "$TMP/previous.json" "$CFG/ruleset-src/geoip-google.json"
    cmp "$TMP/previous.srs" "$CFG/ruleset/geoip-google.srs"
    if [[ "$GEO_TEST_MODE" != compile-fail ]]; then
        [[ $(wc -l <"$TMP/compiles") == "$before" ]]
    fi
    ! rg -q 'Traceback' "$TMP/output"
    assert_clean
done
GEO_TEST_MODE=timeout
if _build_singbox_geosite_ruleset geosite-google >"$TMP/output" 2>&1; then exit 1; fi
rg -q 'curl 28' "$TMP/output"
assert_clean
printf '%s\n' 'ok - failed downloads never compile stale sources; empty/invalid sources and partial compilation preserve caches'

GEO_TEST_MODE=interrupt
python3 - "$ROOT/vless-server.sh" <<'PY'
import os, signal, subprocess, sys, time
from pathlib import Path
root = Path(os.environ['GEO_TEST_TMP'])
process = subprocess.Popen(
    ['bash', '-c', 'source "$1"; _build_singbox_geoip_ruleset geoip-google', '_', sys.argv[1]],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, start_new_session=True,
)
try:
    deadline = time.monotonic() + 5
    while not (root / 'ready').exists():
        if process.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('download did not start')
        time.sleep(0.01)
    os.killpg(process.pid, signal.SIGINT)
    output, _ = process.communicate(timeout=5)
    assert process.returncode == 130, (process.returncode, output)
    assert b'Traceback' not in output, output
    assert '已取消'.encode() in output, output
finally:
    if process.poll() is None:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
PY
cmp "$TMP/previous.json" "$CFG/ruleset-src/geoip-google.json"
cmp "$TMP/previous.srs" "$CFG/ruleset/geoip-google.srs"
assert_clean
printf '%s\n' 'ok - Ctrl+C exits with status 130, prints no traceback, cleans temporary files and preserves caches'

GEO_TEST_MODE=ok
_ensure_singbox_rulesets_from_routing_rules '[{"rule_set":["geoip-google","geosite-google"]}]'
before=$(wc -l <"$TMP/downloads")
_ensure_singbox_rulesets_from_routing_rules '[{"rule_set":["geoip-google","geosite-google"]}]'
[[ $(wc -l <"$TMP/downloads") == "$before" ]]
if [[ -n "${VLESS_TEST_SINGBOX_BIN:-}" ]]; then
    SINGBOX_CONFIG_BINARY="$VLESS_TEST_SINGBOX_BIN"
    _build_singbox_geoip_ruleset geoip-google
    _build_singbox_geosite_ruleset geosite-google
    "$SINGBOX_CONFIG_BINARY" rule-set decompile "$CFG/ruleset/geoip-google.srs" -o "$TMP/decompiled.json" >/dev/null
    jq -e '.rules[0].ip_cidr==["192.0.2.0/24","2001:db8::/32"]' "$TMP/decompiled.json" >/dev/null
fi
printf '%s\n' 'ok - cached rules avoid downloads; optional real Sing-box compilation and decompilation'
