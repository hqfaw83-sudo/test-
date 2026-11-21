AirPods 健康权限测试工程

用途：验证签名安装后能否读取耳机音频音量。不是完整聆听统计应用。
工程尚未在 macOS 编译，也未在 iPhone 验证。

1. 将本目录全部内容放到 GitHub 仓库根目录，务必保留 .github/workflows/build.yml。
2. GitHub 仓库 Actions → Build iPhone test IPA → Run workflow。
3. 成功后在该次运行的 Artifacts 下载 AirPodsHealthProbe-unsigned，解压出 IPA。
4. Windows 爱思助手 → 工具箱 → IPA签名 → 添加 IPA → 使用 Apple ID 签名。
5. 在爱思中自行输入账号及验证信息，签名成功后安装到连接的 iPhone。
6. 按 iOS 提示完成信任和开发者模式，然后打开应用，请求健康授权并读取记录。

若签名或安装提示 HealthKit 权限不支持，保留完整错误信息。不要删除 HealthKit 权限以伪装成功。
若无记录，检查健康 App 是否已有耳机音频音量数据及读取授权。
免费签名的 HealthKit 可用性尚未验证；编译成功或安装成功不代表健康读取成功。
不要将 Apple 密码、验证码、签名证书或健康导出文件放入仓库。
