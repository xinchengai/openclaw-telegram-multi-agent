# OpenClaw Telegram Multi-Agent Setup

Telegram 多 Bot 协作一键配置脚本。

## 功能

- 一键配置 OpenClaw 多 Agent Telegram 机器人
- 支持主 Bot + 多个子 Bot 协作
- Agent 间通过 @mention 分配任务
- 自动生成 SOUL.md 和 IDENTITY.md

## 使用方式

```bash
# 下载脚本
curl -O https://raw.githubusercontent.com/你的用户名/openclaw-telegram-multi-agent/main/setup_telegram_multi_agent.sh

# 添加执行权限
chmod +x setup_telegram_multi_agent.sh

# 运行 (交互式)
./setup_telegram_multi_agent.sh

# 或命令行
./setup_telegram_multi_agent.sh \
  --main-token "主bot:token" \
  --user-id "123456" \
  --group-id "-1001234567890" \
  --main-username "@主bot名" \
  --bot "coder:子bot1token:@coder_bot" \
  --bot "writer:子bot2token:@writer_bot"
```

## 配置说明

### 输入参数

| 参数 | 说明 | 必需 |
|------|------|------|
| `--main-token` | 主 Bot Token (from @BotFather) | 是 |
| `--user-id` | 你的 Telegram User ID (from @userinfobot) | 是 |
| `--group-id` | 群组 ID (如 -1001234567890) | 是 |
| `--bot` | 子 Bot 配置 (格式: 名称:Token) | 是 |

### 架构说明

```
群聊:
  用户 @主bot → 主bot 分析 → @子bot执行 → 返回结果 → @其他子bot继续

私聊:
  所有 Bot 都可以随时响应
```

### 配置结构

| 配置项 | 主 Bot | 子 Bot |
|--------|--------|--------|
| 群聊触发 | requireMention: true | requireMention: true |
| 私聊 | dmPolicy: pairing | dmPolicy: allowlist |

## 前提条件

- OpenClaw 已安装 (`npm install -g openclaw`)
- 已创建 Telegram Bot (通过 @BotFather)
- 已获取你的 User ID (通过 @userinfobot)

## 注意事项

1. 运行前请备份现有配置: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak`
2. 首次运行后需要重启 Gateway: `openclaw gateway restart`
3. 子 Bot 间协作依赖 `tools.agentToAgent` 配置

## 目录结构

```
~/.openclaw/
├── workspace-main/          # 主 Bot 工作区
│   ├── IDENTITY.md
│   └── SOUL.md
├── workspace-{bot1}/        # 子 Bot 工作区
│   ├── IDENTITY.md
│   └── SOUL.md
├── agents/
│   ├── main/agent/
│   └── {bot1}/agent/
└── openclaw.json            # 配置文件
```

## License

MIT