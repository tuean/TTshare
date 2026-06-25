# TTshare 设计文档

## 概述

TTshare 是一个两端的个人网页快照工具：
- **手机端（Android/Flutter）**：接收 Android 系统分享菜单的 URL → 下载页面 → 生成 HTML 归档 + Markdown 阅读版 → 推送到坚果云 WebDAV
- **桌面端（macOS/Flutter）**：从 WebDAV 拉取内容 → 本地缓存 → 阅读/搜索/收藏/删除/再分享

## 系统架构

```
┌──────────────────────┐     ┌──────────────────────┐
│    Android 分享菜单   │     │   Mac Desktop App    │
│   (浏览器/知乎/微信   │     │   (阅读/搜索/管理)   │
│    等 App)           │     │                      │
└────────┬─────────────┘     └──────────┬───────────┘
         │ URL + 标题                    │ HTTPS WebDAV
         ▼                               ▼
┌─────────────────────────────────────────────┐
│            坚果云 WebDAV 服务器              │
│  /TTshare/<文章目录>/index.html              │
│  /TTshare/<文章目录>/index.md                │
└─────────────────────────────────────────────┘
```

## 手机端（Android/Flutter）

### 核心工作流

1. 用户在 App 中点击分享 → 选择 TTshare
2. Android 原生层通过 MethodChannel 把 URL + 标题传给 Flutter
3. 启动 WebView 加载页面（带上已存储的 Cookie）
4. WebView 渲染完成后，获取最终 HTML
5. 两个步骤并行：
   - **HTML 归档**：将页面保存为自包含的 .html 文件
   - **阅读模式提取**：通过 WebView 注入 Readability.js，提取正文后转 Markdown
6. 两文件写入临时目录，通过 WebDAV 上传到坚果云
7. 上传完成后弹出通知

### Cookie 管理

- 所有页面走 WebView 加载（而非直接 HTTP 下载），确保登录态有效
- Cookie 按 domain 持久化到本地文件
- 首次遇到某个域名时弹出 WebView 让用户手动登录，登录后自动捕获 Cookie
- WebView UA 设置为包含 "MicroMessenger" 以处理微信公众号文章
- 对需要"展开阅读全文"的页面自动注入 JS 模拟点击
- 设置页面提供 Cookie 管理（查看已登录域名、清除所有 Cookie）
- 上传失败（403/内容不完整）时提示用户重新登录

### App 页面结构

#### 主页面 — 分享记录列表

顶部标题栏 + 设置入口，主体为时间线列表，每项显示：标题、来源、保存时间、上传状态（成功/上传中/失败）。

状态有三种：
- ✅ 上传成功
- ⏳ 上传中
- ❌ 上传失败（可点击重试）

#### 设置页面

- WebDAV 配置：服务器 URL、用户名、密码、根目录（默认 /TTshare），含"验证连接"按钮
- Cookie 管理：列表显示已登录/未登录的域名，可清除所有 Cookie
- 关于页面：版本号

#### 内嵌 WebView 登录页

- 提示"请登录 xxx 以保存内容"
- 用户登录后自动捕获 Cookie 并关闭
- 5 分钟超时可取消

### 文件命名与目录结构

```
/TTshare/
├── 2026-06-25-微信公众号-文章标题/
│   ├── index.html
│   └── index.md
└── 2026-06-26-知乎-另一个标题/
    ├── index.html
    └── index.md
```

命名规则：`日期-来源-标题`，去非法字符，限长 100 字符。同名冲突追加 `_1`、`_2` 后缀。

## 桌面端（macOS/Flutter）

### 整体架构

```
WebDAV ↔ Sync Engine (pull/push) ↔ SQLite 本地缓存 ↔ App UI
```

- **Sync Engine**：首次全量拉取，后续增量检查（按文件修改时间），支持手动强制同步
- **SQLite 缓存**：存储文章元数据、收藏标记、搜索索引（FTS5 全文搜索）
- **本地文件缓存**：HTML 和 Markdown 文件缓存在本地

### 数据模型

```dart
class Article {
  String id;            // UUID
  String title;         // 文章标题
  String source;        // 来源域名/平台
  DateTime savedAt;     // 保存时间
  DateTime syncedAt;    // 同步到本地的时间
  bool isFavorite;      // 是否收藏
  String webdavPath;    // WebDAV 上的路径
  String htmlPath;      // 本地 HTML 缓存路径
  String mdPath;        // 本地 Markdown 缓存路径
}
```

### 页面布局（三栏式）

| 区域 | 内容 |
|------|------|
| 搜索栏（顶部固定） | 全文搜索，匹配标题 + Markdown 正文，即时响应 |
| 左侧列表 | 时间线倒序排列。顶部有"📌 收藏"过滤器。每项显示标题、来源、日期 |
| 右侧阅读区 | 默认渲染 HTML（内嵌 WebView），保留原网页排版。顶部浮层按钮：☆收藏、🔗分享、🗑删除、📄MD切换 |

### 核心功能

| 功能 | 说明 |
|------|------|
| **同步** | 后台自动同步 + 手动按钮。状态栏显示同步状态 |
| **搜索** | SQLite FTS5 全文搜索，搜索标题 + Markdown 正文 |
| **收藏** | SQLite 标记 `is_favorite`，左侧过滤器快速筛选 |
| **删除** | 确认弹窗 → 删除本地缓存 + SQLite 记录 + WebDAV 远程文件 |
| **再分享** | macOS 原生 Share Sheet，可将 Markdown/HTML 分享到微信、邮件、AirDrop 等 |
| **Markdown 切换** | 点击按钮切换 HTML/Markdown 视图 |

### 交互细节

- 搜索栏始终可见，输入即搜
- 列表默认按 savedAt 倒序
- 阅读区默认 HTML 视图
- 双击 Markdown 区域可复制全文
- 删除双重确认（先弹窗再执行）
- 状态栏：已同步 ✓ / 本地 N 篇 / WebDAV N 篇

## 技术栈

- **手机端**：Flutter (Android)，依赖包：http, sqflite, flutter_inappwebview, webdav_client, share_plus, path_provider
- **桌面端**：Flutter (macOS)，依赖包：sqflite (ffi), flutter_inappwebview (macOS), markdown, webdav_client, share_plus, path_provider

## 不包含的范围（明确不做）

- 不支持 iOS（当前只做 Android 手机端）
- 不提供自建服务器/托管服务
- 不再支持其他 WebDAV 服务商之外的同步方式（如 iCloud、Dropbox）
- 不做文章分类/标签系统（仅收藏标记）
