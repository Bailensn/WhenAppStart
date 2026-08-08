# Go + telebot.v4 服务端完整教程

> 从零搭建企业级 Telegram Bot 服务端，涵盖 Bot 开发、WebSocket 通信、H5 管理界面、Docker 部署全流程  
> 适用版本：Go 1.22+ / telebot.v4 / gorilla/websocket v1.5+

---

## 目录

- [第一部分：环境搭建与第一个 Bot](#第一部分环境搭建与第一个-bot)
- [第二部分：Bot 对象与全部方法详解](#第二部分bot-对象与全部方法详解)
- [第三部分：Handler 与事件处理](#第三部分handler-与事件处理)
- [第四部分：键盘与交互](#第四部分键盘与交互)
- [第五部分：FSM 状态机](#第五部分fsm-状态机)
- [第六部分：Middleware 中间件](#第六部分middleware-中间件)
- [第七部分：文件处理](#第七部分文件处理)
- [第八部分：Webhook 部署](#第八部分webhook-部署)
- [第九部分：WebSocket 通信 + H5 管理界面](#第九部分websocket-通信--h5-管理界面)
- [第十部分：项目工程化 + 附录](#第十部分项目工程化--附录)

---

## 第一部分：环境搭建与第一个 Bot

### 一、为什么选 Go + telebot

| 维度 | Python (aiogram) | Go (telebot) |
|---|---|---|
| 并发模型 | asyncio 单线程事件循环 | Goroutine 真·多核并行 |
| 部署 | 需 Python 运行时 + 依赖 | 编译为单二进制，零依赖 |
| 内存占用 | ~80-150MB | ~10-30MB |
| 冷启动 | 1-3s | <50ms |
| 类型安全 | 运行时才发现错误 | 编译期拦截 |
| 适合场景 | 快速原型、脚本化 | 高并发、长驻服务、微服务 |

**核心结论**：如果你要做一个 **7×24 小时稳定运行、同时管理数千用户、还要和 Android 端实时通信** 的 Bot 服务，Go 是更优解。

### 二、环境搭建

#### 2.1 安装 Go

```bash
# macOS
brew install go

# Ubuntu/Debian
sudo apt update && sudo apt install -y golang-go

# CentOS/RHEL
sudo yum install -y golang

# 验证
go version  # 输出: go version go1.22.x ...
```

#### 2.2 配置 Go 环境

```bash
# 设置 GOPATH（Go 1.16+ 默认 $HOME/go，可不设）
echo 'export GOPATH=$HOME/go' >> ~/.zshrc
echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
source ~/.zshrc

# 开启 Go Modules（Go 1.16+ 默认开启）
go env -w GO111MODULE=on

# 配置代理（国内必设）
go env -w GOPROXY=https://goproxy.cn,direct
```

#### 2.3 创建项目

```bash
mkdir telebot-server && cd telebot-server
go mod init telebot-server
```

#### 2.4 安装 telebot.v4

```bash
go get gopkg.in/telebot.v4@latest
```

安装完成后 `go.mod` 应包含：

```go
module telebot-server

go 1.22

require gopkg.in/telebot.v4 v4.0.0
```

### 三、获取 Bot Token

1. 打开 Telegram，搜索 `@BotFather`
2. 发送 `/newbot`
3. 按提示输入 Bot 名称（如 `MyGoBot`）
4. 再输入用户名（必须以 `bot` 结尾，如 `my_go_bot`）
5. BotFather 会返回 Token，格式如：`1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`

> ⚠️ **安全提醒**：Token 等同于你的 Bot 密码，绝不要硬编码在代码里或提交到公开仓库。

### 四、第一个 Bot：Hello World

创建 `main.go`：

```go
package main

import (
	"log"
	"os"

	"gopkg.in/telebot.v4"
)

func main() {
	// 从环境变量读取 Token
	token := os.Getenv("TELEGRAM_BOT_TOKEN")
	if token == "" {
		log.Fatal("❌ 请设置环境变量 TELEGRAM_BOT_TOKEN")
	}

	// 创建 Bot 实例
	bot, err := telebot.NewBot(telebot.Settings{
		Token:  token,
		Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	})
	if err != nil {
		log.Fatalf("❌ 创建 Bot 失败: %v", err)
	}

	// 注册命令处理器
	bot.Handle("/start", func(c telebot.Context) error {
		return c.Send("👋 你好！我是用 Go 写的 Bot！")
	})

	bot.Handle("/help", func(c telebot.Context) error {
		return c.Send("输入 /start 开始使用")
	})

	// 处理所有文本消息（兜底）
	bot.Handle(telebot.OnText, func(c telebot.Context) error {
		text := c.Text()
		return c.Send("你说了: " + text)
	})

	log.Println("🤖 Bot 已启动，等待消息...")
	bot.Start()
}
```

运行：

```bash
export TELEGRAM_BOT_TOKEN="你的Token"
go run main.go
```

打开 Telegram 搜索你的 Bot 用户名，发送 `/start`，就能收到回复了。

### 五、telebot.Settings 完整参数

```go
type Settings struct {
	// Token - Telegram Bot API Token（必填）
	Token string

	// Poller - 轮询器（二选一：LongPoller 或 Webhook）
	// LongPoller: 适合开发/小规模
	// Webhook:   适合生产环境
	Poller Poller

	// URL - 自定义 Telegram API 地址（默认 https://api.telegram.org）
	// 用于自建代理或本地测试
	URL string

	// HTTPClient - 自定义 HTTP 客户端
	// 可用于设置代理、超时等
	HTTPClient *http.Client

	// ParseMode - 全局默认解析模式
	// telebot.ParseModeMarkdown / telebot.ParseModeHTML
	ParseMode ParseMode

	// Verbose - 是否打印调试日志
	Verbose bool

	// OnError - 全局错误回调
	OnError func(error, Context)
}
```

#### 自定义 HTTP 客户端（代理场景）

```go
// 使用 SOCKS5 代理（国内服务器必备）
import (
	"golang.org/x/net/proxy"
	"net/http"
)

func createProxyClient() *http.Client {
	dialer, err := proxy.SOCKS5("tcp", "127.0.0.1:7890", nil, proxy.Direct)
	if err != nil {
		log.Fatal(err)
	}
	transport := &http.Transport{
		Dial: dialer.Dial,
	}
	return &http.Client{
		Transport: transport,
		Timeout:   60 * time.Second,
	}
}

bot, err := telebot.NewBot(telebot.Settings{
	Token:     token,
	Poller:    &telebot.LongPoller{Timeout: 10 * time.Second},
	HTTPClient: createProxyClient(),
	Verbose:   true,
})
```

### 六、项目结构（推荐）

```
telebot-server/
├── main.go                 # 入口
├── go.mod
├── go.sum
├── config/
│   └── config.go           # 配置加载
├── internal/
│   ├── bot/
│   │   ├── bot.go          # Bot 初始化
│   │   └── handlers.go     # 消息处理器
│   ├── ws/                 # WebSocket（后续章节）
│   ├── auth/               # JWT 鉴权（后续章节）
│   └── store/              # 数据持久化
└── web/
    └── static/             # H5 管理界面（后续章节）
```

### 七、常见问题

| 问题 | 原因 | 解决 |
|---|---|---|
| `401 Unauthorized` | Token 错误 | 检查环境变量，重新从 BotFather 获取 |
| `409 Conflict` | 多个实例同时运行 | 确保只有一个进程在跑 |
| 收不到消息 | 网络不通 | 配置代理后重启 |
| `rate limit` | 发送太频繁 | 加入延迟或使用 webhook |
| 启动后秒退 | `bot.Start()` 未阻塞 | 检查是否用了 `go bot.Start()` |

---

> **第一部分完**。下一部分将深入讲解 Bot 对象的所有方法和参数。

---
# Go + telebot.v4 服务端完整教程（第二部分：Bot 对象与全部方法详解）

---

## 第二部分：Bot 对象与全部方法详解

### 一、Bot 对象结构

```go
// 源码简化版
type Bot struct {
	Token      string
	URL        string
	Settings   Settings
	Me         *User          // Bot 自身信息
	Commands   []Command      // 已注册的命令列表
	Poller     Poller         // 轮询器
	Router     *Router        // 路由树
	Store      Storage        // FSM 存储后端
	HttpClient *http.Client   // HTTP 客户端
	// ... 内部字段
}
```

### 二、Bot 创建与配置

```go
// 最简创建
bot, err := telebot.NewBot(telebot.Settings{
	Token:  "123456:ABC-DEF",
	Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
})

// 完整配置
bot, err := telebot.NewBot(telebot.Settings{
	Token:  os.Getenv("TELEGRAM_BOT_TOKEN"),
	URL:    "https://api.telegram.org", // 可指向自建网关
	Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	ParseMode: telebot.ParseModeMarkdown,
	Verbose:   true,
	OnError: func(err error, ctx telebot.Context) {
		log.Printf("⚠️ Bot 错误: %v", err)
	},
	HTTPClient: &http.Client{
		Timeout: 60 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        100,
			MaxIdleConnsPerHost:  10,
			IdleConnTimeout:      90 * time.Second,
		},
	},
})
```

### 三、Bot 全部方法详解

#### 3.1 生命周期

| 方法 | 签名 | 说明 |
|---|---|---|
| `Start` | `func (b *Bot) Start()` | 开始轮询，阻塞直到 `Stop()` 被调用 |
| `Stop` | `func (b *Bot) Stop()` | 优雅停止，等待当前消息处理完毕 |
| `Close` | `func (b *Bot) Close()` | 释放资源（HTTP 连接池等） |
| `Me` | `func (b *Bot) Me() *User` | 获取 Bot 自身信息 |

```go
// 优雅退出示例
func main() {
	bot, _ := telebot.NewBot(settings)
	go bot.Start()

	// 监听退出信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 正在停止 Bot...")
	bot.Stop()
	bot.Close()
	log.Println("✅ 已安全退出")
}
```

#### 3.2 发送消息

| 方法 | 签名 | 说明 |
|---|---|---|
| `Send` | `func (b *Bot) Send(to Recipient, what any, opts ...any) (*Message, error)` | 发送任意类型消息 |
| `Reply` | `func (b *Bot) Reply(to Editable, what any, opts ...any) (*Message, error)` | 回复某条消息 |
| `Forward` | `func (b *Bot) Forward(to Recipient, msg Editable, opts ...any) (*Message, error)` | 转发消息 |
| `Copy` | `func (b *Bot) Copy(to Recipient, msg Editable, opts ...any) (*Message, error)` | 复制消息（不带转发标记） |
| `SendAlbum` | `func (b *Bot) SendAlbum(to Recipient, album Album, opts ...any) ([]*Message, error)` | 发送媒体组 |

```go
// Send - 万能发送方法
// what 参数支持的类型：
//   string          → 文本消息
//   *Photo          → 图片
//   *Video          → 视频
//   *Document       → 文件
//   *Audio          → 音频
//   *Voice          → 语音
//   *Sticker        → 贴纸
//   *Animation      → GIF
//   *Location       → 位置
//   *Contact        → 联系人
//   *Poll           → 投票
//   *Invoice        → 发票
//   *Dice           → 骰子

// 发送文本
msg, err := bot.Send(chat, "Hello!", &telebot.SendOptions{
	ParseMode:    telebot.ParseModeMarkdown,
	DisableWebPreview: true,
})

// 发送图片（从 URL）
photo := &telebot.Photo{
	File:    telebot.FromURL("https://picsum.photos/400/300"),
	Caption: "一张随机图片",
}
msg, err := bot.Send(chat, photo, &telebot.SendOptions{
	ParseMode: telebot.ParseModeHTML,
})

// 发送视频（从磁盘）
video := &telebot.Video{
	File:     telebot.FromDisk("./video.mp4"),
	Caption:  "视频标题",
	Duration: 60,
	Width:    1920,
	Height:   1080,
}
bot.Send(chat, video)

// 发送文档
doc := &telebot.Document{
	File:     telebot.FromDisk("./report.pdf"),
	FileName: "2024年度报告.pdf",
	Caption:  "📄 请查收",
}
bot.Send(chat, doc)

// 发送位置
loc := &telebot.Location{
	Lat: 39.9042, // 北京纬度
	Lng: 116.4074, // 北京经度
}
bot.Send(chat, loc)

// 发送骰子
dice := &telebot.Dice{Type: "🎲"}
bot.Send(chat, dice)

// SendAlbum - 媒体组
album := telebot.Album{
	&telebot.Photo{File: telebot.FromURL("https://picsum.photos/400/300?1")},
	&telebot.Photo{File: telebot.FromURL("https://picsum.photos/400/300?2")},
	&telebot.Video{File: telebot.FromDisk("./clip.mp4")},
}
msgs, err := bot.SendAlbum(chat, album, &telebot.SendOptions{
	Caption: "相册标题",
})

// Reply - 回复消息
bot.Reply(originalMsg, "这是回复内容")

// Forward - 转发
bot.Forward(targetChat, originalMsg)

// Copy - 复制（不带转发标记）
bot.Copy(targetChat, originalMsg)
```

#### 3.3 编辑消息

| 方法 | 签名 | 说明 |
|---|---|---|
| `Edit` | `func (b *Bot) Edit(msg Editable, what any, opts ...any) (*Message, error)` | 编辑消息内容 |
| `EditCaption` | `func (b *Bot) EditCaption(msg Editable, caption string, opts ...any) (*Message, error)` | 仅编辑标题 |
| `EditReplyMarkup` | `func (b *Bot) EditReplyMarkup(msg Editable, markup *ReplyMarkup) (*Message, error)` | 仅编辑键盘 |

```go
// 编辑文本
bot.Edit(msg, "更新后的内容", &telebot.SendOptions{
	ParseMode: telebot.ParseModeMarkdown,
})

// 编辑图片标题
bot.EditCaption(photoMsg, "新的标题文字")

// 编辑键盘（移除按钮）
bot.EditReplyMarkup(msg, &telebot.ReplyMarkup{
	InlineKeyboard: [][]telebot.InlineButton{}, // 空键盘 = 移除
})
```

#### 3.4 删除与置顶

| 方法 | 签名 | 说明 |
|---|---|---|
| `Delete` | `func (b *Bot) Delete(msg Editable) error` | 删除消息 |
| `Pin` | `func (b *Bot) Pin(msg Editable, opts ...any) error` | 置顶消息 |
| `Unpin` | `func (b *Bot) Unpin(msg Editable) error` | 取消置顶 |
| `UnpinAll` | `func (b *Bot) UnpinAll(chat ChatID) error` | 取消所有置顶 |

```go
// 删除消息
bot.Delete(msg)

// 置顶并通知所有人
bot.Pin(msg, &telebot.PinOptions{
	DisableNotification: false, // 发送通知
})

// 取消置顶
bot.Unpin(msg)

// 取消群内所有置顶
bot.UnpinAll(chatID)
```

#### 3.5 群组管理

| 方法 | 签名 | 说明 |
|---|---|---|
| `Ban` | `func (b *Bot) Ban(chat ChatID, user User, duration ...time.Duration) error` | 封禁用户 |
| `Unban` | `func (b *Bot) Unban(chat ChatID, user User) error` | 解封用户 |
| `Kick` | `func (b *Bot) Kick(chat ChatID, user User) error` | 踢出用户 |
| `Restrict` | `func (b *Bot) Restrict(chat ChatID, user User, rights Rights, duration ...time.Duration) error` | 限制权限 |
| `Promote` | `func (b *Bot) Promote(chat ChatID, user User, rights Rights) error` | 提升权限 |
| `Leave` | `func (b *Bot) Leave(chat ChatID) error` | 离开群组 |
| `GetChat` | `func (b *Bot) GetChat(id ChatID) (*Chat, error)` | 获取聊天信息 |
| `GetMembersCount` | `func (b *Bot) GetMembersCount(chat ChatID) (int, error)` | 获取成员数 |
| `GetMember` | `func (b *Bot) GetMember(chat ChatID, user User) (*Member, error)` | 获取成员信息 |
| `GetAdmins` | `func (b *Bot) GetAdmins(chat ChatID) ([]Member, error)` | 获取管理员列表 |

```go
// 封禁用户（默认永久）
bot.Ban(chatID, user)

// 封禁 24 小时
bot.Ban(chatID, user, 24*time.Hour)

// 解封
bot.Unban(chatID, user)

// 踢出（踢出后自动解封，可重新加入）
bot.Kick(chatID, user)

// 限制权限（禁言）
bot.Restrict(chatID, user, telebot.Rights{
	CanSendMessages:   false,
	CanSendMedia:       false,
	CanSendPolls:       false,
	CanAddWebPagePreviews: false,
}, 1*time.Hour) // 禁言1小时

// 解除禁言
bot.Restrict(chatID, user, telebot.Rights{
	CanSendMessages:   true,
	CanSendMedia:       true,
	CanSendPolls:       true,
	CanAddWebPagePreviews: true,
})

// 提升为管理员
bot.Promote(chatID, user, telebot.Rights{
	CanChangeInfo:     true,
	CanDeleteMessages:  true,
	CanRestrictMembers: true,
	CanPromoteMembers:  false,
	CanInviteUsers:    true,
	CanPinMessages:    true,
})

// 获取聊天信息
chat, err := bot.GetChat(chatID)
fmt.Printf("标题: %s, 类型: %s, 成员数: %d\n", chat.Title, chat.Type, chat.MembersCount)

// 获取成员数
count, _ := bot.GetMembersCount(chatID)

// 获取成员信息
member, _ := bot.GetMember(chatID, user)
fmt.Printf("状态: %s, 权限: %+v\n", member.Status, member.Rights)

// 获取所有管理员
admins, _ := bot.GetAdmins(chatID)
for _, admin := range admins {
	fmt.Printf("管理员: %s, 权限: %+v\n", admin.User.FirstName, admin.Rights)
}

// 离开群组
bot.Leave(chatID)
```

#### 3.6 投票

| 方法 | 签名 | 说明 |
|---|---|---|
| `SendPoll` | `func (b *Bot) SendPoll(to Recipient, poll *Poll, opts ...any) (*Message, error)` | 发送投票 |
| `StopPoll` | `func (b *Bot) StopPoll(msg Editable) (*Poll, error)` | 停止投票 |

```go
// 发送投票
poll := &telebot.Poll{
	Question:    "你最喜欢哪个编程语言？",
	Options:     []string{"Go", "Python", "Rust", "TypeScript"},
	IsAnonymous: true,
	Type:        "regular",  // regular | quiz
	OpenPeriod:  3600,       // 1小时
}
msg, _ := bot.SendPoll(chatID, poll)

// 发送测验（有正确答案）
quiz := &telebot.Poll{
	Question:    "Go 的并发原语是什么？",
	Options:     []string{"Thread", "Goroutine", "Process", "Fiber"},
	IsAnonymous: false,
	Type:        "quiz",
	CorrectOptionID: 1, // Goroutine 是正确答案
	Explanation: "Go 使用 Goroutine 实现轻量级并发，由 runtime 调度。",
}
bot.SendPoll(chatID, quiz)

// 停止投票
pollResult, _ := bot.StopPoll(pollMsg)
fmt.Printf("最终票数: %+v\n", pollResult.Options)
```

#### 3.7 文件操作

| 方法 | 签名 | 说明 |
|---|---|---|
| `FileByID` | `func (b *Bot) FileByID(fileID string) (File, error)` | 获取文件信息 |
| `Download` | `func (b *Bot) Download(file File, dst io.Writer) error` | 下载文件 |
| `GetFileURL` | `func (b *Bot) GetFileURL(file File) string` | 获取文件直链 |

```go
// 获取文件信息
fileInfo, err := bot.FileByID(msg.Document.FileID)
fmt.Printf("文件大小: %d bytes, 路径: %s\n", fileInfo.FileSize, fileInfo.FilePath)

// 下载到文件
dst, _ := os.Create("./downloads/" + msg.Document.FileName)
defer dst.Close()
bot.Download(fileInfo, dst)

// 下载到内存
var buf bytes.Buffer
bot.Download(fileInfo, &buf)
data := buf.Bytes()

// 获取直链
url := bot.GetFileURL(fileInfo)
fmt.Println("直链:", url)
// https://api.telegram.org/file/bot<TOKEN>/<file_path>
```

#### 3.8 Webhook

| 方法 | 签名 | 说明 |
|---|---|---|
| `SetWebhook` | `func (b *Bot) SetWebhook(webhook *Webhook) error` | 设置 Webhook |
| `DeleteWebhook` | `func (b *Bot) DeleteWebhook(drop ...bool) error` | 删除 Webhook |
| `GetWebhookInfo` | `func (b *Bot) GetWebhookInfo() (*WebhookInfo, error)` | 获取 Webhook 状态 |

```go
// 设置 Webhook
webhook := &telebot.Webhook{
	Endpoint: &telebot.WebhookEndpoint{
		PublicURL: "https://your-domain.com/webhook",
		Listen:    ":8443",
		CertFile:  "./certs/fullchain.pem",
		KeyFile:   "./certs/privkey.pem",
	},
	MaxConnections: 100,
	AllowedUpdates: []string{"message", "callback_query", "inline_query"},
}
bot.SetWebhook(webhook)

// 使用已有 HTTP Server（推荐）
bot.Handle(telebot.OnText, func(c telebot.Context) error {
	return c.Send("Webhook 模式运行中")
})
bot.StartWebhook(webhook) // 非阻塞

// 删除 Webhook（切回 Long Polling 前必须调用）
bot.DeleteWebhook(true)

// 查看 Webhook 状态
info, _ := bot.GetWebhookInfo()
fmt.Printf("URL: %s\n待处理更新: %d\n最近错误: %s\n",
	info.URL, info.PendingUpdateCount, info.LastErrorMessage)
```

#### 3.9 命令管理

| 方法 | 签名 | 说明 |
|---|---|---|
| `SetCommands` | `func (b *Bot) SetCommands(commands ...Command) error` | 设置命令列表 |
| `GetCommands` | `func (b *Bot) GetCommands() ([]Command, error)` | 获取命令列表 |
| `DeleteCommands` | `func (b *Bot) DeleteCommands(commands ...Command) error` | 删除命令 |
| `SetMyDescription` | `func (b *Bot) SetMyDescription(desc string) error` | 设置 Bot 描述 |
| `SetMyShortDescription` | `func (b *Bot) SetMyShortDescription(desc string) error` | 设置短描述 |

```go
// 设置命令列表（用户在输入框输入 / 时显示）
bot.SetCommands(
	telebot.Command{Text: "start", Description: "开始使用"},
	telebot.Command{Text: "help", Description: "查看帮助"},
	telebot.Command{Text: "settings", Description: "个人设置"},
	telebot.Command{Text: "about", Description: "关于本机器人"},
)

// 设置多语言命令
bot.SetCommands(
	telebot.Command{Text: "start", Description: "开始使用"},
).WithScope(telebot.AllChatAdministrators())

// 设置 Bot 描述（BotFather /setdescription 的 API 等价）
bot.SetMyDescription("这是一个用 Go + telebot.v4 编写的 Telegram 机器人")

// 设置短描述（转发时显示）
bot.SetMyShortDescription("Go 编写的高效 Telegram Bot")
```

#### 3.10 获取 Bot 信息

```go
// GetMe - 获取 Bot 自身信息
me, err := bot.GetMe()
fmt.Printf("ID: %d\n用户名: @%s\n名称: %s\nCanJoinGroups: %v\n", 
	me.ID, me.Username, me.FirstName, me.CanJoinGroups)
```

### 四、Recipient 接口

所有发送方法的第一个参数都是 `Recipient` 接口：

```go
type Recipient interface {
	Recipient() string // 返回 ChatID 字符串或 @username
}
```

实现 `Recipient` 的类型：

| 类型 | Recipient() 返回值 | 说明 |
|---|---|---|
| `ChatID(int64)` | `"123456789"` | 用数字 ID 指定 |
| `*User` | `"@username"` | 用用户名指定 |
| `*Chat` | `"-100123456789"` | 群组/频道 ID |
| 自定义类型 | 自定义 | 实现 Recipient 接口即可 |

```go
// 用 ChatID
bot.Send(telebot.ChatID(123456789), "你好")

// 用用户名
user := &telebot.User{Username: "john_doe"}
bot.Send(user, "你好 John")

// 用 Chat 对象
chat := &telebot.Chat{ID: -100123456789, Type: "supergroup"}
bot.Send(chat, "群公告")

// 自定义类型
type Channel struct {
	ChannelName string
}
func (c *Channel) Recipient() string {
	return "@" + c.ChannelName
}
bot.Send(&Channel{ChannelName: "my_channel"}, "频道消息")
```

### 五、Editable 接口

编辑/删除方法的参数类型是 `Editable`：

```go
type Editable interface {
	MessageSig() (chatID int64, messageID int)
}
```

`*Message` 天然实现此接口，你也可以自定义：

```go
// 用消息 ID 直接操作
type MsgRef struct {
	ChatID    int64
	MessageID int
}
func (m *MsgRef) MessageSig() (int64, int) {
	return m.ChatID, m.MessageID
}

// 保存消息引用，后续编辑
ref := &MsgRef{ChatID: 123, MessageID: 456}
bot.Edit(ref, "更新后的内容")
bot.Delete(ref)
```

---

> **第二部分完**。下一部分将讲解 Handler 注册与事件处理。

---
# Go + telebot.v4 服务端完整教程（第三部分：Handler 与事件处理）

---

## 第三部分：Handler 与事件处理

### 一、Handler 注册机制

telebot 使用**路由树**模式注册处理器，支持精确匹配、正则匹配、函数匹配三种方式。

```go
// 函数签名
func (b *Bot) Handle(endpoint any, handler HandlerFunc, middleware ...MiddlewareFunc)
func (b *Bot) Handle(endpoint any, handler HandlerFunc, middleware ...MiddlewareFunc)

// HandlerFunc 签名
type HandlerFunc func(c Context) error
```

### 二、命令处理

```go
// 精确命令匹配
bot.Handle("/start", func(c telebot.Context) error {
	return c.Send("👋 欢迎！")
})

// 带参数
bot.Handle("/echo", func(c telebot.Context) error {
	args := c.Args() // 返回 []string，不含 /echo
	if len(args) == 0 {
		return c.Send("用法: /echo <内容>")
	}
	return c.Send(strings.Join(args, " "))
})

// 多个命令共享处理器
echoHandler := func(c telebot.Context) error {
	return c.Send("重复: " + c.Text())
}
bot.Handle("/echo", echoHandler)
bot.Handle("/repeat", echoHandler)
```

### 三、事件常量（全量）

| 常量 | 触发条件 |
|---|---|
| `OnText` | 收到纯文本消息（不含命令） |
| `OnPhoto` | 收到图片 |
| `OnVideo` | 收到视频 |
| `OnAudio` | 收到音频文件 |
| `OnVoice` | 收到语音消息 |
| `OnDocument` | 收到文件/文档 |
| `OnSticker` | 收到贴纸 |
| `OnAnimation` | 收到 GIF/动画 |
| `OnLocation` | 收到位置信息 |
| `OnContact` | 收到联系人分享 |
| `OnVenue` | 收到地点（带地址） |
| `OnMediaGroup` | 收到媒体组（相册） |
| `OnCallback` | 收到回调查询 |
| `OnQuery` | 收到内联查询 |
| `OnChosenInlineResult` | 用户选择了内联结果 |
| `OnNewChatMembers` | 新成员加入群 |
| `OnLeftChatMember` | 成员离开群 |
| `OnNewChatTitle` | 群标题变更 |
| `OnNewChatPhoto` | 群头像变更 |
| `OnDeleteChatPhoto` | 群头像被删 |
| `OnGroupCreated` | 群组创建 |
| `OnPinnedMessage` | 消息被置顶 |
| `OnChannelPost` | 频道帖子 |
| `OnEditedChannelPost` | 频道帖子被编辑 |
| `OnEditedMessage` | 消息被编辑 |
| `OnMyChatMember` | Bot 自身成员状态变更 |
| `OnChatMember` | 群成员状态变更 |
| `OnPoll` | 收到投票 |
| `OnPollAnswer` | 投票被回答 |
| `OnInvoice` | 收到发票 |
| `OnPreCheckout` | 预结账查询 |
| `OnShippingQuery` | 运费查询 |
| `OnAddedToGroup` | Bot 被加入群组 |
| `OnRemovedFromGroup` | Bot 被移出群组 |
| `OnVideoNote` | 收到视频笔记（圆形视频） |
| `OnDice` | 收到骰子消息 |
| `OnPassportData` | 收到 Telegram Passport 数据 |

### 四、事件处理示例

```go
// 文本消息（兜底处理）
bot.Handle(telebot.OnText, func(c telebot.Context) error {
	return c.Send("收到文本: " + c.Text())
})

// 图片
bot.Handle(telebot.OnPhoto, func(c telebot.Context) error {
	photos := c.Message().Photo
	// photos 是数组，最后一个元素分辨率最高
	photo := photos[len(photos)-1]
	return c.Send(fmt.Sprintf("📸 收到图片: %dx%d, ID: %s",
		photo.Width, photo.Height, photo.FileID))
})

// 视频
bot.Handle(telebot.OnVideo, func(c telebot.Context) error {
	video := c.Message().Video
	return c.Send(fmt.Sprintf("🎬 视频: %s, 时长: %ds",
		video.FileName, video.Duration))
})

// 语音
bot.Handle(telebot.OnVoice, func(c telebot.Context) error {
	voice := c.Message().Voice
	return c.Send(fmt.Sprintf("🎤 语音: %ds", voice.Duration))
})

// 贴纸
bot.Handle(telebot.OnSticker, func(c telebot.Context) error {
	sticker := c.Message().Sticker
	return c.Send(fmt.Sprintf("😀 贴纸: %s (emoji: %s)", sticker.SetName, sticker.Emoji))
})

// 位置
bot.Handle(telebot.OnLocation, func(c telebot.Context) error {
	loc := c.Message().Location
	return c.Send(fmt.Sprintf("📍 位置: %.4f, %.4f", loc.Lat, loc.Lng))
})

// 联系人
bot.Handle(telebot.OnContact, func(c telebot.Context) error {
	contact := c.Message().Contact
	return c.Send(fmt.Sprintf("👤 联系人: %s %s, 电话: %s",
		contact.FirstName, contact.LastName, contact.PhoneNumber))
})

// 媒体组
bot.Handle(telebot.OnMediaGroup, func(c telebot.Context) error {
	return c.Send("📸 收到一组媒体！")
})

// 新成员加入
bot.Handle(telebot.OnNewChatMembers, func(c telebot.Context) error {
	members := c.Message().NewChatMembers
	var names []string
	for _, m := range members {
		names = append(names, m.FirstName)
	}
	return c.Send(fmt.Sprintf("🎉 欢迎 %s 加入群聊！", strings.Join(names, ", ")))
})

// 成员离开
bot.Handle(telebot.OnLeftChatMember, func(c telebot.Context) error {
	member := c.Message().LeftChatMember
	return c.Send(fmt.Sprintf("👋 %s 离开了群聊", member.FirstName))
})

// 群标题变更
bot.Handle(telebot.OnNewChatTitle, func(c telebot.Context) error {
	return c.Send("📝 群标题已变更为: " + c.Message().NewChatTitle)
})

// Bot 被加入群组
bot.Handle(telebot.OnAddedToGroup, func(c telebot.Context) error {
	chat := c.Chat()
	return c.Send(fmt.Sprintf("✅ 感谢将我加入「%s」！输入 /help 查看可用命令", chat.Title))
})

// Bot 被移出群组
bot.Handle(telebot.OnRemovedFromGroup, func(c telebot.Context) error {
	chatID := c.Chat().ID
	log.Printf("Bot 被移出群组: %d", chatID)
	return nil
})
```

### 五、Context 接口详解

```go
type Context interface {
	// 基础信息
	Message() *Message       // 当前消息
	Sender() *User           // 发送者
	Chat() *Chat             // 所在聊天
	Text() string            // 消息文本
	Args() []string          // 命令参数（不含命令本身）
	Arg(n int) string        // 第 n 个参数

	// 回调数据
	Data() string            // Callback 数据
	Callback() *Callback     // 完整回调对象

	// 发送
	Send(what any, opts ...any) (*Message, error)
	Reply(what any, opts ...any) (*Message, error)
	Edit(what any, opts ...any) (*Message, error)
	Delete() error
	Forward(to Recipient, opts ...any) (*Message, error)
	Copy(to Recipient, opts ...any) (*Message, error)

	// 快捷回复
	Answer(text string, opts ...any) error
	Notify(text string, opts ...any) error
	Respond(opts ...any) error

	// 状态管理
	State() State
	Set(state State) error
	Reset() error
	Get(key string) (any, bool)
	SetData(key string, val any)

	// 流程控制
	Prompt(text string, handler HandlerFunc) error
	Next(handler HandlerFunc) error

	// 权限
	Ban(duration ...time.Duration) error
	Kick() error

	// 原始更新
	Update() *Update
}
```

### 六、Prompt 与 Next（对话流）

```go
// Prompt - 发送问题并等待用户下一条消息
bot.Handle("/name", func(c telebot.Context) error {
	c.Send("请输入你的名字：")
	return c.Prompt("waiting_for_name", func(c telebot.Context) error {
		name := c.Text()
		return c.Send(fmt.Sprintf("你好，%s！", name))
	})
})

// Next - 注册下一条消息的处理器
bot.Handle("/register", func(c telebot.Context) error {
	c.Send("请输入你的邮箱：")
	return c.Next(func(c telebot.Context) error {
		email := c.Text()
		if !strings.Contains(email, "@") {
			c.Send("❌ 邮箱格式不正确，请重新输入：")
			return c.Next(nil) // 继续等待
		}
		c.Send("请输入你的手机号：")
		return c.Next(func(c telebot.Context) error {
			phone := c.Text()
			return c.Send(fmt.Sprintf("✅ 注册成功！\n邮箱: %s\n手机: %s", email, phone))
		})
	})
})
```

### 七、命令参数解析

```go
bot.Handle("/set", func(c telebot.Context) error {
	args := c.Args()
	if len(args) < 2 {
		return c.Send("用法: /set <key> <value>")
	}
	key := args[0]
	value := strings.Join(args[1:], " ")
	// 保存到数据库/缓存
	saveSetting(c.Sender().ID, key, value)
	return c.Send(fmt.Sprintf("✅ 已设置 %s = %s", key, value))
})

// 带引号参数解析
bot.Handle("/say", func(c telebot.Context) error {
	// 用户输入: /say hello "my friend" how are you
	// c.Args() = ["hello", "my friend", "how", "are", "you"]
	// 需要用自定义解析保留引号内容
	text := c.Message().Payload // 获取命令后的原始文本
	return c.Send("你说: " + text)
})
```

### 八、错误处理

```go
// 全局错误处理器
bot.Settings.OnError = func(err error, c telebot.Context) {
	log.Printf("❌ 错误: %v | 用户: %d | 消息: %s", 
		err, c.Sender().ID, c.Text())

	// 通知用户
	c.Send("⚠️ 处理出错，请稍后重试")
}

// 单个 Handler 中的错误
bot.Handle("/divide", func(c telebot.Context) error {
	args := c.Args()
	if len(args) != 2 {
		return c.Send("用法: /divide <a> <b>")
	}
	a, err1 := strconv.Atoi(args[0])
	b, err2 := strconv.Atoi(args[1])
	if err1 != nil || err2 != nil {
		return c.Send("❌ 请输入有效数字")
	}
	if b == 0 {
		return c.Send("❌ 除数不能为零")
	}
	return c.Send(fmt.Sprintf("结果: %d / %d = %d", a, b, a/b))
})
```

### 九、路由分组（Middleware 链）

```go
// 使用 Middleware 实现路由分组
func adminOnly(next telebot.HandlerFunc) telebot.MiddlewareFunc {
	return func(c telebot.Context) error {
		userID := c.Sender().ID
		if !isAdmin(userID) {
			return c.Send("❌ 你没有管理员权限")
		}
		return next(c)
	}
}

func logged(next telebot.HandlerFunc) telebot.MiddlewareFunc {
	return func(c telebot.Context) error {
		start := time.Now()
		err := next(c)
		log.Printf("⏱️ %s 处理耗时: %v", c.Text(), time.Since(start))
		return err
	}
}

// 注册带中间件的 Handler
bot.Handle("/admin_stats", logged(adminOnly(func(c telebot.Context) error {
	return c.Send("📊 管理员统计面板")
})))

bot.Handle("/admin_ban", adminOnly(func(c telebot.Context) error {
	return c.Send("🔨 封禁功能")
}))
```

---

> **第三部分完**。下一部分将讲解键盘与交互。

---
# Go + telebot.v4 服务端完整教程（第四部分：键盘与交互）

---

## 第四部分：键盘与交互

### 一、ReplyMarkup 结构

```go
type ReplyMarkup struct {
	// 内联键盘（消息内按钮，点击触发回调）
	InlineKeyboard [][]InlineButton

	// 回复键盘（输入框上方，点击发送文本）
	ReplyKeyboard [][]ReplyButton
	ResizeReplyKeyboard  bool
	OneTimeReplyKeyboard bool
	RemoveReplyKeyboard  bool

	// 强制回复（打开键盘）
	ForceReply          bool
	ForceReplySelective bool

	// 占位符
	InputFieldPlaceholder string

	// 选择性（仅对指定用户生效）
	Selective bool
}
```

### 二、InlineKeyboard（内联键盘）

#### 2.1 创建按钮

```go
// InlineButton 结构
type InlineButton struct {
	Text   string  // 显示文字
	Unique string  // 唯一标识（用于回调路由）
	Data   string  // 回调数据
	URL    string  // 打开链接
	Login  *Login  // 登录按钮
	Pay    bool    // 支付按钮
	WebApp *WebApp // Web App 按钮
}
```

#### 2.2 快捷创建方法

```go
markup := &telebot.ReplyMarkup{}

// 方式1：Data 按钮（回调）
btnLike := markup.Data("👍 点赞", "like", "msg_42")
btnDislike := markup.Data("👎 踩", "dislike", "msg_42")

// 方式2：URL 按钮
btnWeb := markup.URL("🌐 访问网站", "https://example.com")

// 方式3：Pay 按钮
btnPay := markup.Pay("💳 支付 9.9元")

// 方式4：WebApp 按钮
btnMiniApp := markup.WebApp("🎮 打开小游戏", &telebot.WebApp{
	URL: "https://your-mini-app.com",
})

// 排列为 2 行
markup.InlineKeyboard = [][]telebot.InlineButton{
	{btnLike, btnDislike},
	{btnWeb, btnMiniApp},
}
```

#### 2.3 完整示例：分页菜单

```go
func createPagination(currentPage, totalPages int) *telebot.ReplyMarkup {
	markup := &telebot.ReplyMarkup{}

	prevText := "◀️ 上一页"
	nextText := "下一页 ▶️"
	pageText := fmt.Sprintf("📄 %d/%d", currentPage, totalPages)

	var prevBtn, nextBtn telebot.InlineButton
	if currentPage > 1 {
		prevBtn = markup.Data(prevText, "page", fmt.Sprintf("%d", currentPage-1))
	}
	if currentPage < totalPages {
		nextBtn = markup.Data(nextText, "page", fmt.Sprintf("%d", currentPage+1))
	}

	pageBtn := markup.Data(pageText, "page_info", fmt.Sprintf("%d", currentPage))

	row := []telebot.InlineButton{}
	if currentPage > 1 {
		row = append(row, prevBtn)
	}
	row = append(row, pageBtn)
	if currentPage < totalPages {
		row = append(row, nextBtn)
	}

	markup.InlineKeyboard = [][]telebot.InlineButton{row}
	return markup
}

// 使用
bot.Handle("/page", func(c telebot.Context) error {
	markup := createPagination(1, 5)
	return c.Send("请选择页面：", markup)
})

// 处理分页回调
bot.Handle(telebot.OnCallback, func(c telebot.Context) error {
	data := c.Data() // "page:2" 格式
	parts := strings.Split(data, ":")
	if len(parts) != 2 || parts[0] != "page" {
		return c.Respond()
	}
	page, _ := strconv.Atoi(parts[1])
	markup := createPagination(page, 5)
	return c.Edit("请选择页面：", markup)
})
```

#### 2.4 菜单树（多级菜单）

```go
func mainMenu() *telebot.ReplyMarkup {
	markup := &telebot.ReplyMarkup{}
	btnShop := markup.Data("🛒 商店", "menu", "shop")
	btnProfile := markup.Data("👤 个人中心", "menu", "profile")
	btnHelp := markup.Data("❓ 帮助", "menu", "help")
	markup.InlineKeyboard = [][]telebot.InlineButton{
		{btnShop, btnProfile},
		{btnHelp},
	}
	return markup
}

func shopMenu() *telebot.ReplyMarkup {
	markup := &telebot.ReplyMarkup{}
	btnBuy := markup.Data("💰 购买", "shop", "buy")
	btnCart := markup.Data("🛍️ 购物车", "shop", "cart")
	btnBack := markup.Data("◀️ 返回", "menu", "main")
	markup.InlineKeyboard = [][]telebot.InlineButton{
		{btnBuy, btnCart},
		{btnBack},
	}
	return markup
}

// 统一回调路由
bot.Handle(telebot.OnCallback, func(c telebot.Context) error {
	parts := strings.Split(c.Data(), ":")
	if len(parts) < 2 {
		return c.Respond()
	}
	category, action := parts[0], parts[1]

	switch category {
	case "menu":
		switch action {
		case "main":
			return c.Edit("主菜单：", mainMenu())
		case "shop":
			return c.Edit("商店：", shopMenu())
		case "profile":
			return c.Edit("个人中心", profileMenu())
		case "help":
			return c.Edit("帮助信息", helpMenu())
		}
	case "shop":
		// 处理商店操作
		return c.Respond(&telebot.CallbackResponse{
			Text: "处理中...",
		})
	}
	return c.Respond()
})
```

### 三、ReplyKeyboard（回复键盘）

```go
// 创建回复键盘
markup := &telebot.ReplyMarkup{
	ResizeReplyKeyboard:  true,  // 自动调整大小
	OneTimeReplyKeyboard: false, // 不一次性隐藏
	InputFieldPlaceholder: "输入消息...",
}

btn1 := telebot.ReplyButton{Text: "📊 统计"}
btn2 := telebot.ReplyButton{Text: "⚙️ 设置"}
btn3 := telebot.ReplyButton{Text: "📞 联系客服"}
btn4 := telebot.ReplyButton{Text: "📍 发送位置", RequestLocation: true}
btn5 := telebot.ReplyButton{Text: "📞 分享联系人", RequestContact: true}

markup.ReplyKeyboard = [][]telebot.ReplyButton{
	{btn1, btn2},
	{btn3},
	{btn4, btn5},
}

bot.Send(chat, "请选择操作：", markup)
```

#### 3.1 隐藏回复键盘

```go
// 方式1：发送消息时移除
bot.Send(chat, "键盘已隐藏", &telebot.ReplyMarkup{
	RemoveReplyKeyboard: true,
})

// 方式2：ReplyKeyboardRemove
removeMarkup := &telebot.ReplyMarkup{
	RemoveReplyKeyboard: true,
}
bot.Send(chat, "再见 👋", removeMarkup)
```

#### 3.2 强制回复

```go
markup := &telebot.ReplyMarkup{
	ForceReply:          true,
	InputFieldPlaceholder: "请输入回复内容...",
}
bot.Send(chat, "请回复这条消息：", markup)
```

### 四、Callback 处理详解

```go
// 完整回调处理
bot.Handle(telebot.OnCallback, func(c telebot.Context) error {
	callback := c.Callback()
	log.Printf("🔘 回调: data=%s, from=%s, msg_id=%d",
		callback.Data, callback.Sender.Username, callback.Message.ID)

	// 响应回调（让按钮不再转圈）
	return c.Respond(&telebot.CallbackResponse{
		Text:      "✅ 已处理",  // 弹出提示文字
		ShowAlert: false,         // true=弹窗, false=顶部提示
	})
})

// 带弹窗的响应
bot.Handle(telebot.OnCallback, func(c telebot.Context) error {
	data := c.Data()
	if data == "delete" {
		// 删除消息
		c.Delete()
		return c.Respond(&telebot.CallbackResponse{
			Text:      "🗑️ 消息已删除",
			ShowAlert: true, // 弹窗提示
		})
	}
	return c.Respond()
})
```

### 五、Web App 按钮

```go
// Telegram Web App（Mini App）按钮
markup := &telebot.ReplyMarkup{}
btnApp := markup.WebApp("🎮 打开应用", &telebot.WebApp{
	URL: "https://your-web-app.com?user_id=123",
})
markup.InlineKeyboard = [][]telebot.InlineButton{{btnApp}}

bot.Send(chat, "点击下方按钮打开应用：", markup)

// 在 Web App 中通过 Telegram.WebApp API 与 Bot 通信
// 前端 JS:
//   Telegram.WebApp.ready()
//   Telegram.WebApp.expand()
//   Telegram.WebApp.sendData(JSON.stringify({action: 'submit', data: formData}))
```

### 六、Login 按钮

```go
// Telegram Login Widget
markup := &telebot.ReplyMarkup{}
btnLogin := markup.Login(&telebot.Login{
	URL: "https://your-site.com/auth/telegram",
})
markup.InlineKeyboard = [][]telebot.InlineButton{{btnLogin}}

bot.Send(chat, "点击下方按钮使用 Telegram 账号登录：", markup)
```

### 七、完整实战：投票机器人

```go
type Poll struct {
	Question string
	Options  []string
	Votes    map[string]map[int]bool // chatID -> optionIndex -> voted
}

var activePolls = make(map[string]*Poll)
var pollMutex sync.RWMutex

func createPollMarkup(pollID string, poll *Poll) *telebot.ReplyMarkup {
	markup := &telebot.ReplyMarkup{}
	var rows [][]telebot.InlineButton

	for i, opt := range poll.Options {
		btn := markup.Data(fmt.Sprintf("%s", opt), "vote", fmt.Sprintf("%s:%d", pollID, i))
		rows = append(rows, []telebot.InlineButton{btn})
	}
	// 查看结果按钮
	btnResult := markup.Data("📊 查看结果", "result", pollID)
	rows = append(rows, []telebot.InlineButton{btnResult})

	markup.InlineKeyboard = rows
	return markup
}

func voteCount(poll *Poll, optionIdx int) int {
	count := 0
	for _, voters := range poll.Votes {
		if voters[optionIdx] {
			count++
		}
	}
	return count
}

bot.Handle("/poll", func(c telebot.Context) error {
	args := c.Args()
	if len(args) < 3 {
		return c.Send(`用法: /poll "问题" "选项1" "选项2" ...`)
	}

	pollID := fmt.Sprintf("%d_%d", c.Chat().ID, time.Now().Unix())
	poll := &Poll{
		Question: args[0],
		Options:  args[1:],
		Votes:    make(map[string]map[int]bool),
	}

	pollMutex.Lock()
	activePolls[pollID] = poll
	pollMutex.Unlock()

	markup := createPollMarkup(pollID, poll)
	return c.Send("📊 " + poll.Question, markup)
})

bot.Handle(telebot.OnCallback, func(c telebot.Context) error {
	parts := strings.Split(c.Data(), ":")
	if len(parts) < 2 {
		return c.Respond()
	}

	action := parts[0]
	switch action {
	case "vote":
		pollID := parts[1]
		optionIdx, _ := strconv.Atoi(parts[2])

		pollMutex.RLock()
		poll, exists := activePolls[pollID]
		pollMutex.RUnlock()

		if !exists {
			return c.Respond(&telebot.CallbackResponse{
				Text: "投票已结束", ShowAlert: true,
			})
		}

		chatKey := fmt.Sprintf("%d", c.Chat().ID)
		if poll.Votes[chatKey] == nil {
			poll.Votes[chatKey] = make(map[int]bool)
		}
		poll.Votes[chatKey][optionIdx] = true

		return c.Respond(&telebot.CallbackResponse{
			Text: "✅ 投票成功！",
		})

	case "result":
		pollID := parts[1]
		pollMutex.RLock()
		poll, exists := activePolls[pollID]
		pollMutex.RUnlock()

		if !exists {
			return c.Respond(&telebot.CallbackResponse{Text: "投票不存在"})
		}

		var result strings.Builder
		result.WriteString("📊 投票结果\n\n")
		for i, opt := range poll.Options {
			count := voteCount(poll, i)
			result.WriteString(fmt.Sprintf("%s: %d 票\n", opt, count))
		}
		return c.Edit(result.String())
	}
	return c.Respond()
})
```

---

> **第四部分完**。下一部分将讲解 FSM 状态机。

---
# Go + telebot.v4 服务端完整教程（第五部分：FSM 状态机）

---

## 第五部分：FSM 状态机

### 一、FSM 核心概念

FSM（Finite State Machine，有限状态机）用于管理**多步骤对话流程**，比如用户注册、订单填写、配置向导等场景。

```
用户: /register
Bot: 请输入你的名字
用户: 张三
Bot: 请输入你的邮箱
用户: zhang@example.com
Bot: 请输入你的手机号
用户: 13800138000
Bot: ✅ 注册成功！
```

### 二、telebot 的 FSM 实现

telebot.v4 内置 FSM 支持，核心类型：

```go
// State 表示状态
type State string

// StatesGroup 状态组（命名空间）
type StatesGroup string

// Bot FSM 方法
bot.StateStorage() Storage        // 获取状态存储
bot.SetState(user, state) error  // 设置状态
bot.GetState(user) (State, error) // 获取状态
bot.ResetState(user) error       // 重置状态
```

### 三、内存存储 vs Redis 存储

```go
// 内存存储（开发/单实例）
import "gopkg.in/telebot.v4/storage/memory"

store := memory.NewStorage()
bot, _ := telebot.NewBot(telebot.Settings{
	Token:  token,
	Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	Store:  store, // 设置 FSM 存储
})

// Redis 存储（生产/多实例）
import "gopkg.in/telebot.v4/storage/redis"

store, _ := redis.NewStorage(redis.Config{
	Addr:     "localhost:6379",
	Password: "",
	DB:       0,
	Prefix:   "telebot_fsm:",
})
bot, _ := telebot.NewBot(telebot.Settings{
	Token:  token,
	Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	Store:  store,
})
```

### 四、完整注册流程示例

```go
package main

import (
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
	"time"

	"gopkg.in/telebot.v4"
)

// 定义状态
type RegisterState telebot.State

const (
	StateIdle         RegisterState = ""
	StateWaitingName  RegisterState = "waiting_name"
	StateWaitingEmail RegisterState = "waiting_email"
	StateWaitingPhone RegisterState = "waiting_phone"
	StateConfirming   RegisterState = "confirming"
)

// 用户数据存储在 FSM Data 中
type RegisterData struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	Phone string `json:"phone"`
}

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
var phoneRegex = regexp.MustCompile(`^1[3-9]\d{9}$`)

func main() {
	bot, err := telebot.NewBot(telebot.Settings{
		Token:  os.Getenv("TELEGRAM_BOT_TOKEN"),
		Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
		Store:  memory.NewStorage(),
	})
	if err != nil {
		log.Fatal(err)
	}

	// 启动注册
	bot.Handle("/register", func(c telebot.Context) error {
		c.SetState(StateWaitingName)
		return c.Send("📝 开始注册流程\n\n请输入你的姓名：")
	})

	// 状态路由：根据当前状态分发
	bot.Handle(telebot.OnText, func(c telebot.Context) error {
		state := c.State()
		text := strings.TrimSpace(c.Text())

		switch RegisterState(state) {
		case StateWaitingName:
			return handleName(c, text)
		case StateWaitingEmail:
			return handleEmail(c, text)
		case StateWaitingPhone:
			return handlePhone(c, text)
		case StateConfirming:
			return handleConfirm(c, text)
		default:
			return c.Send("输入 /register 开始注册")
		}
	})

	// 取消命令
	bot.Handle("/cancel", func(c telebot.Context) error {
		c.ResetState()
		return c.Send("❌ 已取消注册流程")
	})

	log.Println("🤖 注册机器人已启动")
	bot.Start()
}

func handleName(c telebot.Context, name string) error {
	if len(name) < 2 || len(name) > 20 {
		return c.Send("❌ 姓名长度需 2-20 个字符，请重新输入：")
	}

	data := RegisterData{Name: name}
	c.SetData("register", data)
	c.SetState(StateWaitingEmail)
	return c.Send(fmt.Sprintf("✅ 姓名: %s\n\n请输入你的邮箱：", name))
}

func handleEmail(c telebot.Context, email string) error {
	if !emailRegex.MatchString(email) {
		return c.Send("❌ 邮箱格式不正确，请重新输入：")
	}

	var data RegisterData
	c.Get("register", &data)
	data.Email = email
	c.SetData("register", data)

	c.SetState(StateWaitingPhone)
	return c.Send(fmt.Sprintf("✅ 邮箱: %s\n\n请输入你的手机号：", email))
}

func handlePhone(c telebot.Context, phone string) error {
	if !phoneRegex.MatchString(phone) {
		return c.Send("❌ 手机号格式不正确（需为11位中国大陆号码），请重新输入：")
	}

	var data RegisterData
	c.Get("register", &data)
	data.Phone = phone
	c.SetData("register", data)

	// 展示确认信息
	summary := fmt.Sprintf(`
📋 *请确认你的信息*

姓名: %s
邮箱: %s
手机: %s

回复 *确认* 完成注册，回复 *修改* 重新开始
`, data.Name, data.Email, data.Phone)

	c.SetState(StateConfirming)
	return c.Send(summary, &telebot.SendOptions{
		ParseMode: telebot.ParseModeMarkdown,
	})
}

func handleConfirm(c telebot.Context, text string) error {
	var data RegisterData
	c.Get("register", &data)

	if text == "确认" || text == "yes" || text == "y" {
		// 保存到数据库
		saveUser(c.Sender().ID, data)

		c.ResetState()
		return c.Send(fmt.Sprintf(`
🎉 *注册成功！*

姓名: %s
邮箱: %s
手机: %s

欢迎加入！输入 /help 查看可用功能。
`, data.Name, data.Email, data.Phone), &telebot.SendOptions{
			ParseMode: telebot.ParseModeMarkdown,
		})
	}

	// 重新来过
	c.ResetState()
	return c.Send("🔄 已重置，输入 /register 重新开始")
}

func saveUser(userID int64, data RegisterData) {
	// TODO: 写入数据库
	log.Printf("💾 保存用户: ID=%d, Name=%s, Email=%s, Phone=%s",
		userID, data.Name, data.Email, data.Phone)
}
```

### 五、FSM 数据操作

```go
// 设置状态
c.SetState("waiting_input")

// 获取状态
state := c.State()
fmt.Println("当前状态:", state)

// 重置状态（回到初始）
c.ResetState()

// 保存数据（JSON 序列化后存入 Storage）
c.SetData("key", value)

// 读取数据
var data MyStruct
exists := c.Get("key", &data)
if !exists {
	// 数据不存在
}

// 删除数据
c.DeleteData("key")
```

### 六、超时清理

```go
// 启动定时清理过期状态
func startFSMCleaner(bot *telebot.Bot, timeout time.Duration) {
	ticker := time.NewTicker(5 * time.Minute)
	go func() {
		for range ticker.C {
			cleanExpiredStates(bot, timeout)
		}
	}()
}

func cleanExpiredStates(bot *telebot.Bot, timeout time.Duration) {
	// 遍历所有用户状态，超时的重置
	store := bot.StateStorage()
	// 注意：具体实现取决于 Storage 后端
	// Redis 可以通过 TTL 自动过期
}
```

### 七、基于 Redis TTL 的自动过期

```go
// 自定义 Redis Storage 包装器
type ttlStorage struct {
	telebot.Storage
	defaultTTL time.Duration
}

func (s *ttlStorage) SetState(user telebot.Recipient, state telebot.State) error {
	// 设置状态并附加 TTL
	key := fmt.Sprintf("state:%s", user.Recipient())
	// 使用 Redis SETEX 设置过期
	return s.Storage.SetState(user, state)
}

// 更简单的方式：直接用 Redis Storage + 配置 TTL
store, _ := redis.NewStorage(redis.Config{
	Addr:     "localhost:6379",
	Password: "",
	DB:       0,
	Prefix:   "bot:",
	// 状态 30 分钟过期
	StateTTL: 30 * time.Minute,
})
```

### 八、多流程并发管理

```go
// 不同流程用不同的 State 前缀
const (
	// 注册流程
	RegisterStart  telebot.State = "register:start"
	RegisterName   telebot.State = "register:name"
	RegisterEmail  telebot.State = "register:email"

	// 反馈流程
	FeedbackStart  telebot.State = "feedback:start"
	FeedbackType   telebot.State = "feedback:type"
	FeedbackDetail telebot.State = "feedback:detail"

	// 订单流程
	OrderSelect    telebot.State = "order:select"
	OrderConfirm   telebot.State = "order:confirm"
	OrderPayment   telebot.State = "order:payment"
)

// 在 Handler 中根据前缀路由
bot.Handle(telebot.OnText, func(c telebot.Context) error {
	state := c.State()
	switch {
	case strings.HasPrefix(string(state), "register:"):
		return handleRegisterFlow(c, state)
	case strings.HasPrefix(string(state), "feedback:"):
		return handleFeedbackFlow(c, state)
	case strings.HasPrefix(string(state), "order:"):
		return handleOrderFlow(c, state)
	}
	return c.Send("输入 /help 查看可用命令")
})
```

### 九、Prompt 模式（轻量 FSM 替代）

对于简单场景，用 `Prompt` 比 FSM 更简洁：

```go
// 三步走注册（无需定义状态）
bot.Handle("/quick_register", func(c telebot.Context) error {
	c.Send("请输入姓名：")
	return c.Prompt("qr_name", func(c telebot.Context) error {
		name := c.Text()
		c.Send(fmt.Sprintf("你好 %s，请输入邮箱：", name))
		return c.Prompt("qr_email", func(c telebot.Context) error {
			email := c.Text()
			c.Send(fmt.Sprintf("最后一步，请输入手机号：", name))
			return c.Prompt("qr_phone", func(c telebot.Context) error {
				phone := c.Text()
				return c.Send(fmt.Sprintf(
					"✅ 注册完成！\n姓名: %s\n邮箱: %s\n手机: %s",
					name, email, phone))
			})
		})
	})
})
```

### 十、FSM 最佳实践

| 实践 | 说明 |
|---|---|
| 状态命名用前缀分组 | `register:name` / `order:pay` 避免冲突 |
| 数据用结构体 | JSON 序列化存入，方便扩展字段 |
| 设置超时 | Redis TTL 或定时清理，防止僵尸状态 |
| 提供取消命令 | `/cancel` 重置所有状态 |
| 每个状态验证输入 | 非法输入时留在当前状态提示重输 |
| 不要在 FSM 中存大对象 | 只存 ID/键值对，大对象存数据库 |
| 测试状态流转 | 用表格驱动测试覆盖每种状态转换 |

---

> **第五部分完**。下一部分将讲解 Middleware 中间件。

---
# Go + telebot.v4 服务端完整教程（第六部分：Middleware 中间件）

---

## 第六部分：Middleware 中间件

### 一、Middleware 概念

Middleware（中间件）是**请求处理链**中的拦截器，在 Handler 执行前后插入逻辑：

```
请求 → Middleware1 → Middleware2 → Handler → Middleware2 → Middleware1 → 响应
```

典型用途：
- 日志记录
- 性能监控
- 权限校验
- 限流熔断
- panic 恢复
- 数据注入

### 二、Middleware 签名

```go
type MiddlewareFunc func(next telebot.HandlerFunc) telebot.HandlerFunc

// 注册方式
bot.Handle(endpoint, middleware1(middleware2(handler)))
```

### 三、内置 Middleware

telebot.v4 提供的中间件：

```go
import "gopkg.in/telebot.v4/middleware"

// Logger - 请求日志
bot.Use(middleware.Logger(middleware.LoggerConfig{
	Log: func(format string, args ...any) {
		log.Printf("[BOT] "+format, args...)
	},
}))

// Recover - panic 恢复
bot.Use(middleware.Recover(middleware.RecoverConfig{
	OnRecover: func(err error, c telebot.Context) {
		log.Printf("💥 panic 恢复: %v", err)
		c.Send("⚠️ 系统内部错误，请稍后重试")
	},
}))

// Throttle - 限流
bot.Use(middleware.Throttle(10, time.Minute)) // 每用户每分钟10条

// AutoRespond - 自动响应 Callback
bot.Use(middleware.AutoRespond())

// WhiteList - 白名单
bot.Use(middleware.WhiteList(123456, 789012)) // 仅允许指定用户ID

// BlackList - 黑名单
bot.Use(middleware.BlackList(111111, 222222)) // 禁止指定用户ID
```

### 四、自定义 Middleware

#### 4.1 日志中间件

```go
func LoggingMiddleware() telebot.MiddlewareFunc {
	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) error {
			start := time.Now()
			user := c.Sender()
			text := c.Text()

			err := next(c)

			duration := time.Since(start)
			status := "✅"
			if err != nil {
				status = "❌"
			}
			log.Printf("%s [%v] user=%d text=%q err=%v",
				status, duration, user.ID, text, err)
			return err
		}
	}
}

// 注册
bot.Use(LoggingMiddleware())
```

#### 4.2 鉴权中间件

```go
func AuthMiddleware(allowedIDs ...int64) telebot.MiddlewareFunc {
	allowed := make(map[int64]bool)
	for _, id := range allowedIDs {
		allowed[id] = true
	}

	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) error {
			userID := c.Sender().ID
			if !allowed[userID] {
				return c.Send("🚫 你没有权限使用此功能")
			}
			return next(c)
		}
	}
}

// 从数据库动态加载管理员列表
func AdminOnly(store *UserStore) telebot.MiddlewareFunc {
	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) error {
			userID := c.Sender().ID
			user, err := store.GetUser(userID)
			if err != nil || !user.IsAdmin {
				return c.Send("🔒 需要管理员权限")
			}
			// 注入用户数据到 Context
			c.Set("user", user)
			return next(c)
		}
	}
}
```

#### 4.3 限流中间件（滑动窗口）

```go
type RateLimiter struct {
	mu       sync.RWMutex
	buckets  map[int64]*tokenBucket
	rate     int           // 每秒允许的请求数
	capacity int           // 桶容量
	refill   time.Duration // 补充间隔
}

type tokenBucket struct {
	tokens     float64
	lastRefill time.Time
}

func NewRateLimiter(rate, capacity int) *RateLimiter {
	rl := &RateLimiter{
		buckets:  make(map[int64]*tokenBucket),
		rate:     rate,
		capacity: capacity,
		refill:   time.Second,
	}
	// 定期清理
	go rl.cleanup()
	return rl
}

func (rl *RateLimiter) Allow(userID int64) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	bucket, exists := rl.buckets[userID]
	if !exists {
		rl.buckets[userID] = &tokenBucket{
			tokens:     float64(rl.capacity - 1),
			lastRefill: now,
		}
		return true
	}

	// 补充令牌
	elapsed := now.Sub(bucket.lastRefill).Seconds()
	tokensToAdd := elapsed * float64(rl.rate)
	bucket.tokens = min(float64(rl.capacity), bucket.tokens+tokensToAdd)
	bucket.lastRefill = now

	if bucket.tokens >= 1 {
		bucket.tokens--
		return true
	}
	return false
}

func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		rl.mu.Lock()
		threshold := time.Now().Add(-10 * time.Minute)
		for id, b := range rl.buckets {
			if b.lastRefill.Before(threshold) {
				delete(rl.buckets, id)
			}
		}
		rl.mu.Unlock()
	}
}

// 作为 Middleware 使用
func RateLimitMiddleware(rl *RateLimiter) telebot.MiddlewareFunc {
	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) error {
			if !rl.Allow(c.Sender().ID) {
				return c.Send("⏳ 请求过于频繁，请稍后再试")
			}
			return next(c)
		}
	}
}

// 注册
rl := NewRateLimiter(5, 10) // 每秒5个，容量10
bot.Use(RateLimitMiddleware(rl))
```

#### 4.4 panic 恢复中间件

```go
func RecoverMiddleware() telebot.MiddlewareFunc {
	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) (err error) {
			defer func() {
				if r := recover(); r != nil {
					stack := debug.Stack()
					log.Printf("💥 panic: %v\n%s", r, stack)
					err = c.Send("⚠️ 系统繁忙，请稍后重试")
				}
			}()
			return next(c)
		}
	}
}
```

#### 4.5 性能监控中间件

```go
func MetricsMiddleware(metrics *Metrics) telebot.MiddlewareFunc {
	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) error {
			start := time.Now()
			err := next(c)
			duration := time.Since(start)

			handlerName := getHandlerName(c)
			metrics.Record(handlerName, duration, err != nil)

			// 慢查询告警
			if duration > 3*time.Second {
				log.Printf("🐢 慢处理: %s 耗时 %v", handlerName, duration)
			}
			return err
		}
	}
}

type Metrics struct {
	mu       sync.RWMutex
	counts   map[string]int64
	durations map[string]time.Duration
	errors   map[string]int64
}

func NewMetrics() *Metrics {
	return &Metrics{
		counts:    make(map[string]int64),
		durations: make(map[string]time.Duration),
		errors:    make(map[string]int64),
	}
}

func (m *Metrics) Record(name string, d time.Duration, isErr bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.counts[name]++
	m.durations[name] = (m.durations[name] + d) / 2 // 滑动平均
	if isErr {
		m.errors[name]++
	}
}

func (m *Metrics) Snapshot() map[string]any {
	m.mu.RLock()
	defer m.mu.RUnlock()
	// 返回副本
	return map[string]any{
		"counts":    copyMap(m.counts),
		"durations": copyMap(m.durations),
		"errors":    copyMap(m.errors),
	}
}
```

#### 4.6 数据注入中间件

```go
// 从数据库加载用户并注入 Context
func InjectUser(store *UserStore) telebot.MiddlewareFunc {
	return func(next telebot.HandlerFunc) telebot.HandlerFunc {
		return func(c telebot.Context) error {
			userID := c.Sender().ID
			user, err := store.GetOrCreate(userID, c.Sender().FirstName)
			if err != nil {
				return c.Send("⚠️ 系统错误，请稍后重试")
			}
			// 存入 Context
			c.Set("user", user)
			return next(c)
		}
	}
}

// 在 Handler 中获取
bot.Handle("/profile", func(c telebot.Context) error {
	user := c.Get("user").(*User)
	return c.Send(fmt.Sprintf("👤 %s\n📧 %s\n📞 %s",
		user.Name, user.Email, user.Phone))
})
```

### 五、Middleware 执行顺序

```go
// 注册顺序 = 执行顺序（洋葱模型）
bot.Use(middleware1) // 外层
bot.Use(middleware2) // 中层
bot.Use(middleware3) // 内层

// 执行顺序：
// 请求 → m1 → m2 → m3 → Handler
// 响应 ← m1 ← m2 ← m3 ← Handler

// 实用建议：
// 1. Recover 放最外层（确保捕获所有 panic）
// 2. Logger 放第二层（记录所有请求）
// 3. Auth 放内层（在日志之后做鉴权）
// 4. RateLimit 放 Auth 之前（防止未鉴权请求打爆系统）

bot.Use(RecoverMiddleware())     // 1. 最外层
bot.Use(LoggingMiddleware())     // 2. 日志
bot.Use(RateLimitMiddleware(rl)) // 3. 限流
// Auth 只对特定 Handler 使用（不在全局注册）
```

### 六、路由级 Middleware

```go
// 全局 Middleware（所有 Handler 生效）
bot.Use(LoggingMiddleware())

// 单个 Handler 的 Middleware（更灵活）
adminOnly := AdminOnly(store)
bot.Handle("/admin", adminOnly(func(c telebot.Context) error {
	return c.Send("🔒 管理员面板")
}))

// 多个 Middleware 组合
chain := func(h telebot.HandlerFunc, mws ...telebot.MiddlewareFunc) telebot.HandlerFunc {
	for i := len(mws) - 1; i >= 0; i-- {
		h = mws[i](h)
	}
	return h
}

bot.Handle("/secure", chain(
	func(c telebot.Context) error {
		return c.Send("🔐 安全内容")
	},
	LoggingMiddleware(),
	AuthMiddleware(123, 456),
	RateLimitMiddleware(rl),
))
```

### 七、Middleware 最佳实践

| 实践 | 说明 |
|---|---|
| Recover 必须放最外层 | 确保任何 panic 都不会导致进程崩溃 |
| 限流在鉴权之前 | 防止攻击者用无效请求消耗鉴权资源 |
| Middleware 不要做重IO | 保持轻量，重操作放 Handler 或异步 |
| 用 `c.Set()` 传递数据 | 避免全局变量，保持并发安全 |
| 注意闭包变量捕获 | Middleware 中引用的变量要在每次请求时重新读取 |
| 测试每个 Middleware | 用 mock Context 单元测试 |

---

> **第六部分完**。下一部分将讲解文件处理。

---
# Go + telebot.v4 服务端完整教程（第七部分：文件处理）

---

## 第七部分：文件处理

### 一、文件来源

telebot 支持三种文件来源：

| 来源 | 函数 | 适用场景 |
|---|---|---|
| URL | `telebot.FromURL(url)` | 网络图片/视频直链 |
| 磁盘 | `telebot.FromDisk(path)` | 服务器本地文件 |
| Reader | `telebot.FromReader(io.Reader)` | 内存数据/HTTP流/生成内容 |
| Bytes | `telebot.FromBytes([]byte)` | 内存字节数组 |

### 二、发送文件

#### 2.1 发送图片

```go
// 从 URL
photo := &telebot.Photo{
	File:    telebot.FromURL("https://picsum.photos/600/400"),
	Caption: "随机图片",
}
bot.Send(chat, photo)

// 从磁盘
photo := &telebot.Photo{
	File:    telebot.FromDisk("./images/photo.jpg"),
	Caption: "本地图片",
}
bot.Send(chat, photo)

// 从内存
imgBytes := generateImage() // []byte
photo := &telebot.Photo{
	File:     telebot.FromBytes(imgBytes),
	Caption:  "动态生成",
	FileName: "generated.png",
}
bot.Send(chat, photo)
```

#### 2.2 发送视频

```go
video := &telebot.Video{
	File:     telebot.FromDisk("./videos/clip.mp4"),
	Caption:  "🎬 精彩片段",
	Duration: 30,                    // 时长（秒）
	Width:    1920,                   // 宽度
	Height:   1080,                   // 高度
	Thumb:    telebot.FromDisk("./thumbs/clip.jpg"), // 缩略图
}
bot.Send(chat, video)
```

#### 2.3 发送文档

```go
doc := &telebot.Document{
	File:     telebot.FromDisk("./files/report.pdf"),
	FileName: "2024年度报告.pdf",  // 显示给用户的文件名
	Caption:  "📄 请查收",
	MIME:     "application/pdf",    // MIME 类型
}
bot.Send(chat, doc)

// 发送代码文件
doc := &telebot.Document{
	File:     telebot.FromDisk("./main.go"),
	FileName: "main.go",
	Caption:  "📝 Go 源码",
}
bot.Send(chat, doc)
```

#### 2.4 发送音频

```go
audio := &telebot.Audio{
	File:     telebot.FromDisk("./music/song.mp3"),
	Caption:  "🎵 好听的歌",
	Duration: 180,    // 时长
	Title:    "Song Title",
	Performer: "Artist Name",
}
bot.Send(chat, audio)

// 语音消息（OGG/OPUS）
voice := &telebot.Voice{
	File:     telebot.FromDisk("./voice.ogg"),
	Duration: 10,
}
bot.Send(chat, voice)
```

### 三、媒体组（Album）

```go
// 发送图片组
album := telebot.Album{
	&telebot.Photo{File: telebot.FromURL("https://picsum.photos/400/300?1")},
	&telebot.Photo{File: telebot.FromURL("https://picsum.photos/400/300?2")},
	&telebot.Photo{File: telebot.FromURL("https://picsum.photos/400/300?3")},
}

msgs, err := bot.SendAlbum(chat, album, &telebot.SendOptions{
	Caption: "📸 相册",
})

// 混合类型媒体组
album := telebot.Album{
	&telebot.Photo{File: telebot.FromDisk("./img1.jpg")},
	&telebot.Video{File: telebot.FromDisk("./vid1.mp4")},
	&telebot.Document{File: telebot.FromDisk("./doc1.pdf")},
}
msgs, err := bot.SendAlbum(chat, album)

// 批量发送多张本地图片
func sendDirectoryAsAlbum(bot *telebot.Bot, chat telebot.Recipient, dir string) error {
	files, _ := filepath.Glob(filepath.Join(dir, "*.jpg"))
	if len(files) == 0 {
		return fmt.Errorf("目录为空")
	}

	// Telegram 限制：每组最多 10 个
	const maxPerAlbum = 10
	for i := 0; i < len(files); i += maxPerAlbum {
		end := i + maxPerAlbum
		if end > len(files) {
			end = len(files)
		}

		album := telebot.Album{}
		for _, f := range files[i:end] {
			album = append(album, &telebot.Photo{
				File: telebot.FromDisk(f),
			})
		}

		_, err := bot.SendAlbum(chat, album)
		if err != nil {
			return err
		}
	}
	return nil
}
```

### 四、文件下载

#### 4.1 下载到磁盘

```go
// 获取文件信息
file := msg.Document
fileInfo, err := bot.FileByID(file.FileID)
if err != nil {
	return err
}

// 创建目标文件
dst, _ := os.Create("./downloads/" + file.FileName)
defer dst.Close()

// 下载
err = bot.Download(fileInfo, dst)
if err != nil {
	return fmt.Errorf("下载失败: %w", err)
}

log.Printf("✅ 文件已保存: %s (%d bytes)", file.FileName, fileInfo.FileSize)
```

#### 4.2 下载到内存

```go
// 下载到 bytes.Buffer
var buf bytes.Buffer
fileInfo, _ := bot.FileByID(msg.Photo[len(msg.Photo)-1].FileID)
bot.Download(fileInfo, &buf)

// 直接使用
data := buf.Bytes()
log.Printf("下载完成: %d bytes", len(data))

// 转存到 S3 / 数据库
uploadToS3("photos/"+fileID+".jpg", data)
```

#### 4.3 获取直链

```go
// 获取 Telegram CDN 直链（无需下载）
fileInfo, _ := bot.FileByID(msg.Document.FileID)
url := bot.GetFileURL(fileInfo)
log.Printf("直链: %s", url)
// 输出: https://api.telegram.org/file/bot<TOKEN>/photos/file_0.jpg

// 可直接用 HTTP 下载
resp, _ := http.Get(url)
defer resp.Body.Close()
data, _ := io.ReadAll(resp.Body)
```

#### 4.4 批量下载

```go
func downloadAll(bot *telebot.Bot, msgs []*telebot.Message, dstDir string) error {
	os.MkdirAll(dstDir, 0755)

	var wg sync.WaitGroup
	errChan := make(chan error, len(msgs))

	for _, msg := range msgs {
		var fileID string
		var fileName string

		switch {
		case len(msg.Photo) > 0:
			photo := msg.Photo[len(msg.Photo)-1]
			fileID = photo.FileID
			fileName = fmt.Sprintf("photo_%s.jpg", fileID[:8])
		case msg.Video != nil:
			fileID = msg.Video.FileID
			fileName = msg.Video.FileName
			if fileName == "" {
				fileName = fmt.Sprintf("video_%s.mp4", fileID[:8])
			}
		case msg.Document != nil:
			fileID = msg.Document.FileID
			fileName = msg.Document.FileName
		default:
			continue
		}

		wg.Add(1)
		go func(fid, fname string) {
			defer wg.Done()

			fileInfo, err := bot.FileByID(fid)
			if err != nil {
				errChan <- err
				return
			}

			dst, err := os.Create(filepath.Join(dstDir, fname))
			if err != nil {
				errChan <- err
				return
			}
			defer dst.Close()

			if err := bot.Download(fileInfo, dst); err != nil {
				errChan <- err
				return
			}
			log.Printf("✅ 下载: %s", fname)
		}(fileID, fileName)
	}

	wg.Wait()
	close(errChan)

	if len(errChan) > 0 {
		return <-errChan
	}
	return nil
}
```

### 五、文件回显机器人

```go
// 完整的文件回显 Bot
package main

import (
	"log"
	"os"
	"time"

	"gopkg.in/telebot.v4"
)

func main() {
	bot, err := telebot.NewBot(telebot.Settings{
		Token:  os.Getenv("TELEGRAM_BOT_TOKEN"),
		Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	})
	if err != nil {
		log.Fatal(err)
	}

	// 回显图片
	bot.Handle(telebot.OnPhoto, func(c telebot.Context) error {
		photos := c.Message().Photo
		photo := photos[len(photos)-1] // 最高分辨率
		return c.Send(&telebot.Photo{FileID: photo.FileID}, &telebot.SendOptions{
			Caption: "📸 你的图片",
		})
	})

	// 回显视频
	bot.Handle(telebot.OnVideo, func(c telebot.Context) error {
		video := c.Message().Video
		return c.Send(&telebot.Video{FileID: video.FileID}, &telebot.SendOptions{
			Caption: "🎬 你的视频",
		})
	})

	// 回显文件
	bot.Handle(telebot.OnDocument, func(c telebot.Context) error {
		doc := c.Message().Document
		return c.Send(&telebot.Document{FileID: doc.FileID}, &telebot.SendOptions{
			Caption: "📄 你的文件",
		})
	})

	// 回显语音
	bot.Handle(telebot.OnVoice, func(c telebot.Context) error {
		voice := c.Message().Voice
		return c.Send(&telebot.Voice{FileID: voice.FileID})
	})

	// 回显贴纸
	bot.Handle(telebot.OnSticker, func(c telebot.Context) error {
		sticker := c.Message().Sticker
		return c.Send(&telebot.Sticker{FileID: sticker.FileID})
	})

	log.Println("🤖 文件回显 Bot 已启动")
	bot.Start()
}
```

### 六、文件管理最佳实践

```go
// internal/service/file_manager.go
package service

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"gopkg.in/telebot.v4"
)

type FileManager struct {
	bot      *telebot.Bot
	baseDir  string
	maxSize  int64
	mu       sync.RWMutex
	cache    map[string]string // fileID → localPath
}

func NewFileManager(bot *telebot.Bot, baseDir string) *FileManager {
	os.MkdirAll(baseDir, 0755)
	return &FileManager{
		bot:     bot,
		baseDir: baseDir,
		maxSize: 50 * 1024 * 1024, // 50MB
		cache:   make(map[string]string),
	}
}

// Download 下载并缓存
func (fm *FileManager) Download(msg *telebot.Message) (string, error) {
	var (
		fileID   string
		fileName string
	)

	switch {
	case len(msg.Photo) > 0:
		p := msg.Photo[len(msg.Photo)-1]
		fileID = p.FileID
		fileName = fmt.Sprintf("photo_%s.jpg", fileID[:10])
	case msg.Video != nil:
		fileID = msg.Video.FileID
		fileName = msg.Video.FileName
	case msg.Document != nil:
		fileID = msg.Document.FileID
		fileName = msg.Document.FileName
	default:
		return "", fmt.Errorf("不支持的文件类型")
	}

	// 检查缓存
	fm.mu.RLock()
	if path, ok := fm.cache[fileID]; ok {
		fm.mu.RUnlock()
		return path, nil
	}
	fm.mu.RUnlock()

	// 检查磁盘
	finalPath := filepath.Join(fm.baseDir, fileName)
	if _, err := os.Stat(finalPath); err == nil {
		fm.mu.Lock()
		fm.cache[fileID] = finalPath
		fm.mu.Unlock()
		return finalPath, nil
	}

	// 下载
	fileInfo, err := fm.bot.FileByID(fileID)
	if err != nil {
		return "", err
	}
	if int64(fileInfo.FileSize) > fm.maxSize {
		return "", fmt.Errorf("文件过大: %d bytes", fileInfo.FileSize)
	}

	dst, err := os.Create(finalPath)
	if err != nil {
		return "", err
	}
	defer dst.Close()

	if err := fm.bot.Download(fileInfo, dst); err != nil {
		os.Remove(finalPath)
		return "", err
	}

	fm.mu.Lock()
	fm.cache[fileID] = finalPath
	fm.mu.Unlock()

	return finalPath, nil
}

// GetURL 获取直链
func (fm *FileManager) GetURL(fileID string) (string, error) {
	fileInfo, err := fm.bot.FileByID(fileID)
	if err != nil {
		return "", err
	}
	return fm.bot.GetFileURL(fileInfo), nil
}

// Cleanup 清理过期文件
func (fm *FileManager) Cleanup(maxAge time.Duration) (int, error) {
	cutoff := time.Now().Add(-maxAge)
	count := 0

	err := filepath.Walk(fm.baseDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if info.ModTime().Before(cutoff) {
			os.Remove(path)
			count++
		}
		return nil
	})

	// 清空缓存
	fm.mu.Lock()
	fm.cache = make(map[string]string)
	fm.mu.Unlock()

	return count, err
}
```

### 七、文件大小限制参考

| 类型 | Telegram 限制 | 建议限制 |
|---|---|---|
| 图片 | 10 MB | 5 MB |
| 视频 | 50 MB | 30 MB |
| 文档 | 50 MB | 30 MB |
| 音频 | 50 MB | 20 MB |
| 语音 | 1 MB (OGG) | 1 MB |
| 贴纸 | 512 KB | 512 KB |
| 媒体组 | 10 个/组 | 10 个/组 |

---

> **第七部分完**。下一部分将讲解 Webhook 部署。

---
# Go + telebot.v4 服务端完整教程（第八部分：Webhook 部署）

---

## 第八部分：Webhook 部署

### 一、为什么用 Webhook

| 维度 | Long Polling | Webhook |
|---|---|---|
| 原理 | Bot 主动轮询 Telegram 服务器 | Telegram 主动推送更新到你的服务器 |
| 延迟 | 取决于轮询间隔（通常 1-10s） | 几乎实时（毫秒级） |
| 服务器要求 | 能访问 Telegram 即可 | 需要公网 IP + HTTPS |
| 资源消耗 | 持续占用连接 | 仅在有消息时消耗资源 |
| 适合场景 | 开发/小规模/无公网 IP | 生产环境/高并发 |

### 二、Webhook 前置条件

1. **公网 IP 或域名**
2. **HTTPS 证书**（Let's Encrypt 免费）
3. **开放端口**（默认 443，或 8443 等）

### 三、使用 telebot 内置 Webhook

```go
package main

import (
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"log"
	"os"

	"gopkg.in/telebot.v4"
)

func main() {
	bot, err := telebot.NewBot(telebot.Settings{
		Token: os.Getenv("TELEGRAM_BOT_TOKEN"),
		// Poller 不设置，使用 Webhook 模式
	})
	if err != nil {
		log.Fatal(err)
	}

	// 注册 Handler
	bot.Handle("/start", func(c telebot.Context) error {
		return c.Send("👋 Webhook 模式运行中！")
	})
	bot.Handle(telebot.OnText, func(c telebot.Context) error {
		return c.Send("你说: " + c.Text())
	})

	// 配置 Webhook
	webhook := &telebot.Webhook{
		Endpoint: &telebot.WebhookEndpoint{
			PublicURL: "https://your-domain.com", // 公网 HTTPS 地址
			Listen:    ":8443",                   // 监听端口
			CertFile:  "./certs/fullchain.pem",   // SSL 证书
			KeyFile:   "./certs/privkey.pem",    // SSL 私钥
		},
		MaxConnections: 100,                          // 最大并发连接
		AllowedUpdates: []string{                    // 只接收指定类型更新
			"message",
			"callback_query",
			"inline_query",
			"my_chat_member",
		},
	}

	// 设置 Webhook
	if err := bot.SetWebhook(webhook); err != nil {
		log.Fatalf("设置 Webhook 失败: %v", err)
	}

	// 验证 Webhook 状态
	info, _ := bot.GetWebhookInfo()
	log.Printf("✅ Webhook 已设置: %s", info.URL)

	// 启动（非阻塞）
	bot.StartWebhook(webhook)
	log.Println("🤖 Webhook 服务已启动")

	// 阻塞主线程
	select {}
}
```

### 四、使用已有 HTTP Server

```go
// 更灵活的方式：把 Webhook 挂载到自己的 HTTP Server
package main

import (
	"context"
	"crypto/tls"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"gopkg.in/telebot.v4"
)

func main() {
	bot, err := telebot.NewBot(telebot.Settings{
		Token: os.Getenv("TELEGRAM_BOT_TOKEN"),
	})
	if err != nil {
		log.Fatal(err)
	}

	// 注册 Handler
	bot.Handle("/start", func(c telebot.Context) error {
		return c.Send("👋 Hello from Webhook!")
	})

	// 创建 Webhook
	webhook := &telebot.Webhook{
		Endpoint: &telebot.WebhookEndpoint{
			PublicURL: "https://your-domain.com",
			Listen:    ":8443",
			CertFile:  "./certs/fullchain.pem",
			KeyFile:   "./certs/privkey.pem",
		},
	}
	bot.SetWebhook(webhook)

	// 创建自定义 HTTP Server
	mux := http.NewServeMux()

	// 挂载 Webhook 到 /webhook 路径
	mux.HandleFunc("/webhook", func(w http.ResponseWriter, r *http.Request) {
		bot.ServeHTTP(w, r) // telebot 提供的 HTTP Handler
	})

	// 自定义路由
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(200)
		w.Write([]byte(`{"status":"healthy"}`))
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Telegram Bot Server is running"))
	})

	// 配置 TLS
	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS12,
	}

	server := &http.Server{
		Addr:         ":8443",
		Handler:       mux,
		TLSConfig:     tlsConfig,
		ReadTimeout:   15 * time.Second,
		WriteTimeout:  15 * time.Second,
		IdleTimeout:   60 * time.Second,
		MaxHeaderBytes: 1 << 20, // 1MB
	}

	// 优雅退出
	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		log.Println("🌐 HTTPS 服务启动: https://your-domain.com:8443")
		if err := server.ListenAndServeTLS(
			"./certs/fullchain.pem",
			"./certs/privkey.pem",
		); err != nil && err != http.ErrServerClosed {
			log.Fatalf("❌ 服务异常: %v", err)
		}
	}()

	// 启动 Bot（非阻塞）
	go bot.StartWebhook(webhook)

	// 等待退出信号
	<-done
	log.Println("🛑 正在关闭...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	server.Shutdown(ctx)
	bot.Stop()
	log.Println("✅ 已安全退出")
}
```

### 五、nginx 反向代理

#### 5.1 证书申请（Let's Encrypt）

```bash
# 安装 certbot
sudo apt install -y certbot

# 申请证书（手动模式，适合已有 nginx）
sudo certbot certonly --standalone -d your-domain.com

# 证书路径
# /etc/letsencrypt/live/your-domain.com/fullchain.pem
# /etc/letsencrypt/live/your-domain.com/privkey.pem

# 自动续期（加入 crontab）
echo "0 3 * * * certbot renew --quiet" | sudo tee -a /etc/crontab
```

#### 5.2 nginx 配置

```nginx
# /etc/nginx/sites-available/telebot
upstream bot_backend {
    server 127.0.0.1:8443;
    keepalive 32;
}

# HTTP → HTTPS 重定向
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;
}

# HTTPS 主服务
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate     /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    client_max_body_size 50m;

    # Telegram Webhook 端点
    location /webhook {
        proxy_pass http://bot_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 超时设置（Telegram 可能发送大文件）
        proxy_read_timeout  300s;
        proxy_send_timeout  300s;

        # 禁用缓冲（实时性）
        proxy_buffering off;
    }

    # 健康检查
    location /health {
        proxy_pass http://bot_backend;
        access_log off;
    }

    # 静态文件（H5 管理界面）
    location / {
        root /opt/telebot-server/web/static;
        index index.html;
        try_files $uri $uri/ /index.html;

        # 缓存静态资源
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

```bash
# 启用站点
sudo ln -s /etc/nginx/sites-available/telebot /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 六、systemd 服务管理

```ini
# /etc/systemd/system/telebot.service
[Unit]
Description=Telegram Bot Server (Go + telebot.v4)
Documentation=https://github.com/go-telegram-bot-api/telebot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=telebot
Group=telebot
WorkingDirectory=/opt/telebot-server

# 可执行文件
ExecStart=/opt/telebot-server/bin/server

# 环境变量
EnvironmentFile=/opt/telebot-server/.env
Environment=GOMAXPROCS=4

# 自动重启
Restart=on-failure
RestartSec=5s
MaxRestartSec=60s

# 安全加固
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/opt/telebot-server/data

# 日志
StandardOutput=journal
StandardError=journal
SyslogIdentifier=telebot

[Install]
WantedBy=multi-user.target
```

```bash
# 创建用户
sudo useradd -r -s /bin/false telebot

# 设置权限
sudo chown -R telebot:telebot /opt/telebot-server

# 启用服务
sudo systemctl daemon-reload
sudo systemctl enable telebot.service
sudo systemctl start telebot.service

# 查看日志
sudo journalctl -u telebot -f
```

### 七、Docker 部署

#### 7.1 Dockerfile

```dockerfile
# ---- 构建阶段 ----
FROM golang:1.22-alpine AS builder

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server main.go

# ---- 运行阶段 ----
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata curl
ENV TZ=Asia/Shanghai
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime

WORKDIR /app
COPY --from=builder /build/server .
COPY --from=builder /build/web ./web

EXPOSE 8443

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8443/health || exit 1

CMD ["./server"]
```

#### 7.2 docker-compose.yml

```yaml
version: "3.9"

services:
  bot-server:
    build: .
    container_name: telebot-server
    restart: unless-stopped
    ports:
      - "8443:8443"
    env_file:
      - .env
    environment:
      - APP_ENV=production
      - GOMAXPROCS=4
    volumes:
      - ./certs:/app/certs:ro
      - bot_data:/app/data
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - bot-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8443/health"]
      interval: 30s
      timeout: 5s

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
    networks:
      - bot-net

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - ./web/static:/usr/share/nginx/html:ro
    depends_on:
      - bot-server
    networks:
      - bot-net

volumes:
  redis_data:
  bot_data:

networks:
  bot-net:
    driver: bridge
```

### 八、Webhook 管理命令

```go
// 查看 Webhook 状态
info, err := bot.GetWebhookInfo()
if err != nil {
	log.Fatal(err)
}
fmt.Printf("URL: %s\n", info.URL)
fmt.Printf("Has Custom Certificate: %v\n", info.HasCustomCertificate)
fmt.Printf("Pending Updates: %d\n", info.PendingUpdateCount)
fmt.Printf("Last Error: %s\n", info.LastErrorMessage)
fmt.Printf("Last Error Date: %v\n", info.LastErrorDate)
fmt.Printf("Max Connections: %d\n", info.MaxConnections)

// 删除 Webhook（切回 Long Polling 前必须）
bot.DeleteWebhook(true) // true = 立即删除并丢弃待处理更新

// 验证 Webhook 是否可达
func verifyWebhook(bot *telebot.Bot) {
	info, err := bot.GetWebhookInfo()
	if err != nil {
		log.Printf("❌ 获取 Webhook 信息失败: %v", err)
		return
	}
	if info.LastErrorCode != 0 {
		log.Printf("⚠️ Webhook 错误: [%d] %s", info.LastErrorCode, info.LastErrorMessage)
	}
	if info.PendingUpdateCount > 100 {
		log.Printf("⚠️ 积压更新过多: %d", info.PendingUpdateCount)
	}
}
```

### 九、部署检查清单

```
□ 域名已解析到服务器公网 IP
□ SSL 证书已安装且未过期
□ nginx 配置已测试通过 (nginx -t)
□ 防火墙开放 443/80 端口
□ .env 文件权限为 600
□ systemd 服务已启用
□ 日志正常输出（journalctl -u telebot -f）
□ Webhook 状态正常（PendingUpdateCount < 10）
□ 健康检查端点返回 200
□ 数据库/Redis 连接正常
□ 定时备份脚本已配置
□ 监控告警已设置（CPU/内存/磁盘）
□ 自动更新证书已配置（certbot renew）
```

---

> **第八部分完**。下一部分将讲解 WebSocket 双向通信 + H5 管理界面。

---
# Go + telebot.v4 服务端完整教程（第九部分：WebSocket 通信 + H5 管理界面）

---

## 第九部分：WebSocket 双向通信 + H5 管理界面

这一章解决一个核心问题：**Bot 收到消息后，怎么实时推送到你的 Android 管理端 / 浏览器管理面板？** 答案就是 WebSocket。

### 一、为什么用 WebSocket

| 方案 | 优点 | 缺点 |
|---|---|---|
| **WebSocket** | 双向实时、低延迟、标准协议 | 需要维护长连接 |
| 轮询 REST API | 简单 | 延迟高、浪费请求 |
| SSE（单向推送） | 简单、走 HTTP | 只能服务端→客户端 |
| gRPC Stream | 高性能 | 浏览器不支持，需代理 |

WebSocket 是最优解：**浏览器原生支持、Android OkHttp 原生支持、Go 服务端一个库搞定**。

### 二、Go 服务端：gorilla/websocket

#### 2.1 安装

```bash
go get github.com/gorilla/websocket@latest
```

#### 2.2 核心结构设计

```go
// internal/ws/hub.go
// Hub 管理所有 WebSocket 连接
package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// ClientMessage 客户端→服务端消息
type ClientMessage struct {
	Type    string          `json:"type"` // "auth" | "send_message" | "broadcast" | "kick"
	Payload json.RawMessage `json:"payload"`
}

// ServerMessage 服务端→客户端消息
type ServerMessage struct {
	Type      string    `json:"type"` // "auth_ok" | "new_message" | "user_joined" | "error" | "pong"
	Timestamp time.Time `json:"timestamp"`
	Payload   any       `json:"payload,omitempty"`
}

// Client 单个连接
type Client struct {
	hub    *Hub
	conn   *websocket.Conn
	send   chan []byte
	userID string // 认证后的用户标识
	authed bool
}

// Hub 连接管理器
type Hub struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
	upgrader   websocket.Upgrader
}

// NewHub 创建 Hub
func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		upgrader: websocket.Upgrader{
			ReadBufferSize:  4096,
			WriteBufferSize: 4096,
			CheckOrigin: func(r *http.Request) bool {
				return true // 生产环境应检查 Origin
			},
		},
	}
}

// Run 启动 Hub 事件循环
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Printf("✅ WS 客户端连接: %s (在线: %d)", client.userID, h.Count())
			// 发送欢迎消息
			welcome := ServerMessage{
				Type:      "welcome",
				Timestamp: time.Now(),
				Payload: map[string]any{
					"message": "已连接到 Bot 管理服务器",
					"online":  h.Count(),
				},
			}
			data, _ := json.Marshal(welcome)
			client.send <- data

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
			}
			h.mu.Unlock()
			log.Printf("❌ WS 客户端断开: %s (在线: %d)", client.userID, h.Count())

		case message := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

// Count 在线客户端数量
func (h *Hub) Count() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}

// Broadcast 向所有客户端广播
func (h *Hub) Broadcast(msg ServerMessage) {
	data, err := json.Marshal(msg)
	if err != nil {
		log.Printf("❌ 序列化失败: %v", err)
		return
	}
	select {
	case h.broadcast <- data:
	default:
		log.Printf("⚠️ 广播队列满，丢弃消息")
	}
}

// SendToUser 向特定用户发送
func (h *Hub) SendToUser(userID string, msg ServerMessage) {
	data, _ := json.Marshal(msg)
	h.mu.RLock()
	defer h.mu.RUnlock()
	for client := range h.clients {
		if client.userID == userID && client.authed {
			select {
			case client.send <- data:
			default:
			}
		}
	}
}

// ServeWS HTTP 升级处理器
func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request) {
	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("❌ WS 升级失败: %v", err)
		return
	}
	client := &Client{
		hub:  h,
		conn: conn,
		send: make(chan []byte, 64),
	}
	client.hub.register <- client
	go client.writePump()
	go client.readPump()
}
```

#### 2.3 Client 读写协程

```go
// readPump 读取客户端消息
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(4096)
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, raw, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		var msg ClientMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			c.sendError("消息格式错误")
			continue
		}
		c.handleMessage(msg)
	}
}

// writePump 向客户端写消息
func (c *Client) writePump() {
	ticker := time.NewTicker(30 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				return
			}
		case <-ticker.C:
			// 心跳 ping
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
```

#### 2.4 消息处理与认证

```go
// handleMessage 处理客户端消息
func (c *Client) handleMessage(msg ClientMessage) {
	switch msg.Type {
	case "auth":
		var payload struct {
			Token string `json:"token"`
		}
		json.Unmarshal(msg.Payload, &payload)
		if payload.Token == "" {
			c.sendError("Token 不能为空")
			return
		}
		// 实际应调用 auth.ParseToken() 验证 JWT
		c.userID = payload.Token
		c.authed = true
		c.sendSuccess("auth_ok", map[string]any{"user_id": c.userID})
		log.Printf("🔐 客户端认证成功: %s", c.userID)

	case "send_message":
		if !c.authed {
			c.sendError("未认证")
			return
		}
		var payload struct {
			ChatID int64  `json:"chat_id"`
			Text   string `json:"text"`
		}
		json.Unmarshal(msg.Payload, &payload)
		// 通过 Bot 发送消息（需要 Bot 引用）
		c.hub.Broadcast(ServerMessage{
			Type:      "message_sent",
			Timestamp: time.Now(),
			Payload:   payload,
		})

	case "ping":
		c.send <- mustJSON(ServerMessage{
			Type:      "pong",
			Timestamp: time.Now(),
		})

	default:
		c.sendError(fmt.Sprintf("未知消息类型: %s", msg.Type))
	}
}

func (c *Client) sendError(msg string) {
	c.send <- mustJSON(ServerMessage{
		Type:      "error",
		Timestamp: time.Now(),
		Payload:   map[string]string{"message": msg},
	})
}

func (c *Client) sendSuccess(typ string, payload any) {
	c.send <- mustJSON(ServerMessage{
		Type:      typ,
		Timestamp: time.Now(),
		Payload:   payload,
	})
}

func mustJSON(v any) []byte {
	data, _ := json.Marshal(v)
	return data
}
```

### 三、与 telebot 集成

```go
// main.go（核心片段）
package main

import (
	"log"
	"net/http"
	"os"

	"gopkg.in/telebot.v4"
	"yourproject/internal/ws"
)

func main() {
	// 创建 Hub
	hub := ws.NewHub()
	go hub.Run()

	// 创建 Bot
	bot, err := telebot.NewBot(telebot.Settings{
		Token:  os.Getenv("TELEGRAM_BOT_TOKEN"),
		Poller: &telebot.LongPoller{Timeout: 10 * time.Second},
	})
	if err != nil {
		log.Fatal(err)
	}

	// Bot 收到消息 → 推送 WebSocket
	bot.Handle(telebot.OnText, func(c telebot.Context) error {
		msg := c.Message()
		hub.Broadcast(ws.ServerMessage{
			Type:      "new_message",
			Timestamp: time.Now(),
			Payload: map[string]any{
				"message_id": msg.ID,
				"chat_id":    msg.Chat.ID,
				"user_id":    msg.Sender.ID,
				"username":   msg.Sender.Username,
				"text":       msg.Text,
				"date":       msg.Time().Format(time.RFC3339),
			},
		})
		return nil
	})

	// 新用户加入群
	bot.Handle(telebot.OnAddedToGroup, func(c telebot.Context) error {
		hub.Broadcast(ws.ServerMessage{
			Type:      "bot_added_to_group",
			Timestamp: time.Now(),
			Payload: map[string]any{
				"chat_id": c.Chat().ID,
				"title":   c.Chat().Title,
				"members": c.Chat().MembersCount,
			},
		})
		return nil
	})

	// 注册 WebSocket 路由
	http.HandleFunc("/ws", hub.ServeWS)

	// 提供静态 H5 管理界面
	http.Handle("/", http.FileServer(http.Dir("./web/static")))

	// 启动 HTTP 服务
	go func() {
		addr := ":8080"
		log.Printf("🌐 HTTP 服务启动: http://localhost%s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Fatal(err)
		}
	}()

	// 启动 Bot
	log.Println("🤖 Bot 已启动，等待消息...")
	bot.Start()
}
```

### 四、JWT 鉴权

#### 4.1 生成与验证 Token

```go
// internal/auth/jwt.go
package auth

import (
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var jwtSecret = []byte(os.Getenv("JWT_SECRET"))

type Claims struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"`
	jwt.RegisteredClaims
}

// GenerateToken 生成 JWT
func GenerateToken(userID, username, role string) (string, error) {
	claims := Claims{
		UserID:   userID,
		Username: username,
		Role:     role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "telebot-server",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(jwtSecret)
}

// ParseToken 解析 JWT
func ParseToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (any, error) {
		return jwtSecret, nil
	})
	if err != nil {
		return nil, err
	}
	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}
	return nil, fmt.Errorf("无效 Token")
}
```

#### 4.2 WebSocket 连接时鉴权

```go
// 方式：连接时通过 URL 参数传 Token
// ws://localhost:8080/ws?token=eyJhbGciOiJIUzI1NiIs...

func (h *Hub) ServeWS(w http.ResponseWriter, r *http.Request) {
	tokenStr := r.URL.Query().Get("token")
	claims, err := auth.ParseToken(tokenStr)
	if err != nil {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	conn, err := h.upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	client := &Client{
		hub:    h,
		conn:   conn,
		send:   make(chan []byte, 64),
		userID: claims.UserID,
		authed: true,
	}
	client.hub.register <- client
	go client.writePump()
	go client.readPump()
}
```

### 五、H5 管理界面文件清单

```
web/static/
├── index.html          ← 登录页
├── dashboard.html      ← 管理面板
├── css/
│   └── style.css      ← 暗色主题样式
└── js/
    ├── ws-client.js    ← WebSocket 客户端封装
    ├── auth.js         ← 登录鉴权逻辑
    └── dashboard.js    ← 仪表盘交互逻辑
```

### 六、登录页 (index.html)

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bot 管理后台 - 登录</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body class="login-page">
    <div class="login-container">
        <div class="login-header">
            <h1>🤖 Bot Manager</h1>
            <p>Telegram Bot 管理后台</p>
        </div>
        <form class="login-form" id="loginForm">
            <div class="form-group">
                <label for="username">用户名</label>
                <input type="text" id="username" placeholder="请输入用户名" required>
            </div>
            <div class="form-group">
                <label for="password">密码</label>
                <input type="password" id="password" placeholder="请输入密码" required>
            </div>
            <button type="submit" class="btn btn-primary">登 录</button>
            <div class="error-msg" id="errorMsg"></div>
        </form>
    </div>
    <script src="js/auth.js"></script>
</body>
</html>
```

### 七、管理面板 (dashboard.html)

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bot 管理面板</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body class="dashboard-page">
    <aside class="sidebar">
        <div class="sidebar-header">
            <h2>🤖 Bot Manager</h2>
        </div>
        <nav class="sidebar-nav">
            <a href="#dashboard" class="nav-item active" data-tab="dashboard">
                <span class="icon">📊</span> 仪表盘
            </a>
            <a href="#messages" class="nav-item" data-tab="messages">
                <span class="icon">💬</span> 消息流
                <span class="badge" id="msgBadge">0</span>
            </a>
            <a href="#users" class="nav-item" data-tab="users">
                <span class="icon">👥</span> 用户管理
            </a>
            <a href="#broadcast" class="nav-item" data-tab="broadcast">
                <span class="icon">📢</span> 广播推送
            </a>
        </nav>
        <div class="sidebar-footer">
            <div class="user-info">
                <span class="avatar">👤</span>
                <span class="username" id="username">admin</span>
            </div>
            <button class="btn-logout" id="btnLogout">退出</button>
        </div>
    </aside>

    <main class="main-content">
        <header class="top-bar">
            <h1 id="pageTitle">仪表盘</h1>
            <div class="status-bar">
                <span class="status-dot" id="wsStatus"></span>
                <span id="wsStatusText">连接中...</span>
                <span class="online-count">在线: <span id="onlineCount">0</span></span>
            </div>
        </header>

        <section class="tab-content active" id="tab-dashboard">
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="stat-icon">💬</div>
                    <div class="stat-info">
                        <span class="stat-value" id="statMessages">0</span>
                        <span class="stat-label">今日消息</span>
                    </div>
                </div>
                <div class="stat-card">
                    <div class="stat-icon">👥</div>
                    <div class="stat-info">
                        <span class="stat-value" id="statUsers">0</span>
                        <span class="stat-label">总用户数</span>
                    </div>
                </div>
                <div class="stat-card">
                    <div class="stat-icon">📢</div>
                    <div class="stat-info">
                        <span class="stat-value" id="statBroadcasts">0</span>
                        <span class="stat-label">广播次数</span>
                    </div>
                </div>
            </div>
            <div class="message-stream">
                <h2>📨 实时消息流</h2>
                <div class="stream-container" id="messageStream">
                    <div class="empty-state">等待消息...</div>
                </div>
            </div>
        </section>

        <section class="tab-content" id="tab-broadcast">
            <div class="broadcast-panel">
                <h2>📢 发送广播</h2>
                <div class="form-group">
                    <label>目标</label>
                    <select id="broadcastTarget">
                        <option value="all">全部用户</option>
                        <option value="active">活跃用户（7天内）</option>
                        <option value="vip">VIP 用户</option>
                    </select>
                </div>
                <div class="form-group">
                    <label>消息内容</label>
                    <textarea id="broadcastText" rows="5" placeholder="输入要广播的内容..."></textarea>
                </div>
                <button class="btn btn-primary" id="btnBroadcast">发送广播</button>
                <div class="broadcast-result" id="broadcastResult"></div>
            </div>
        </section>
    </main>

    <script src="js/ws-client.js"></script>
    <script src="js/auth.js"></script>
    <script src="js/dashboard.js"></script>
</body>
</html>
```

### 八、暗色主题 CSS (style.css)

```css
:root {
    --bg-primary: #0f0f23;
    --bg-secondary: #1a1a2e;
    --bg-card: #16213e;
    --bg-hover: #1e2a4a;
    --text-primary: #eaeaea;
    --text-secondary: #a0a0b0;
    --accent: #6c5ce7;
    --accent-hover: #7d6ff0;
    --success: #00b894;
    --warning: #fdcb6e;
    --danger: #e74c3c;
    --border: #2a2a4a;
    --shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

* { margin: 0; padding: 0; box-sizing: border-box; }

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: var(--bg-primary);
    color: var(--text-primary);
    min-height: 100vh;
    line-height: 1.6;
}

/* 登录页 */
.login-page {
    display: flex; align-items: center; justify-content: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 50%, #16213e 100%);
}
.login-container {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 48px;
    width: 100%;
    max-width: 420px;
    box-shadow: var(--shadow);
}
.login-header { text-align: center; margin-bottom: 32px; }
.login-header h1 { font-size: 28px; color: var(--accent); }

.form-group { margin-bottom: 20px; }
.form-group label {
    display: block; margin-bottom: 6px;
    color: var(--text-secondary); font-size: 14px;
}
.form-group input,
.form-group select,
.form-group textarea {
    width: 100%; padding: 12px 16px;
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-primary); font-size: 15px;
    transition: border-color 0.2s;
}
.form-group input:focus,
.form-group select:focus,
.form-group textarea:focus {
    outline: none; border-color: var(--accent);
}

.btn {
    display: inline-block; padding: 12px 24px;
    border: none; border-radius: 8px;
    font-size: 15px; font-weight: 600;
    cursor: pointer; transition: all 0.2s;
}
.btn-primary { background: var(--accent); color: white; width: 100%; }
.btn-primary:hover { background: var(--accent-hover); transform: translateY(-1px); }

.error-msg {
    color: var(--danger); font-size: 14px;
    margin-top: 12px; text-align: center; min-height: 20px;
}

/* 管理面板 */
.dashboard-page { display: flex; min-height: 100vh; }
.sidebar {
    width: 260px; background: var(--bg-secondary);
    border-right: 1px solid var(--border);
    display: flex; flex-direction: column;
    position: fixed; top: 0; left: 0; bottom: 0;
    overflow-y: auto;
}
.sidebar-header { padding: 24px; border-bottom: 1px solid var(--border); }
.sidebar-header h2 { color: var(--accent); font-size: 20px; }
.sidebar-nav { flex: 1; padding: 16px 12px; }
.nav-item {
    display: flex; align-items: center;
    padding: 12px 16px;
    color: var(--text-secondary);
    text-decoration: none;
    border-radius: 8px;
    margin-bottom: 4px;
    transition: all 0.2s;
}
.nav-item:hover { background: var(--bg-hover); color: var(--text-primary); }
.nav-item.active { background: var(--accent); color: white; }
.nav-item .icon { margin-right: 12px; font-size: 18px; }
.nav-item .badge {
    margin-left: auto; background: var(--danger);
    color: white; font-size: 12px;
    padding: 2px 8px; border-radius: 10px; display: none;
}
.sidebar-footer {
    padding: 16px 20px; border-top: 1px solid var(--border);
    display: flex; align-items: center; justify-content: space-between;
}
.btn-logout {
    background: none; border: 1px solid var(--border);
    color: var(--text-secondary);
    padding: 6px 12px; border-radius: 6px; cursor: pointer;
}
.btn-logout:hover { border-color: var(--danger); color: var(--danger); }

/* 主内容 */
.main-content { margin-left: 260px; flex: 1; padding: 0; }
.top-bar {
    display: flex; align-items: center; justify-content: space-between;
    padding: 20px 32px;
    background: var(--bg-secondary);
    border-bottom: 1px solid var(--border);
    position: sticky; top: 0; z-index: 100;
}
.top-bar h1 { font-size: 22px; }
.status-bar {
    display: flex; align-items: center; gap: 12px;
    font-size: 14px; color: var(--text-secondary);
}
.status-dot {
    width: 8px; height: 8px; border-radius: 50%;
    background: var(--warning); animation: pulse 2s infinite;
}
.status-dot.connected { background: var(--success); }
.status-dot.disconnected { background: var(--danger); }
@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }

/* 统计卡片 */
.tab-content { display: none; padding: 32px; }
.tab-content.active { display: block; }
.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
    gap: 20px; margin-bottom: 32px;
}
.stat-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 24px;
    display: flex; align-items: center; gap: 16px;
    transition: transform 0.2s;
}
.stat-card:hover { transform: translateY(-2px); box-shadow: var(--shadow); }
.stat-icon {
    font-size: 32px; width: 56px; height: 56px;
    display: flex; align-items: center; justify-content: center;
    background: var(--bg-hover); border-radius: 12px;
}
.stat-value { display: block; font-size: 28px; font-weight: 700; }
.stat-label { font-size: 13px; color: var(--text-secondary); }

/* 消息流 */
.message-stream {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px; padding: 24px;
}
.message-stream h2 { margin-bottom: 16px; font-size: 18px; }
.stream-container { max-height: 500px; overflow-y: auto; }
.msg-item {
    padding: 12px 16px;
    border-bottom: 1px solid var(--border);
    display: flex; gap: 12px; align-items: flex-start;
}
.msg-item:last-child { border-bottom: none; }
.msg-avatar {
    width: 36px; height: 36px; border-radius: 50%;
    background: var(--accent);
    display: flex; align-items: center; justify-content: center;
    font-size: 16px; flex-shrink: 0;
}
.msg-body { flex: 1; }
.msg-header { display: flex; justify-content: space-between; margin-bottom: 4px; }
.msg-name { font-weight: 600; }
.msg-time { font-size: 12px; color: var(--text-secondary); }
.msg-text { color: var(--text-secondary); font-size: 14px; word-break: break-word; }

/* 广播面板 */
.broadcast-panel {
    max-width: 600px;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px; padding: 32px;
}
.broadcast-panel h2 { margin-bottom: 24px; }
.broadcast-result {
    margin-top: 16px; padding: 12px;
    border-radius: 8px; display: none;
}
.broadcast-result.success {
    display: block;
    background: rgba(0, 184, 148, 0.1);
    color: var(--success);
    border: 1px solid var(--success);
}
.broadcast-result.error {
    display: block;
    background: rgba(231, 76, 60, 0.1);
    color: var(--danger);
    border: 1px solid var(--danger);
}

.empty-state { text-align: center; padding: 48px; color: var(--text-secondary); font-size: 15px; }
```

### 九、WebSocket 客户端 (ws-client.js)

```javascript
// js/ws-client.js
class WSClient {
    constructor() {
        this.ws = null;
        this.token = localStorage.getItem('token');
        this.reconnectAttempts = 0;
        this.maxReconnectDelay = 30000;
        this.handlers = {};
        this.onCloseCallbacks = [];
    }

    connect() {
        if (!this.token) {
            console.error('❌ 无 Token，跳转到登录页');
            window.location.href = '/index.html';
            return;
        }
        const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
        const url = `${protocol}//${location.host}/ws?token=${encodeURIComponent(this.token)}`;
        console.log('🔌 连接 WebSocket:', url);
        this.ws = new WebSocket(url);

        this.ws.onopen = () => {
            console.log('✅ WebSocket 已连接');
            this.reconnectAttempts = 0;
            this.updateStatus('connected', '已连接');
        };

        this.ws.onmessage = (event) => {
            try {
                const msg = JSON.parse(event.data);
                this.dispatch(msg);
            } catch (e) {
                console.error('❌ 消息解析失败:', e);
            }
        };

        this.ws.onclose = () => {
            console.log('❌ WebSocket 断开');
            this.updateStatus('disconnected', '已断开');
            this.onCloseCallbacks.forEach(cb => cb());
            this.reconnect();
        };

        this.ws.onerror = (err) => {
            console.error('❌ WebSocket 错误:', err);
        };
    }

    reconnect() {
        if (this.reconnectAttempts >= 10) {
            console.error('❌ 重连次数过多，停止重试');
            this.updateStatus('disconnected', '连接失败');
            return;
        }
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), this.maxReconnectDelay);
        this.reconnectAttempts++;
        console.log(`🔄 ${delay}ms 后尝试重连 (第 ${this.reconnectAttempts} 次)...`);
        this.updateStatus('reconnecting', `重连中... (${this.reconnectAttempts}/10)`);
        setTimeout(() => this.connect(), delay);
    }

    send(type, payload) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify({ type, payload }));
        }
    }

    on(type, handler) {
        if (!this.handlers[type]) this.handlers[type] = [];
        this.handlers[type].push(handler);
    }

    dispatch(msg) {
        const handlers = this.handlers[msg.type] || [];
        handlers.forEach(h => h(msg.payload, msg));
        const allHandlers = this.handlers['*'] || [];
        allHandlers.forEach(h => h(msg));
    }

    updateStatus(state, text) {
        const dot = document.getElementById('wsStatus');
        const textEl = document.getElementById('wsStatusText');
        if (dot) dot.className = `status-dot ${state}`;
        if (textEl) textEl.textContent = text;
    }

    close() {
        if (this.ws) this.ws.close();
    }
}

window.wsClient = new WSClient();
```

### 十、仪表盘逻辑 (dashboard.js)

```javascript
// js/dashboard.js
document.addEventListener('DOMContentLoaded', () => {
    const token = localStorage.getItem('token');
    const username = localStorage.getItem('username');
    if (!token) { window.location.href = '/index.html'; return; }

    const userEl = document.getElementById('username');
    if (userEl && username) userEl.textContent = username;

    wsClient.connect();

    let stats = { messages: 0, users: new Set(), broadcasts: 0 };

    wsClient.on('new_message', (payload) => {
        stats.messages++;
        stats.users.add(payload.user_id);
        document.getElementById('statMessages').textContent = stats.messages;
        document.getElementById('statUsers').textContent = stats.users.size;
        appendMessage(payload);
        updateBadge(stats.messages);
    });

    wsClient.on('welcome', (payload) => {
        console.log('🎉', payload.message, '| 在线:', payload.online);
        document.getElementById('onlineCount').textContent = payload.online;
    });

    wsClient.on('error', (payload) => {
        console.error('⚠️ 服务器错误:', payload.message);
        showToast(payload.message, 'error');
    });

    document.getElementById('btnBroadcast').addEventListener('click', () => {
        const text = document.getElementById('broadcastText').value.trim();
        const target = document.getElementById('broadcastTarget').value;
        if (!text) { showResult('请输入广播内容', 'error'); return; }
        wsClient.send('broadcast', { text, target });
        stats.broadcasts++;
        document.getElementById('statBroadcasts').textContent = stats.broadcasts;
        document.getElementById('broadcastText').value = '';
        showResult('广播已发送!', 'success');
    });

    document.getElementById('btnLogout').addEventListener('click', () => {
        localStorage.removeItem('token');
        localStorage.removeItem('username');
        wsClient.close();
        window.location.href = '/index.html';
    });

    // Tab 切换
    document.querySelectorAll('.nav-item[data-tab]').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const tab = item.dataset.tab;
            document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
            item.classList.add('active');
            document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
            document.getElementById(`tab-${tab}`).classList.add('active');
            const titles = { dashboard: '仪表盘', messages: '消息流', users: '用户管理', broadcast: '广播推送' };
            document.getElementById('pageTitle').textContent = titles[tab] || '';
            if (tab === 'messages') {
                const badge = document.getElementById('msgBadge');
                badge.style.display = 'none';
                badge.textContent = '0';
            }
        });
    });

    // 心跳
    setInterval(() => {
        if (wsClient.ws && wsClient.ws.readyState === WebSocket.OPEN) {
            wsClient.send('ping', { time: Date.now() });
        }
    }, 25000);
});

function appendMessage(payload) {
    const container = document.getElementById('messageStream');
    const empty = container.querySelector('.empty-state');
    if (empty) empty.remove();
    const el = document.createElement('div');
    el.className = 'msg-item';
    const name = payload.username || 'unknown';
    const time = new Date(payload.date).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
    el.innerHTML =
        '<div class="msg-avatar">' + name.charAt(0).toUpperCase() + '</div>' +
        '<div class="msg-body">' +
            '<div class="msg-header"><span class="msg-name">@' + name + '</span><span class="msg-time">' + time + '</span></div>' +
            '<div class="msg-text">' + escapeHtml(payload.text || '') + '</div>' +
        '</div>';
    container.prepend(el);
    while (container.children.length > 100) container.removeChild(container.lastChild);
}

function updateBadge(count) {
    const badge = document.getElementById('msgBadge');
    if (!badge) return;
    badge.textContent = count > 99 ? '99+' : count;
    badge.style.display = count > 0 ? 'inline-block' : 'none';
}

function showResult(text, type) {
    const el = document.getElementById('broadcastResult');
    el.textContent = text;
    el.className = 'broadcast-result ' + type;
    setTimeout(() => { el.className = 'broadcast-result'; }, 3000);
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}
```

### 十一、登录鉴权 (auth.js)

```javascript
// js/auth.js
document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('loginForm');
    const errorEl = document.getElementById('errorMsg');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();
        const username = document.getElementById('username').value.trim();
        const password = document.getElementById('password').value;
        if (!username || !password) { showError('请输入用户名和密码'); return; }

        try {
            const resp = await fetch('/api/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
            });
            const data = await resp.json();
            if (!resp.ok) { showError(data.error || '登录失败'); return; }
            localStorage.setItem('token', data.token);
            localStorage.setItem('username', data.username);
            window.location.href = '/dashboard.html';
        } catch (err) {
            showError('网络错误: ' + err.message);
        }
    });

    function showError(msg) { errorEl.textContent = msg; }
});
```

### 十二、完整项目结构

```
project/
├── main.go
├── go.mod
├── go.sum
├── config/
│   └── config.go
├── internal/
│   ├── bot/
│   │   ├── bot.go
│   │   ├── handlers.go
│   │   └── middleware.go
│   ├── ws/
│   │   ├── hub.go
│   │   └── client.go
│   ├── auth/
│   │   └── jwt.go
│   ├── api/
│   │   ├── login.go
│   │   └── broadcast.go
│   └── store/
│       └── user.go
├── web/
│   └── static/
│       ├── index.html
│       ├── dashboard.html
│       ├── css/style.css
│       └── js/
│           ├── ws-client.js
│           ├── auth.js
│           └── dashboard.js
└── Dockerfile
```

---

> **第九部分完**。下一部分将讲解完整项目结构、Docker 部署与运维监控。

---
# Go + telebot.v4 服务端完整教程（第十部分：项目工程化 + 附录）---

## 第十部分：完整项目结构、部署与运维

### 一、完整项目目录结构

```
telebot-server/
├── main.go                    # 入口：初始化并启动所有服务
├── go.mod
├── go.sum
├── Makefile                   # 常用命令快捷方式
├── Dockerfile
├── docker-compose.yml
├── .env.example               # 环境变量模板
├── config/
│   └── config.go              # 配置加载（环境变量 + .env）
├── internal/
│   ├── bot/
│   │   ├── bot.go             # telebot 初始化与注册
│   │   ├── handlers.go        # 所有消息处理器
│   │   ├── middleware.go      # 中间件（日志/限流/鉴权）
│   │   └── commands.go        # 命令注册与解析
│   ├── ws/
│   │   ├── hub.go             # WebSocket Hub（连接管理）
│   │   └── client.go          # Client 读写协程
│   ├── auth/
│   │   └── jwt.go             # JWT 生成与验证
│   ├── api/
│   │   ├── router.go          # HTTP 路由注册
│   │   ├── login.go           # POST /api/login
│   │   ├── broadcast.go       # POST /api/broadcast
│   │   └── stats.go           # GET  /api/stats
│   ├── store/
│   │   ├── user.go            # 用户 CRUD
│   │   ├── message.go         # 消息持久化
│   │   └── redis.go           # Redis 连接池
│   ├── service/
│   │   ├── file_manager.go    # 文件下载/缓存
│   │   ├── stats.go           # 统计数据聚合
│   │   └── scheduler.go       # 定时任务（清理/心跳）
│   └── model/
│       ├── user.go             # User 结构体
│       └── message.go          # Message 结构体
├── web/
│   └── static/
│       ├── index.html          # 登录页
│       ├── dashboard.html      # 管理面板
│       ├── css/style.css      # 暗色主题
│       └── js/
│           ├── ws-client.js    # WebSocket 客户端
│           ├── auth.js         # 登录逻辑
│           └── dashboard.js    # 仪表盘逻辑
├── scripts/
│   ├── deploy.sh              # 部署脚本
│   └── backup.sh              # 数据库备份
└── docs/
    └── api.md                 # API 文档
```

### 二、main.go 完整示例

```go
// main.go
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"telebot-server/config"
	"telebot-server/internal/api"
	"telebot-server/internal/auth"
	"telebot-server/internal/bot"
	"telebot-server/internal/store"
	"telebot-server/internal/ws"
)

func main() {
	// 加载配置
	cfg := config.Load()

	// 初始化存储
	db := store.Init(cfg.DatabaseURL)
	redis := store.InitRedis(cfg.RedisURL)

	// 初始化 JWT
	auth.Init(cfg.JWTSecret)

	// 创建 WebSocket Hub
	hub := ws.NewHub(redis)
	go hub.Run()

	// 创建并启动 Bot
	botInstance, err := bot.New(cfg.TelegramToken, hub, db)
	if err != nil {
		log.Fatalf("❌ Bot 初始化失败: %v", err)
	}
	go botInstance.Start()

	// 注册 HTTP 路由
	router := api.NewRouter(hub, db, cfg)
	http.Handle("/", router)

	// 启动 HTTP 服务
	addr := cfg.HTTPAddr
	server := &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("🌐 HTTP 服务启动: http://localhost%s", addr)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("❌ HTTP 服务异常: %v", err)
		}
	}()

	// 优雅退出
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("🛑 正在关闭服务...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	server.Shutdown(ctx)
	botInstance.Stop()
	db.Close()
	redis.Close()

	log.Println("✅ 服务已安全关闭")
}
```

### 三、配置管理

```go
// config/config.go
package config

import (
	"encoding/json"
	"os"
)

type Config struct {
	TelegramToken string `json:"telegram_token"`
	HTTPAddr      string `json:"http_addr"`
	JWTSecret     string `json:"jwt_secret"`
	DatabaseURL   string `json:"database_url"`
	RedisURL      string `json:"redis_url"`
	Env           string `json:"env"` // development | production
	LogLevel      string `json:"log_level"`
}

func Load() *Config {
	// 尝试从环境变量读取
	cfg := &Config{
		TelegramToken: getEnv("TELEGRAM_BOT_TOKEN", ""),
		HTTPAddr:      getEnv("HTTP_ADDR", ":8080"),
		JWTSecret:     getEnv("JWT_SECRET", "change-me-in-production"),
		DatabaseURL:   getEnv("DATABASE_URL", "sqlite://./data.db"),
		RedisURL:      getEnv("REDIS_URL", "redis://localhost:6379/0"),
		Env:           getEnv("APP_ENV", "development"),
		LogLevel:      getEnv("LOG_LEVEL", "info"),
	}

	// 从 .env 文件覆盖（如果存在）
	if data, err := os.ReadFile(".env"); err == nil {
		// 简单解析 KEY=VALUE
		parseEnvFile(data, cfg)
	}

	// 验证必填项
	if cfg.TelegramToken == "" {
		logFatal("TELEGRAM_BOT_TOKEN 未设置")
	}
	if cfg.JWTSecret == "change-me-in-production" && cfg.Env == "production" {
		logFatal("生产环境必须设置 JWT_SECRET")
	}

	return cfg
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
```

### 四、Makefile

```makefile
# Makefile
BINARY=bin/server
MIGRATIONS=./migrations

.PHONY: run build test clean docker-up docker-down lint fmt

# 开发模式运行
run:
	go run main.go

# 编译
build:
	mkdir -p bin
	CGO_ENABLED=0 go build -o $(BINARY) main.go

# 测试
test:
	go test -v -race -cover ./...

# 代码检查
lint:
	golangci-lint run ./...

# 格式化
fmt:
	go fmt ./...

# Docker 启动
docker-up:
	docker-compose up -d --build

# Docker 停止
docker-down:
	docker-compose down

# 清理
clean:
	rm -rf bin/

# 数据库迁移
migrate-up:
	goose -dir $(MIGRATIONS) postgres "$(DATABASE_URL)" up

migrate-down:
	goose -dir $(MIGRATIONS) postgres "$(DATABASE_URL)" down

# 查看日志
logs:
	docker-compose logs -f bot-server
```

### 五、Docker 部署

#### 5.1 Dockerfile（多阶段构建）

```dockerfile
# ---- 构建阶段 ----
FROM golang:1.22-alpine AS builder

WORKDIR /build
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server main.go

# ---- 运行阶段 ----
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata curl
ENV TZ=Asia/Shanghai
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime

WORKDIR /app
COPY --from=builder /build/server .
COPY --from=builder /build/web ./web

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["./server"]
```

#### 5.2 docker-compose.yml

```yaml
version: "3.9"

services:
  bot-server:
    build: .
    container_name: telebot-server
    restart: unless-stopped
    ports:
      - "8080:8080"
    env_file:
      - .env
    environment:
      - APP_ENV=production
    depends_on:
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy
    networks:
      - bot-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
    networks:
      - bot-net

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: telebot
      POSTGRES_USER: telebot
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U telebot"]
      interval: 10s
      timeout: 3s
    networks:
      - bot-net

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - bot-server
    networks:
      - bot-net

volumes:
  redis_data:
  pg_data:

networks:
  bot-net:
    driver: bridge
```

#### 5.3 nginx 配置

```nginx
# nginx.conf
upstream bot_backend {
    server bot-server:8080;
    keepalive 32;
}

# HTTP → HTTPS 重定向
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$host$request_uri;
}

# HTTPS 主服务
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    client_max_body_size 50m;

    # WebSocket 升级
    location /ws {
        proxy_pass http://bot_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400s;  # WebSocket 长连接
        proxy_send_timeout 86400s;
    }

    # 静态文件
    location / {
        proxy_pass http://bot_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 健康检查
    location /health {
        access_log off;
        proxy_pass http://bot_backend;
    }
}
```

### 六、健康检查与监控

```go
// internal/api/health.go
package api

import (
	"encoding/json"
	"net/http"
	"runtime"
	"time"

	"telebot-server/internal/store"
	"telebot-server/internal/ws"
)

type HealthResponse struct {
	Status    string            `json:"status"`
	Uptime    string            `json:"uptime"`
	Time      time.Time         `json:"time"`
	Version   string            `json:"version"`
	GoVersion string            `json:"go_version"`
	Memory    runtime.MemStats  `json:"memory"`
	Services  map[string]string `json:"services"`
}

var startTime = time.Now()

func HealthCheck(hub *ws.Hub, db *store.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)

		services := map[string]string{
			"bot":      "ok",
			"websocket": "ok",
			"database": "ok",
			"redis":    "ok",
		}

		// 检查数据库连接
		if err := db.Ping(); err != nil {
			services["database"] = "error: " + err.Error()
		}

		// 检查 Redis
		if err := db.RedisPing(); err != nil {
			services["redis"] = "error: " + err.Error()
		}

		resp := HealthResponse{
			Status:    "healthy",
			Uptime:    time.Since(startTime).Round(time.Second).String(),
			Time:      time.Now(),
			Version:   "1.0.0",
			GoVersion: runtime.Version(),
			Memory:    m,
			Services:  services,
		}

		// 如果有服务异常，返回 503
		allOk := true
		for _, v := range services {
			if v != "ok" {
				allOk = false
				break
			}
		}
		if !allOk {
			w.WriteHeader(http.StatusServiceUnavailable)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
```

### 七、日志系统

```go
// internal/logger/logger.go
package logger

import (
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var (
	L     *zap.SugaredLogger
	once  sync.Once
)

func Init(env string) {
	once.Do(func() {
		var cfg zap.Config
		if env == "production" {
			cfg = zap.NewProductionConfig()
			cfg.EncoderConfig.TimeKey = "timestamp"
			cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
		} else {
			cfg = zap.NewDevelopmentConfig()
			cfg.EncoderConfig.EncodeLevel = zapcore.CapitalColorLevelEncoder
		}

		// 同时输出到文件和 stdout
		cfg.OutputPaths = []string{
			"stdout",
			filepath.Join("logs", time.Now().Format("2006-01-02")+".log"),
		}

		logger, err := cfg.Build()
		if err != nil {
			log.Fatalf("初始化日志失败: %v", err)
		}

		L = logger.Sugar()
		L.Info("📝 日志系统已初始化")
	})
}

func Sync() {
	if L != nil {
		L.Sync()
	}
}
```

### 八、CI/CD（GitHub Actions）

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: "1.22"
      - run: go test -v -race -cover ./...
      - run: golangci-lint run ./...

  build-and-push:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: |
          docker build -t ghcr.io/${{ github.repository }}:${{ github.sha }} .
          docker tag ghcr.io/${{ github.repository }}:${{ github.sha }} \
                     ghcr.io/${{ github.repository }}:latest
      - name: Push to GHCR
        run: |
          echo ${{ secrets.GHCR_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker push ghcr.io/${{ github.repository }}:latest

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: SSH deploy
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_KEY }}
          source: "docker-compose.yml,.env,nginx.conf"
          target: "/opt/telebot-server"
      - name: Restart services
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SERVER_HOST }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/telebot-server
            docker compose pull
            docker compose up -d
            docker system prune -f
```

---

## 附录 A：telebot.v4 API 速查表

### A.1 Bot 方法

| 方法 | 签名 | 说明 |
|---|---|---|
| `NewBot` | `func NewBot(settings Settings) (*Bot, error)` | 创建 Bot 实例 |
| `Start` | `func (b *Bot) Start()` | 开始轮询（阻塞） |
| `Stop` | `func (b *Bot) Stop()` | 优雅停止 |
| `Send` | `func (b *Bot) Send(to Recipient, what any, opts ...any) (*Message, error)` | 发送消息 |
| `SendAlbum` | `func (b *Bot) SendAlbum(to Recipient, album Album, opts ...any) ([]*Message, error)` | 发送媒体组 |
| `Edit` | `func (b *Bot) Edit(msg Editable, what any, opts ...any) (*Message, error)` | 编辑消息 |
| `Delete` | `func (b *Bot) Delete(msg Editable) error` | 删除消息 |
| `Forward` | `func (b *Bot) Forward(to Recipient, msg Editable, opts ...any) (*Message, error)` | 转发消息 |
| `Copy` | `func (b *Bot) Copy(to Recipient, msg Editable, opts ...any) (*Message, error)` | 复制消息 |
| `Reply` | `func (b *Bot) Reply(msg Editable, what any, opts ...any) (*Message, error)` | 回复消息 |
| `Ban` | `func (b *Bot) Ban(chat ChatID, user User, duration ...time.Duration) error` | 封禁用户 |
| `Unban` | `func (b *Bot) Unban(chat ChatID, user User) error` | 解封用户 |
| `Kick` | `func (b *Bot) Kick(chat ChatID, user User) error` | 踢出用户 |
| `Restrict` | `func (b *Bot) Restrict(chat ChatID, user User, rights Rights, duration ...time.Duration) error` | 限制权限 |
| `Promote` | `func (b *Bot) Promote(chat ChatID, user User, rights Rights) error` | 提升权限 |
| `GetChat` | `func (b *Bot) GetChat(id ChatID) (*Chat, error)` | 获取聊天信息 |
| `GetMembersCount` | `func (b *Bot) GetMembersCount(chat ChatID) (int, error)` | 获取成员数 |
| `GetMember` | `func (b *Bot) GetMember(chat ChatID, user User) (*Member, error)` | 获取成员信息 |
| `SetCommands` | `func (b *Bot) SetCommands(commands ...Command) error` | 设置命令列表 |
| `GetCommands` | `func (b *Bot) GetCommands() ([]Command, error)` | 获取命令列表 |
| `FileByID` | `func (b *Bot) FileByID(fileID string) (File, error)` | 获取文件信息 |
| `Download` | `func (b *Bot) Download(file File, dst io.Writer) error` | 下载文件 |
| `GetFileURL` | `func (b *Bot) GetFileURL(file File) string` | 获取文件直链 |
| `SetWebhook` | `func (b *Bot) SetWebhook(webhook *Webhook) error` | 设置 Webhook |
| `DeleteWebhook` | `func (b *Bot) DeleteWebhook(drop ...bool) error` | 删除 Webhook |
| `GetWebhookInfo` | `func (b *Bot) GetWebhookInfo() (*WebhookInfo, error)` | 获取 Webhook 信息 |
| `GetMe` | `func (b *Bot) GetMe() (*User, error)` | 获取 Bot 自身信息 |
| `SendPoll` | `func (b *Bot) SendPoll(to Recipient, poll *Poll, opts ...any) (*Message, error)` | 发送投票 |
| `StopPoll` | `func (b *Bot) StopPoll(msg Editable) (*Poll, error)` | 停止投票 |
| `Pin` | `func (b *Bot) Pin(msg Editable, opts ...any) error` | 置顶消息 |
| `Unpin` | `func (b *Bot) Unpin(msg Editable) error` | 取消置顶 |
| `UnpinAll` | `func (b *Bot) UnpinAll(chat ChatID) error` | 取消所有置顶 |
| `Leave` | `func (b *Bot) Leave(chat ChatID) error` | 离开群组 |
| `Close` | `func (b *Bot) Close()` | 关闭 Bot（释放资源） |

### A.2 Handler 事件常量

| 常量 | 触发条件 |
|---|---|
| `OnText` | 收到纯文本消息 |
| `OnPhoto` | 收到图片 |
| `OnVideo` | 收到视频 |
| `OnAudio` | 收到音频 |
| `OnVoice` | 收到语音消息 |
| `OnDocument` | 收到文件 |
| `OnSticker` | 收到贴纸 |
| `OnLocation` | 收到位置信息 |
| `OnContact` | 收到联系人 |
| `OnAnimation` | 收到 GIF/动画 |
| `OnMediaGroup` | 收到媒体组 |
| `OnCallback` | 收到回调查询 |
| `OnQuery` | 收到内联查询 |
| `OnChosenInlineResult` | 用户选择了内联结果 |
| `OnNewChatMembers` | 新成员加入群 |
| `OnLeftChatMember` | 成员离开群 |
| `OnNewChatTitle` | 群标题变更 |
| `OnNewChatPhoto` | 群头像变更 |
| `OnDeleteChatPhoto` | 群头像被删 |
| `OnGroupCreated` | 群组创建 |
| `OnPinnedMessage` | 消息被置顶 |
| `OnChannelPost` | 频道帖子 |
| `OnEditedChannelPost` | 频道帖子被编辑 |
| `OnEditedMessage` | 消息被编辑 |
| `OnMyChatMember` | Bot 自身成员状态变更 |
| `OnChatMember` | 群成员状态变更 |
| `OnPoll` | 收到投票 |
| `OnPollAnswer` | 投票被回答 |
| `OnInvoice` | 收到发票 |
| `OnPreCheckout` | 预结账查询 |
| `OnShippingQuery` | 运费查询 |
| `OnAddedToGroup` | Bot 被加入群组 |
| `OnRemovedFromGroup` | Bot 被移出群组 |
| `OnVideoNote` | 收到视频笔记 |
| `OnDice` | 收到骰子消息 |

### A.3 Context 方法

| 方法 | 说明 |
|---|---|
| `Message()` | 获取当前消息 |
| `Sender()` | 获取发送者 |
| `Chat()` | 获取聊天 |
| `Text()` | 获取消息文本 |
| `Args()` | 获取命令参数（不含命令本身）|
| `Arg(n)` | 获取第 n 个参数 |
| `Data()` | 获取 Callback 数据 |
| `Send(what, opts...)` | 发送消息到当前聊天 |
| `Reply(what, opts...)` | 回复当前消息 |
| `Edit(what, opts...)` | 编辑当前消息 |
| `Delete()` | 删除当前消息 |
| `Ban(duration)` | 封禁发送者 |
| `Kick()` | 踢出发送者 |
| `Answer(text, opts...)` | 回复文本（快捷方式）|
| `Respond(opts...)` | 响应回调查询 |
| `Notify(text, opts...)` | 发送通知 |
| `Prompt(text, handler)` | 等待用户下一条消息 |
| `Next(handler)` | 注册下一条消息处理器 |
| `State()` | 获取 FSM 状态 |
| `Set(state)` | 设置 FSM 状态 |
| `Reset()` | 重置 FSM 状态 |
| `Get(key)` | 获取 FSM 数据 |
| `SetData(key, val)` | 设置 FSM 数据 |

### A.4 辅助函数

| 函数 | 说明 |
|---|---|
| `telebot.FromURL(url)` | 从 URL 创建 File |
| `telebot.FromDisk(path)` | 从磁盘创建 File |
| `telebot.FromReader(r)` | 从 Reader 创建 File |
| `telebot.FromBytes(b)` | 从字节数组创建 File |
| `telebot.ParseModeMarkdown` | Markdown 解析模式 |
| `telebot.ParseModeHTML` | HTML 解析模式 |

---

## 附录 B：完整命令注册示例

```go
// internal/bot/commands.go
package bot

import (
	"fmt"
	"strings"
	"time"

	"gopkg.in/telebot.v4"
)

func (b *Bot) registerCommands() {
	// 设置 Bot 命令菜单（用户在输入框输入 / 时显示）
	b.t.SetCommands(
		telebot.Command{Text: "start", Description: "开始使用"},
		telebot.Command{Text: "help", Description: "查看帮助"},
		telebot.Command{Text: "settings", Description: "个人设置"},
		telebot.Command{Text: "stats", Description: "查看统计"},
		telebot.Command{Text: "broadcast", Description: "广播（管理员）"},
		telebot.Command{Text: "ban", Description: "封禁用户（管理员）"},
		telebot.Command{Text: "unban", Description: "解封用户（管理员）"},
		telebot.Command{Text: "kick", Description: "踢出用户（管理员）"},
		telebot.Command{Text: "pin", Description: "置顶消息（管理员）"},
		telebot.Command{Text: "unpin", Description: "取消置顶（管理员）"},
		telebot.Command{Text: "poll", Description: "发起投票（管理员）"},
		telebot.Command{Text: "cancel", Description: "取消当前操作"},
	)

	// /start
	b.t.Handle("/start", b.onStart)
	b.t.Handle("/start <code>", b.onStartWithCode) // 带参数的 start

	// /help
	b.t.Handle("/help", b.onHelp)

	// /settings
	b.t.Handle("/settings", b.onSettings)

	// /stats
	b.t.Handle("/stats", b.onStats)

	// /broadcast（管理员）
	b.t.Handle("/broadcast", b.adminOnly(b.onBroadcast))

	// /ban <user_id> [reason]
	b.t.Handle("/ban", b.adminOnly(b.onBan))

	// /unban <user_id>
	b.t.Handle("/unban", b.adminOnly(b.onUnban))

	// /kick <user_id>
	b.t.Handle("/kick", b.adminOnly(b.onKick))

	// /pin
	b.t.Handle("/pin", b.adminOnly(b.onPin))

	// /unpin
	b.t.Handle("/unpin", b.adminOnly(b.onUnpin))

	// /poll "问题" "选项1" "选项2" ...
	b.t.Handle("/poll", b.adminOnly(b.onPoll))

	// /cancel
	b.t.Handle("/cancel", b.onCancel)
}

func (b *Bot) onStart(c telebot.Context) error {
	user := c.Sender()
	return c.Send(fmt.Sprintf(
		"👋 你好，%s！\n\n欢迎使用本机器人。\n输入 /help 查看可用命令。",
		user.FirstName,
	), &telebot.SendOptions{
		ParseMode: telebot.ParseModeMarkdown,
	})
}

func (b *Bot) onHelp(c telebot.Context) error {
	helpText := `
📖 *可用命令*

/start - 开始使用
/help - 显示此帮助
/settings - 个人设置
/stats - 查看统计

🔒 *管理员命令*
/broadcast - 广播消息
/ban <id> - 封禁用户
/unban <id> - 解封用户
/kick <id> - 踢出用户
/pin - 置顶消息
/poll - 发起投票
`
	return c.Send(helpText, &telebot.SendOptions{
		ParseMode: telebot.ParseModeMarkdown,
	})
}

func (b *Bot) onStats(c telebot.Context) error {
	user := c.Sender()
	stats, err := b.store.GetUserStats(user.ID)
	if err != nil {
		return c.Send("❌ 获取统计失败")
	}
	text := fmt.Sprintf(`
📊 *你的统计*

消息数: %d
加入时间: %s
最后活跃: %s
`, stats.MessageCount, stats.JoinedAt.Format("2006-01-02"), stats.LastActive.Format("2006-01-02 15:04"))
	return c.Send(text, &telebot.SendOptions{
		ParseMode: telebot.ParseModeMarkdown,
	})
}

func (b *Bot) adminOnly(next telebot.HandlerFunc) telebot.HandlerFunc {
	return func(c telebot.Context) error {
		user := c.Sender()
		if !b.store.IsAdmin(user.ID) {
			return c.Send("❌ 你没有权限执行此操作")
		}
		return next(c)
	}
}

func (b *Bot) onBroadcast(c telebot.Context) error {
	args := c.Args()
	if len(args) == 0 {
		return c.Send("用法: /broadcast <消息内容>")
	}
	text := strings.Join(args, " ")
	count, err := b.store.BroadcastMessage(text)
	if err != nil {
		return c.Send(fmt.Sprintf("❌ 广播失败: %v", err))
	}
	return c.Send(fmt.Sprintf("✅ 广播已发送，共 %d 人收到", count))
}

func (b *Bot) onBan(c telebot.Context) error {
	args := c.Args()
	if len(args) < 1 {
		return c.Send("用法: /ban <user_id> [原因]")
	}
	userID := args[0]
	reason := "违反规则"
	if len(args) > 1 {
		reason = strings.Join(args[1:], " ")
	}
	if err := b.store.BanUser(userID, reason); err != nil {
		return c.Send(fmt.Sprintf("❌ 封禁失败: %v", err))
	}
	return c.Send(fmt.Sprintf("✅ 用户 %s 已被封禁\n原因: %s", userID, reason))
}

func (b *Bot) onUnban(c telebot.Context) error {
	args := c.Args()
	if len(args) < 1 {
		return c.Send("用法: /unban <user_id>")
	}
	if err := b.store.UnbanUser(args[0]); err != nil {
		return c.Send(fmt.Sprintf("❌ 解封失败: %v", err))
	}
	return c.Send(fmt.Sprintf("✅ 用户 %s 已解封", args[0]))
}

func (b *Bot) onKick(c telebot.Context) error {
	args := c.Args()
	if len(args) < 1 {
		return c.Send("用法: /kick <user_id>")
	}
	// 实现踢人逻辑
	return c.Send(fmt.Sprintf("✅ 用户 %s 已被踢出", args[0]))
}

func (b *Bot) onPin(c telebot.Context) error {
	msg := c.Message()
	if msg.ReplyTo == nil {
		return c.Send("请回复一条消息后使用 /pin")
	}
	return b.t.Pin(msg.ReplyTo)
}

func (b *Bot) onUnpin(c telebot.Context) error {
	return b.t.UnpinAll(c.Chat().ID)
}

func (b *Bot) onPoll(c telebot.Context) error {
	args := c.Args()
	if len(args) < 3 {
		return c.Send(`用法: /poll "问题" "选项1" "选项2" ...`)
	}
	question := args[0]
	options := args[1:]
	poll := &telebot.Poll{
		Question:     question,
		Options:      options,
		IsAnonymous:  true,
		Type:         "regular",
		OpenPeriod:   3600, // 1小时
	}
	_, err := b.t.SendPoll(c.Chat(), poll)
	if err != nil {
		return c.Send(fmt.Sprintf("❌ 创建投票失败: %v", err))
	}
	return nil
}

func (b *Bot) onCancel(c telebot.Context) error {
	b.fsm.Reset(c.Sender().ID)
	return c.Send("✅ 已取消当前操作")
}
```

---

## 附录 C：环境变量参考

| 变量名 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `TELEGRAM_BOT_TOKEN` | ✅ | - | Telegram Bot Token |
| `HTTP_ADDR` | ❌ | `:8080` | HTTP 服务监听地址 |
| `JWT_SECRET` | ✅ | - | JWT 签名密钥（生产环境必须修改） |
| `DATABASE_URL` | ✅ | `sqlite://./data.db` | 数据库连接字符串 |
| `REDIS_URL` | ❌ | `redis://localhost:6379/0` | Redis 连接字符串 |
| `APP_ENV` | ❌ | `development` | 运行环境 |
| `LOG_LEVEL` | ❌ | `info` | 日志级别 |
| `WEBHOOK_URL` | ❌ | - | Webhook 公网地址 |
| `WEBHOOK_PORT` | ❌ | `8443` | Webhook 监听端口 |
| `CORS_ORIGINS` | ❌ | `*` | 允许的跨域来源 |

---

## 附录 D：常用代码片段

### D.1 发送 Markdown 格式消息

```go
bot.Send(chat, `
*粗体文本*
_斜体文本_
[链接](https://example.com)
\`行内代码\`
\`\`\`go
代码块
\`\`\`
`, &telebot.SendOptions{
	ParseMode: telebot.ParseModeMarkdown,
})
```

### D.2 发送带内联按钮的消息

```go
markup := &telebot.ReplyMarkup{}
btn1 := markup.Data("👍 点赞", "like", "msg_42")
btn2 := markup.Data("👎 踩", "dislike", "msg_42")
btn3 := markup.URL("🌐 访问网站", "https://example.com")
markup.InlineKeyboard = [][]telebot.InlineButton{
	{btn1, btn2},
	{btn3},
}
bot.Send(chat, "你觉得这条消息怎么样？", markup)
```

### D.3 等待用户回复（Prompt）

```go
// 第一步：发送问题并等待回复
c.Send("请输入你的名字：")
c.Next(func(c telebot.Context) error {
	name := c.Text()
	c.Send(fmt.Sprintf("你好，%s！现在请输入你的年龄：", name))
	return nil
})
```

### D.4 文件上传快捷方式

```go
// 发送本地图片
bot.Send(chat, &telebot.Photo{
	File:    telebot.FromDisk("./screenshot.png"),
	Caption: "截图",
})

// 发送网络图片
bot.Send(chat, &telebot.Photo{
	File: telebot.FromURL("https://picsum.photos/600/400"),
})

// 发送文档
bot.Send(chat, &telebot.Document{
	File:     telebot.FromDisk("./report.pdf"),
	FileName: "月度报告.pdf",
	Caption:  "📄 请查收",
})
```

### D.5 定时任务

```go
// 每5分钟执行一次
ticker := time.NewTicker(5 * time.Minute)
go func() {
	for range ticker.C {
		// 清理过期数据
		count, _ := store.CleanupExpired()
		log.Printf("🧹 清理了 %d 条过期数据", count)
	}
}()

// 每天凌晨3点执行
go func() {
	for {
		now := time.Now()
		next := time.Date(now.Year(), now.Month(), now.Day()+1, 3, 0, 0, 0, now.Location())
		time.Sleep(time.Until(next))
		// 执行每日任务
		generateDailyReport()
	}
}()
```

---

> **全文完**。从基础入门到生产部署，从 telebot.v4 全部 API 到 WebSocket 双向通信，从静态 H5 管理界面到 Docker 容器化部署——这份教程覆盖了 Go + Telegram Bot 服务端开发的方方面面。把它吃透，你就能独立搭建一个企业级的 Bot 管理平台。

---

> 📌 **阅读建议**：
> 1. 先跑通第一部分，让 Bot 能回复 "Hello World"
> 2. 逐步添加 Handler、键盘、FSM，形成完整交互
> 3. 接入 WebSocket + H5 界面，实现可视化管控
> 4. 最后用 Docker 部署到服务器，配置 HTTPS + 监控
> 5. 随时查阅附录的 API 速查表
