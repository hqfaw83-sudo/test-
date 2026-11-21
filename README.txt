聆听宇宙 1.1

原生 SwiftUI + HealthKit AirPods 聆听统计应用。
统计今日、近七天、历史累计、记录天数和设备名称分组。
重叠区间合并，跨日按本地日历拆分；只包括设备名称含 AirPods 的记录。
健康记录更新时在前台刷新，每次打开也重新读取。未启用后台交付。
不上传健康数据，不包含用户历史健康数据。
同名耳机合并；分项分别去重，总计跨设备去重。

GitHub Actions 自动编译未签名 IPA，请通过已验证的爱思签名方式安装。
Bundle ID 沿用测试版 com.airpodsprobe.healthtest。
check_math.py 在 macOS 上执行实际 Swift 统计代码的区间、跨日、空数据和夏令时检查。
