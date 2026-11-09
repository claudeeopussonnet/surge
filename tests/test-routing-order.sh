#!/usr/bin/env bash
# Per-core ordering and rollback; temporary files and simulated services only.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
trap 'printf "FAIL at line %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR
export VLESS_TEST_CFG="$TMP/etc"
export VLESS_TEST_SYSTEMD_DIR="$TMP/systemd"
export VLESS_TEST_OPENRC_DIR="$TMP/openrc"
mkdir -p "$VLESS_TEST_CFG" "$VLESS_TEST_SYSTEMD_DIR" "$VLESS_TEST_OPENRC_DIR"
source "$ROOT/vless-server.sh"
_header() { :; }; _line() { :; }; _pause() { :; }; _log() { :; }
_listen_addr() { printf '%s\n' 127.0.0.1; }
systemctl() { printf 'unexpected systemctl\n' >&2; return 1; }
rc-service() { printf 'unexpected rc-service\n' >&2; return 1; }
curl() { printf 'unexpected network download\n' >&2; return 1; }
get_xray_protocols() { printf '%s\n' vless; }
get_singbox_protocols() { printf '%s\n' snell; }
get_mihomo_protocols() { :; }
sing-box() {
    if [[ -n "${VLESS_TEST_SINGBOX_BIN:-}" ]]; then "$VLESS_TEST_SINGBOX_BIN" "$@"; return $?; fi
    case "$1" in
        version) printf '%s\n' 'sing-box version 1.14.4' ;;
        check) jq empty "$3" ;;
        rule-set) cp "$3" "$5" ;;
        *) return 1 ;;
    esac
}
fixture() {
    jq -n '{xray:{},singbox:{snell:{port:43002,psk:"fixture0123456789",version:4}},mihomo:{},routing_rules:[
        {id:"duplicate",type:"custom",domains:"first.example",outbound:"direct",ip_version:"as_is"},
        {id:"duplicate",type:"custom",domains:"second.example",outbound:"block",ip_version:"as_is"},
        {id:"google",type:"google",domains:"geosite:google",outbound:"block",ip_version:"as_is"},
        {id:"singbox-ai",type:"singbox-ai",outbound:"direct",ip_version:"as_is"},
        {id:"ai-intl",type:"ai-intl",domains:"geosite:category-ai-!cn",outbound:"block",ip_version:"as_is"},
        {id:"mihomo-ai",type:"mihomo-ai",outbound:"block",ip_version:"as_is"},
        {id:"all",type:"all",outbound:"block",ip_version:"as_is"},
        {id:"all4",type:"all",outbound:"direct",ip_version:"ipv4_only"},
        {id:"all6",type:"all",outbound:"direct",ip_version:"ipv6_only"}]}' >"$DB_FILE"
}
assert_ids() { db_get_routing_rules "$1" | jq -e --argjson expected "$2" 'map(.id)==$expected' >/dev/null; }
fixture
assert_ids singbox '["duplicate","duplicate","google","singbox-ai","all6","all4","all"]'
assert_ids xray '["duplicate","duplicate","google","ai-intl","all6","all4","all"]'
gen_xray_routing_rules | jq -e '.[-3].ip==["::/0"] and .[-2].ip==["0.0.0.0/0"] and .[-1].outboundTag=="block"' >/dev/null
db_move_routing_rule singbox 4 1
gen_singbox_routing_rules | jq -e '.[0].rule_set==["skk-ai-non-ip"] and .[1].rule_set==["skk-ai-ip"]' >/dev/null
db_move_routing_rule singbox 1 4
db_move_routing_rule singbox 3 1
assert_ids singbox '["google","duplicate","duplicate","singbox-ai","all6","all4","all"]'
assert_ids xray '["duplicate","duplicate","google","ai-intl","all6","all4","all"]'
gen_singbox_routing_rules | jq -e '.[0].rule_set==["geosite-google"] and .[1].rule_set==["geoip-google"]' >/dev/null
db_move_routing_rule xray 4 1
gen_xray_routing_rules | jq -e '.[0].domain==["geosite:category-ai-!cn"]' >/dev/null
assert_ids singbox '["google","duplicate","duplicate","singbox-ai","all6","all4","all"]'
db_move_routing_rule singbox 7 1
gen_singbox_routing_rules | jq -e '.[0]=={outbound:"block"}' >/dev/null
db_move_routing_rule singbox 1 7
db_move_routing_rule singbox 3 1
db_get_routing_rules singbox | jq -e '.[0].domains=="second.example" and .[2].domains=="first.example"' >/dev/null
bash -c 'source "$1"; db_get_routing_rules singbox' _ "$ROOT/vless-server.sh" | jq -e '.[0].domains=="second.example"' >/dev/null
jq -e '[.routing_rules[].id]==["duplicate","duplicate","google","singbox-ai","ai-intl","mihomo-ai","all","all4","all6"]' "$DB_FILE" >/dev/null
printf '%s\n' 'ok - legacy defaults, independent core order, grouped GeoSite/GeoIP, movable ALL, duplicate IDs and persistence'

cp "$DB_FILE" "$TMP/before-invalid.json"
for args in 'singbox 0 1' 'singbox 1 8' 'xray 08 1' 'mihomo 1 2' 'singbox abc 1'; do
    read -r core from to <<<"$args"
    if db_move_routing_rule "$core" "$from" "$to"; then exit 1; fi
    cmp "$TMP/before-invalid.json" "$DB_FILE"
done
displayed=$(db_get_routing_rules singbox)
db_move_routing_rule singbox 2 1
cp "$DB_FILE" "$TMP/before-stale.json"
if db_move_routing_rule singbox 2 1 "$displayed"; then exit 1; fi
cmp "$TMP/before-stale.json" "$DB_FILE"
db_del_routing_rule singbox-ai
db_add_routing_rule custom direct new.example as_is
db_get_routing_rules singbox | jq -e '.[0].id=="google" and .[-1].domains=="new.example" and all(.[];.id!="singbox-ai")' >/dev/null
printf '%s\n' 'ok - invalid/stale selections leave DB intact; adding/deleting rules preserves manual order'

# Seed every source locally; real Sing-box is optional and never starts a server.
mkdir -p "$CFG/ruleset" "$CFG/ruleset-src"
for tag in geoip-google geosite-google skk-ai-non-ip skk-ai-ip; do
    printf '%s\n' '{"version":3,"rules":[{"domain_suffix":["fixture.example"]}]}' >"$CFG/ruleset-src/$tag.json"
    sing-box rule-set compile "$CFG/ruleset-src/$tag.json" -o "$CFG/ruleset/$tag.srs" >/dev/null
done
FAIL_GENERATE=false FAIL_RESTART=false FAIL_HEALTH=false
declare -A RUNNING=([vless-reality]=true [vless-singbox]=true)
svc() {
    printf '%s %s\n' "$1" "$2" >>"$TMP/events"
    case "$1" in
        status) [[ "${RUNNING[$2]}" == true ]] ;;
        restart)
            RUNNING[$2]=false
            if [[ "$FAIL_RESTART" == true ]]; then FAIL_RESTART=false; return 1; fi
            RUNNING[$2]=true ;;
        *) printf 'unexpected service action\n' >&2; return 1 ;;
    esac
}
_wait_for_singbox_ready() {
    if [[ "$FAIL_HEALTH" == true ]]; then FAIL_HEALTH=false; return 1; fi
    [[ "${RUNNING[vless-singbox]}" == true ]]
}
definition=$(declare -f generate_singbox_config)
eval "${definition/generate_singbox_config/generate_singbox_config_real}"
generate_singbox_config() {
    [[ "$FAIL_GENERATE" != true ]] || return 1
    generate_singbox_config_real "$@"
}
generate_xray_config() {
    [[ "$FAIL_GENERATE" != true ]] || return 1
    gen_xray_routing_rules | jq '{routing:{rules:.}}' >"$CFG/config.json"
}
prepare_transaction() {
    fixture
    FAIL_GENERATE=false FAIL_RESTART=false FAIL_HEALTH=false
    RUNNING[vless-reality]=true RUNNING[vless-singbox]=true
    generate_xray_config
    generate_singbox_config >"$TMP/generation-output" 2>&1
    cp "$DB_FILE" "$TMP/original-db.json"
    cp "$CFG/config.json" "$TMP/original-xray.json"
    cp "$CFG/singbox.json" "$TMP/original-singbox.json"
    : >"$TMP/events"
}
for core in xray singbox; do
    prepare_transaction
    _apply_routing_rule_order "$core" 7 1
    if [[ "$core" == singbox ]]; then
        jq -e '.route.rules[0]=={action:"sniff"} and .route.rules[1]=={outbound:"block"}' "$CFG/singbox.json" >/dev/null
        cmp "$CFG/config.json" "$TMP/original-xray.json"
        [[ $(rg -c '^restart vless-singbox$' "$TMP/events") == 1 ]]
        ! rg -q '^restart vless-reality$' "$TMP/events"
    else
        jq -e '.routing.rules[0].outboundTag=="block" and .routing.rules[0].network=="tcp,udp"' "$CFG/config.json" >/dev/null
        cmp "$CFG/singbox.json" "$TMP/original-singbox.json"
        [[ $(rg -c '^restart vless-reality$' "$TMP/events") == 1 ]]
        ! rg -q '^restart vless-singbox$' "$TMP/events"
    fi
    for failure in generate restart health; do
        [[ "$core" != xray || "$failure" != health ]] || continue
        prepare_transaction
        case "$failure" in generate) FAIL_GENERATE=true ;; restart) FAIL_RESTART=true ;; health) FAIL_HEALTH=true ;; esac
        if _apply_routing_rule_order "$core" 7 1 >"$TMP/failure-output" 2>&1; then exit 1; fi
        cmp "$DB_FILE" "$TMP/original-db.json"
        cmp "$CFG/config.json" "$TMP/original-xray.json"
        cmp "$CFG/singbox.json" "$TMP/original-singbox.json"
        [[ "${RUNNING[vless-reality]}" == true && "${RUNNING[vless-singbox]}" == true ]]
        if [[ "$failure" == generate ]]; then ! rg -q '^restart ' "$TMP/events"; fi
    done
    prepare_transaction
    RUNNING[vless-reality]=false RUNNING[vless-singbox]=false
    _apply_routing_rule_order "$core" 7 1 >"$TMP/stopped-output" 2>&1
    ! rg -q '^restart ' "$TMP/events"
    [[ "${RUNNING[vless-reality]}" == false && "${RUNNING[vless-singbox]}" == false ]]
done
printf '%s\n' 'ok - generated route order, sniff preservation, selected-core-only reload, failed generation/restart/health rollback and stopped services'

(
    fixture
    _apply_routing_rule_order() { printf '%s %s %s\n' "$1" "$2" "$3" >>"$TMP/menu-actions"; }
    _reorder_routing_rules <<< $'2\n3\n\n0' >"$TMP/menu" 2>&1
    [[ $(cat "$TMP/menu-actions") == 'singbox 3 1' ]]
    rg -q 'Sing-box 分流规则顺序' "$TMP/menu"
    rg -q 'Sukka-AI-Sing-Box专属' "$TMP/menu"
    ! rg -q 'GeoSite-AI-Xray专属' "$TMP/menu"
    _reorder_routing_rules <<< $'1\n2\n3\n0' >"$TMP/menu" 2>&1
    [[ $(tail -n 1 "$TMP/menu-actions") == 'xray 2 3' ]]
    _reorder_routing_rules <<< $'2\n999\n0' >"$TMP/menu" 2>&1
    rg -q '无效规则序号' "$TMP/menu"
    _reorder_routing_rules <<<2 >"$TMP/menu" 2>&1 # EOF returns without moving anything.
    [[ $(wc -l <"$TMP/menu-actions") == 2 ]]
    get_singbox_protocols() { :; }
    if _reorder_routing_rules <<<2 >"$TMP/menu" 2>&1; then exit 1; fi
    rg -q '请先安装 Sing-box 协议' "$TMP/menu"
    _reorder_routing_rules() { printf 'entry\n' >"$TMP/menu-entry"; }
    show_routing_status() { :; }
    configure_routing_rules <<< $'5\n0' >"$TMP/menu" 2>&1
    [[ $(cat "$TMP/menu-entry") == entry ]]
)
printf '%s\n' 'ok - menu entry, core-specific lists, default pinning, custom positions, invalid input, EOF and unavailable cores'
