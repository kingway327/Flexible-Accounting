# Flexible Accounting (灵活记账) 🪙

[![Flutter](https://img.shields.io/badge/Flutter-v3.0+-02569B?logo=flutter)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-blue)]()

**Flexible Accounting** 是一款秉承“本地优先 (Local-First)”理念打造的跨平台记账与财务分析工具。它致力于在保护用户隐私的同时，提供极度灵活的账单管理、分类整理与深度分析体验。

---

## ✨ 核心特性

- 🔒 **本地优先 & 隐私保护**：所有记账数据存储在用户本地 SQLite 数据库中。无需注册，不上传云端，你的隐私只属于你自己。
- 📥 **智能账单导入**：完美适配 **微信支付** 与 **支付宝** 导出的账单文件 (CSV/Excel)，一键完成数据同步。
- 🗂️ **灵活的分组管理**：支持对账单分类进行多级分组，自定义颜色与图标，让财务结构一目了然。
- 🛠️ **强大的批量编辑**：支持多选账单批量修改分类、添加备注，极大提升整理效率。
- 🎨 **现代化 UI 设计**：采用 Material 3 设计语言，支持网格化图标视图，操作直观且视觉精美。
- 📊 **多维筛选过滤**：基于交易类型、分类、分组及搜索详情的深度过滤系统。

---

## 📸 界面预览

*(提示：你可以在此处添加你屏幕截图的图片链接)*

- **首页列表**：清晰的时间轴流水
- **分类管理**：自由定制的分组与网格化图标
- **批量操作**：高效的账单快速整理

---

## 🚀 快速开始

### 环境依赖
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (建议 v3.0 及以上版本)
- Android Studio / VS Code (安装 Dart 与 Flutter 插件)

### 本地编译
1. 克隆仓库：
   ```bash
   git clone https://github.com/kingway327/Flexible-Accounting.git
   cd Flexible-Accounting
   ```
2. 安装依赖：
   ```bash
   flutter pub get
   ```
3. 运行项目：
   ```bash
   flutter run
   ```

---

## 🛠️ 技术栈

- **框架**: Flutter
- **语言**: Dart
- **数据库**: SQLite (sqflite)
- **状态管理**: Provider
- **文件处理**: file_picker, excel

---

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

---

## 🤝 贡献与反馈

如果你有任何建议或发现了 Bug，欢迎通过以下方式参与：
- 提交 [Issue](https://github.com/kingway327/Flexible-Accounting/issues)
- 提交 [Pull Request](https://github.com/kingway327/Flexible-Accounting/pulls)

让我们一起构建一个更纯粹、更灵活的记账工具！
