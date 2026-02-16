# 自由记账 🪙

[![Flutter](https://img.shields.io/badge/Flutter-v3.0+-02569B?logo=flutter)](https://flutter.dev)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-blue)]()

**自由记账** 是一款秉承“本地优先 (Local-First)”理念打造的跨平台记账与财务分析工具。它致力于在保护用户隐私的同时，提供极度灵活的账单管理、分类整理与深度分析体验。

---
## 为什么要做这样一款软件
  
  在实际生活中，免不了有些场景用支付宝支付，有些场景用微信支付。而当我想要好好计算这个月花了多少时，又要人工自己计算，有些时候又会忘了去记账😢。当我自己做了这样一款软件（半自动，需要申请微信、支付宝账单导入，听起来比较鸡肋🫠）后，也是变相的提醒自己每个月该导出订单看一看，算一笔总账。同样地，薅一薅AI的羊毛，积累一下经验。

## ✨ 核心特性

- 🔒 **本地优先 & 隐私保护**：所有记账数据存储在用户本地 SQLite 数据库中。无需注册，不上传云端，你的隐私只属于你自己。
- 📥 **智能账单导入**：完美适配 **微信支付** 与 **支付宝** 导出的账单文件 (CSV/Excel)，一键完成数据同步。
- 🗂️ **灵活的分组管理**：支持对账单分类进行多级分组，自定义颜色与图标，让财务结构一目了然。<img width="495" height="1018" alt="image" src="https://github.com/user-attachments/assets/391c1a68-4c0e-4cc0-8179-8d8e408811b5" /><img width="544" height="1024" alt="image" src="https://github.com/user-attachments/assets/d714ed3a-ac57-4c58-ac42-df6a8241c428" />


- 🛠️ **强大的批量编辑**：支持多选账单批量修改分类、添加备注，极大提升整理效率。<img width="496" height="1016" alt="image" src="https://github.com/user-attachments/assets/d7a3dd66-d4e4-459b-905f-f27c24aeece7" />

- 🎨 **现代化 UI 设计**：采用 Material 3 设计语言，支持网格化图标视图，操作直观且视觉精美。<img width="486" height="893" alt="image" src="https://github.com/user-attachments/assets/19bc8bef-34c6-4ef7-a305-94a74bf62a00" />

- 📊 **多维筛选过滤**：基于交易类型、分类、分组及搜索详情的深度过滤系统。

---

## � 页面功能介绍

### 1. 首页列表 (Home)
- **数据统计面板**：顶部实时显示当月收入、支出及结余，配合下拉刷新功能，随时掌握财务状况。
- **多维筛选**：右上角提供强大的筛选器，可组合“交易类型”、“日期范围”、“金额区间”等条件快速定位账单。

### 2. 分类管理 (Category Management)
- **账单分类 Tab**：
  - **自定义分类**：用户可自由添加、编辑、删除个性化分类，支持自定义名称。
  - **智能归类**：系统内置微信和支付宝标准分类，并支持将自定义分类与系统分组关联。
- **筛选类型 Tab**：
  - **分组展示**：筛选类型按分组归类显示，颜色与分组标识保持一致，查找更直观。
  - **快捷管理**：自动排序，支持重命名及删除操作。
- **分组管理 Tab**：
  - **全局分组**：创建全局通用的分类分组（如“餐饮美食”、“交通出行”）。
  - **颜色定制**：提供 19 种 Google Material Design 标准色，为每个分组定制专属色彩。

### 3. 批量操作 (Batch Operations)
- **高效整理**：在首页点击编辑按钮即可激活批量模式，支持滑动多选。
- **批量修改**：选中多条账单后，可一键修改它们的分类，解决导入账单分类混乱的问题。
- **批量备注**：支持为多笔交易统一添加备注，记录消费场景。
- **批量删除**：快速清理重复或无效的账单记录。

### 4. 图表分析 (Analysis)
- **多维度视图**：提供“周”、“月”、“年”三种时间维度的切换，满足短、中、长期不同的财务分析需求。
- **趋势分析**：
  - **周视图**：双柱图直观对比本周与上周的每日消费差异。
  - **月视图**：柱状图展示近 5 个月的收支变化趋势，快速识别消费波动。
  - **年视图**：全年月度走势图，宏观掌握年度财务状况。
- **可视化日历**：
  - **月历热力图**：在月视图中以日历形式展示每日收支，金额大小通过颜色深浅或标记直观呈现，通过点击具体日期可查看当日流水详情。
- **分类排行**：详细的分类支出排行榜，展示各分类的金额、占比及条目数，精准定位主要开支点。

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

本项目采用 [GNU GPL v3.0](LICENSE) 开源协议。

---

## 🤝 贡献与反馈

如果你有任何建议或发现了 Bug，欢迎通过以下方式参与：
- 提交 [Issue](https://github.com/kingway327/Flexible-Accounting/issues)
- 提交 [Pull Request](https://github.com/kingway327/Flexible-Accounting/pulls)

让我们一起构建一个更纯粹、更灵活的记账工具！
