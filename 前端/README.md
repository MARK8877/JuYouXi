# 剧有戏 Flutter 前端

移动端首页与整体浏览框架：剧库、视频、追剧、我的。视频页按短剧竖向分页，读取剧集 JSON 中首集的 `videoUrl`、`url`、`playUrl` 或 `m3u8`；没有合法地址时显示海报与不可用状态，不伪造播放。页面通过现有 Go 服务的 `/api/ui/*` 接口读取数据，不在前端保存密码或服务凭据。

## 运行

默认 API 地址是 `http://127.0.0.1:9010`：

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:9010
```

Android 模拟器访问宿主机服务时使用：

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9010
```

真机请将地址替换为开发机在同一局域网内的 IP。构建前端不会停止或修改 9000/9010 服务。

## 验证

```bash
dart analyze .
flutter test
```
