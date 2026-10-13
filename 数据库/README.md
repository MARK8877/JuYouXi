# 剧库 MySQL 独立 API

这是一个新生成的独立项目，位于 `/Users/mark/Documents/ChatGPT/剧有戏/数据库`。它不修改、不替换当前运行在 9000 端口的真实项目。

## 运行

先准备 MySQL 数据库。`schema.sql` 包含 `juku_library` 数据库和表结构；如果使用已有账号，请先在 MySQL 客户端执行它，或把 DSN 指向已经存在的 `juku_library` 数据库。

随后只通过环境变量提供连接信息：

```bash
cd /Users/mark/Documents/ChatGPT/剧有戏/数据库
export JUKU_MYSQL_DSN='user:password@tcp(127.0.0.1:3307)/juku_library?parseTime=true&charset=utf8mb4'
go run ./cmd/server
```

服务默认监听 `http://127.0.0.1:9010`。可用 `JUKU_ADDR=:9011` 修改端口。密码只存在当前进程环境，不会写入代码、SQL、README 或日志。

如果未设置 `JUKU_MYSQL_DSN`，服务仍会启动文档/内存模式，Swagger 可以访问，但业务数据不会持久化；设置 DSN 后才启用 MySQL 持久化。

启动后在线 Swagger 文档地址为 [`http://127.0.0.1:9010/swagger/`](http://127.0.0.1:9010/swagger/)，原始文档地址为 [`http://127.0.0.1:9010/swagger/openapi.yaml`](http://127.0.0.1:9010/swagger/openapi.yaml)。Swagger UI 的静态资源从 `unpkg.com` 加载；无外网时仍可直接访问 YAML 文件。

## 导入剧库数据

导入器接受原接口的 `Drama[]`，也接受带 `data` 字段的接口响应：

```bash
JUKU_MYSQL_DSN='user:password@tcp(127.0.0.1:3307)/juku_library?parseTime=true&charset=utf8mb4' \
  go run ./cmd/import -file ./dramas.json
```

导入器只写入剧集及索引字段，不保存临时播放地址或密码。

## 已覆盖接口

接口路径和字段按已检查的 `#library` 页面保持兼容，详细定义见 [`openapi.yaml`](./openapi.yaml)：

- `/health`
- `/api/ui/viewer`
- `/api/ui/dramas`
- `/api/ui/search`
- `/api/ui/dramas/refresh`
- `/api/ui/cover/repair`
- `/api/ui/following`
- `/api/ui/history`
- `/api/ui/download`
- `/api/ui/rankings`
- `/api/ui/recommendations`
- `/api/ui/image`

剧集完整响应保存在 `dramas.payload` JSON 列，同时把标题、站源、分类、集数等常用字段单独索引。追剧、观看记录、浏览器身份和下载提交使用独立表。临时播放地址、`stoken` 和密码不保存。

## 范围边界

本项目提供数据库持久化和兼容 API，不复制真实项目的红果抓取、播放转码、FFmpeg、Emby 和下载 worker。没有上游导入数据时，剧库接口会返回空数组；可直接用 SQL 或后续导入程序写入 `dramas` 表的 `payload`。
