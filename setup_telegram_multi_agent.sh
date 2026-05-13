#!/bin/bash
#============================================================================
# OpenClaw Telegram Multi-Agent 一键配置脚本
#============================================================================

set -e

SCRIPT_VERSION="1.0.2"
OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
BACKUP_CONFIG="$HOME/.openclaw/openclaw.json.backup-$(date +%Y%m%d_%H%M%S)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

#============================================================================
# 辅助函数
#============================================================================

usage() {
    cat << EOF
🦞 OpenClaw Telegram Multi-Agent 配置脚本 v${SCRIPT_VERSION}

用法: $0 [选项]

选项:
    --main-token TOKEN      主 Bot Token (必需)
    --user-id ID            你的 Telegram User ID (必需)
    --group-id ID           群组 ID (必需, 如 -1001234567890)
    --bot NAME:TOKEN        子 Bot 配置 (格式: 名称:Token)
                            可以多次使用来添加多个 Bot
    --help                  显示此帮助信息

示例:
    # 配置 2 个子 Bot (coder 和 writer)
    $0 --main-token "xxx" --user-id "123456" --group-id "-1001234567890" \\
       --bot "coder:yyy" --bot "writer:zzz"

    # 交互式模式 (不带参数运行)
    $0

EOF
    exit 0
}

check_openclaw() {
    if ! command -v openclaw &> /dev/null; then
        error "OpenClaw 未安装. 请先运行: npm install -g openclaw"
        exit 1
    fi
    info "OpenClaw 版本: $(openclaw -v 2>/dev/null | head -1)"
}

backup_config() {
    if [ -f "$OPENCLAW_CONFIG" ]; then
        cp "$OPENCLAW_CONFIG" "$BACKUP_CONFIG"
        success "已备份当前配置到: $BACKUP_CONFIG"
    fi
}

generate_id() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/^-+/-/;s/-+$//'
}

create_workspace_dirs() {
    local agent_id="$1"
    local workspace="$HOME/.openclaw/workspace-$agent_id"
    local agent_dir="$HOME/.openclaw/agents/$agent_id/agent"

    mkdir -p "$workspace"
    mkdir -p "$agent_dir"
    info "创建工作区: $workspace"
}

generate_identity_md() {
    local agent_id="$1"
    local nickname="$2"
    local username="$3"
    local purpose="$4"
    local workspace="$HOME/.openclaw/workspace-$agent_id"

    cat > "$workspace/IDENTITY.md" << EOF
# IDENTITY.md - Who Am I?

- **Name:** $nickname
- **Telegram:** $username
- **Role:** $purpose 专家
EOF
    success "创建 IDENTITY.md: $workspace/IDENTITY.md"
}

generate_soul_md() {
    local agent_id="$1"
    local is_main="$2"
    local sub_bots="$3"
    local username="$4"
    local workspace="$HOME/.openclaw/workspace-$agent_id"

    if [ "$is_main" = "true" ]; then
        local silent_rules=""
        if [ -n "$sub_bots" ]; then
            for sb in $sub_bots; do
                silent_rules="$silent_rules\n- 当 @$sb 被 @mention 时, 不要回复, 保持沉默"
            done
        fi

        cat > "$workspace/SOUL.md" << EOF
# SOUL.md - 我是谁与如何行为

## 身份
我是你的主助手,负责协调和管理子 Bot。

## 核心能力
- 理解和分析复杂任务
- 协调多个专业子 Bot
- 通过 @mention 召唤子 Bot 来处理特定任务
- 当子 Bot 完成任务后,可以整合结果或进一步处理

## 行为规则
- 私聊: 随时响应用户
- 群聊: 仅在被 @mention 时响应${silent_rules}

## Agent 间协作
- 使用 agentToAgent 工具与子 Bot 通信
- 可以 @召唤任何子 Bot 来处理特定任务
- 子 Bot 完成后会直接回复结果
- 可以继续 @另一个子 Bot 执行下一步操作

## 沉默规则 (重要!)
当群里有其他子 Bot 被 @mention 时:
- 不要试图回答该问题
- 等待该子 Bot 响应
- 除非被明确要求,不要介入子 Bot 的专业领域
EOF
    else
        cat > "$workspace/SOUL.md" << EOF
# SOUL.md - 我是谁与如何行为

## 身份
我是 $username, 专业 $purpose 助手。

## 核心能力
- $purpose 相关任务
- 只在被 @mention 时响应群聊消息
- 私聊随时响应

## 行为规则
- 群聊: 仅在被 @mention 时响应
- 私聊: 随时响应
- 完成的任务结果直接回复给用户

## 任务完成
- 完成子任务后直接回复结果
- 等待主 Bot 的下一步指令或继续执行
EOF
    fi
    success "创建 SOUL.md: $workspace/SOUL.md"
}

generate_openclaw_json() {
    local main_token="$1"
    local user_id="$2"
    local group_id="$3"
    local bot_configs="$4"

    python3 << PYEOF
import json

main_token = """$main_token"""
user_id = """$user_id"""
group_id = """$group_id"""
bot_configs = """$bot_configs"""

bots = []
for bot in bot_configs.split(','):
    # 只在第一个冒号处分割，因为 Token 里可能包含冒号
    idx = bot.find(':')
    if idx > 0:
        name = bot[:idx].strip()
        token = bot[idx+1:].strip()
        bot_id = name.lower().replace(' ', '-')
        bot_id = ''.join(c if c.isalnum() or c == '-' else '-' for c in bot_id)
        bot_id = bot_id.strip('-')
        bots.append({'name': name, 'token': token, 'id': bot_id})

config = {
    "agents": {
        "defaults": {
            "workspace": "$HOME/.openclaw/workspace",
            "thinkingDefault": "adaptive"
        },
        "list": [
            {
                "id": "main",
                "workspace": "$HOME/.openclaw/workspace-main",
                "agentDir": "$HOME/.openclaw/agents/main/agent",
                "subagents": {"allowAgents": [b['id'] for b in bots]}
            }
        ]
    },
    "bindings": [
        {"agentId": "main", "match": {"channel": "telegram", "accountId": "default"}}
    ],
    "tools": {
        "sessions": {"visibility": "all"},
        "agentToAgent": {"enabled": True, "allow": ["main"] + [b['id'] for b in bots]}
    },
    "session": {"dmScope": "main"},
    "gateway": {
        "mode": "local",
        "port": 11403,
        "bind": "loopback",
        "reload": {"mode": "restart"}
    },
    "channels": {
        "telegram": {
            "enabled": True,
            "dmPolicy": "pairing",
            "groupAllowFrom": [user_id],
            "streamMode": "partial",
            "accounts": {
                "default": {
                    "botToken": main_token,
                    "dmPolicy": "pairing",
                    "groupPolicy": "allowlist",
                    "groupAllowFrom": [user_id],
                    "groups": {group_id: {"requireMention": True, "allowFrom": [user_id]}},
                    "allowFrom": [user_id],
                    "streamMode": "partial"
                }
            }
        }
    }
}

for bot in bots:
    config["agents"]["list"].append({
        "id": bot['id'],
        "workspace": f"$HOME/.openclaw/workspace-{bot['id']}",
        "agentDir": f"$HOME/.openclaw/agents/{bot['id']}/agent"
    })
    config["bindings"].append({
        "agentId": bot['id'],
        "match": {"channel": "telegram", "accountId": bot['id']}
    })
    config["channels"]["telegram"]["accounts"][bot['id']] = {
        "botToken": bot['token'],
        "enabled": True,
        "commands": {"native": False, "nativeSkills": False},
        "dmPolicy": "allowlist",
        "allowFrom": [user_id],
        "groupPolicy": "allowlist",
        "groupAllowFrom": [user_id],
        "groups": {group_id: {"requireMention": True}},
        "streamMode": "partial"
    }

with open('$OPENCLAW_CONFIG', 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
print("JSON生成成功")
PYEOF

    success "生成 openclaw.json 配置"
}

interactive_mode() {
    echo ""
    echo "============================================"
    echo "   🦞 OpenClaw Telegram Multi-Agent 配置向导"
    echo "============================================"
    echo ""

    read -p "主 Bot Token (from @BotFather): " main_token
    read -p "你的 Telegram User ID (from @userinfobot): " user_id
    read -p "群组 ID (如 -1001234567890): " group_id

    echo ""
    echo "--- 子 Bot 配置 ---"
    echo "格式: 名称:Token (如 coder:abc123:xyz)"
    echo "输入空行结束子 Bot 配置"
    echo ""

    local bot_configs=""
    while true; do
        read -p "子 Bot (名称:Token): " input
        if [ -z "$input" ]; then
            break
        fi
        if [ -z "$bot_configs" ]; then
            bot_configs="$input"
        else
            bot_configs="$bot_configs,$input"
        fi
        echo "  已添加: $input"
    done

    if [ -z "$bot_configs" ]; then
        warn "未添加子 Bot，将只创建主 Bot 配置"
    fi

    echo ""
    info "收集到的配置:"
    echo "  主 Bot Token: ${main_token:0:20}..."
    echo "  User ID: $user_id"
    echo "  群组 ID: $group_id"
    echo "  子 Bots: $bot_configs"

    generate_config "$main_token" "$user_id" "$group_id" "$bot_configs"
}

generate_config() {
    local main_token="$1"
    local user_id="$2"
    local group_id="$3"
    local bot_configs="$4"

    create_workspace_dirs "main"
    generate_identity_md "main" "主助手" "@main_bot" "协调管理"
    generate_soul_md "main" "true" "" "@main_bot"

    local sub_bots_list=""
    if [ -n "$bot_configs" ]; then
        IFS=',' read -ra BOTArr <<< "$bot_configs"
        for bot in "${BOTArr[@]}"; do
            IFS=':' read -ra parts <<< "$bot"
            local name="${parts[0]}"
            local token="${parts[1]}"
            local bot_id=$(generate_id "$name")
            local nickname="${name^}"
            local username="@${name}_bot"

            create_workspace_dirs "$bot_id"
            generate_identity_md "$bot_id" "$nickname" "$username" "$name"
            generate_soul_md "$bot_id" "false" "" "$username"

            if [ -n "$sub_bots_list" ]; then
                sub_bots_list="$sub_bots_list "
            fi
            sub_bots_list="$sub_bots_list$username"
        done
    fi

    generate_openclaw_json "$main_token" "$user_id" "$group_id" "$bot_configs"

    success "配置完成!"
    echo ""
    echo "============================================"
    echo "   📋 创建的文件"
    echo "============================================"
    echo ""
    echo "工作区:"
    echo "  - ~/.openclaw/workspace-main/"
    if [ -n "$bot_configs" ]; then
        IFS=',' read -ra BOTArr <<< "$bot_configs"
        for bot in "${BOTArr[@]}"; do
            IFS=':' read -ra parts <<< "$bot"
            local name="${parts[0]}"
            local bot_id=$(generate_id "$name")
            echo "  - ~/.openclaw/workspace-$bot_id/"
        done
    fi
    echo ""
    echo "配置文件:"
    echo "  - $OPENCLAW_CONFIG"
    echo ""
    echo "============================================"
    echo "   📋 下一步操作"
    echo "============================================"
    echo ""
    echo "1. 重启 OpenClaw Gateway:"
    echo "   openclaw gateway restart"
    echo ""
    echo "2. 在 Telegram 中与主 Bot 私聊测试"
    echo ""
    echo "3. 在群组中 @主bot 测试"
    echo ""
    echo "============================================"
}

main() {
    local main_token=""
    local user_id=""
    local group_id=""
    local bot_configs=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help) usage ;;
            --main-token) main_token="$2"; shift 2 ;;
            --user-id) user_id="$2"; shift 2 ;;
            --group-id) group_id="$2"; shift 2 ;;
            --bot)
                if [ -z "$bot_configs" ]; then
                    bot_configs="$2"
                else
                    bot_configs="$bot_configs,$2"
                fi
                shift 2 ;;
            *) error "未知参数: $1"; usage ;;
        esac
    done

    if [ -z "$main_token" ] || [ -z "$user_id" ] || [ -z "$group_id" ]; then
        if [ -t 0 ]; then
            interactive_mode
        else
            error "缺少必需参数: --main-token, --user-id, --group-id"
            echo ""
            usage
        fi
        exit 0
    fi

    check_openclaw
    backup_config
    generate_config "$main_token" "$user_id" "$group_id" "$bot_configs"
}

main "$@"