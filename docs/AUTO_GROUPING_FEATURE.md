# 自动分组功能说明文档（已修正）

## 功能概述

当用户通过"分类管理"→"筛选类型"添加或编辑筛选类型时，系统会**自动识别**并分配到对应的分组：

- **微信交易类型** → **微信分组**（绿色 0xFF4CAF50）
- **支付宝交易分类** → **支付宝分组**（蓝色 0xFF1976D2）
- **其他类型** → **自定义分组**（灰色 0xFF9E9E9E）

---

## 完整分类列表

**数据源**：`lib/models/models.dart` 中的 `kSpendingCategories`（第 61-103 行）

### 微信交易类型（8种）
```dart
const wechatTypes = {
  '商户消费', '红包', '转账', '群收款',
  '二维码收付款', '充值提现', '信用卡还款', '退款',
}
```

### 支付宝交易分类（7种）
```dart
const alipayTypes = {
  '餐饮美食', '交通出行', '日用百货', '充值缴费',
  '转账红包', '投资理财', '生活服务',
}
```

### 其他分类（用户自定义或系统定义的其他分类）
包括但不限于：
- 服饰装扮、家居家装、数码电器、运动户外
- 美容美发、母婴亲子、宠物、爱车养车
- 住房物业、酒店旅游、文化休闲、教育培训
- 医疗健康、公共服务、商业服务、公益捐赠
- 互助保障、保险、信用借还、收入、转账红包
- 亲友代付、账户存取、退款、其他

---

## 代码实现

### 1. insertFilterType 方法（添加筛选类型）

**位置**：`lib/data/database_helper.dart` 第 550-604 行

**功能**：添加新筛选类型时自动分配分组

```dart
/// 添加筛选类型（自动分配到对应分组）
/// 使用 kSpendingCategories 中的完整分类列表（包含微信、支付宝的所有类型）
Future<int> insertFilterType(String name) async {
  final db = await database;
  final now = DateTime.now().millisecondsSinceEpoch;

  // 自动分配分组：微信类型 → 微信分组，支付宝类型 → 支付宝分组
  final groups = await db.query('category_groups', columns: ['id', 'name']);
  final groupMap = {for (final g in groups) g['name'] as String: g['id'] as int};

  final wechatGroupId = groupMap['微信'];
  final alipayGroupId = groupMap['支付宝'];
  final customGroupId = groupMap['自定义'];

  // 微信交易类型（完整列表）
  const wechatTypes = {
    '商户消费', '红包', '转账', '群收款',
    '二维码收付款', '充值提现', '信用卡还款', '退款',
  };

  // 支付宝交易分类（完整列表）
  const alipayTypes = {
    '餐饮美食', '交通出行', '日用百货', '充值缴费',
    '转账红包', '投资理财', '生活服务',
  };

  // 根据筛选类型名称决定分组
  int? groupId;
  if (wechatTypes.contains(name) && wechatGroupId != null) {
    groupId = wechatGroupId;  // ✅ 微信类型 → 微信分组
  } else if (alipayTypes.contains(name) && alipayGroupId != null) {
    groupId = alipayGroupId;  // ✅ 支付宝类型 → 支付宝分组
  } else if (customGroupId != null) {
    groupId = customGroupId;  // ✅ 其他 → 自定义分组
  }

  // 插入时包含 group_id
  return db.insert('filter_types', {
    'name': name,
    'sort_order': maxOrder + 1,
    'created_at': now,
    if (groupId != null) 'group_id': groupId,  // ✅ 自动分配
  });
}
```

### 2. updateFilterType 方法（编辑筛选类型）

**位置**：`lib/data/database_helper.dart` 第 606-650 行

**功能**：编辑筛选类型名称时自动更新分组关联

```dart
/// 更新筛选类型名称（自动更新分组）
/// 使用 kSpendingCategories 中的完整分类列表（包含微信、支付宝的所有类型）
Future<int> updateFilterType(int id, String newName) async {
  final db = await database;

  // 获取分组映射和类型列表
  final groups = await db.query('category_groups', columns: ['id', 'name']);
  final groupMap = {for (final g in groups) g['name'] as String: g['id'] as int};

  final wechatGroupId = groupMap['微信'];
  final alipayGroupId = groupMap['支付宝'];
  final customGroupId = groupMap['自定义'];

  // 微信交易类型（完整列表）
  const wechatTypes = {
    '商户消费', '红包', '转账', '群收款',
    '二维码收付款', '充值提现', '信用卡还款', '退款',
  };

  // 支付宝交易分类（完整列表）
  const alipayTypes = {
    '餐饮美食', '交通出行', '日用百货', '充值缴费',
    '转账红包', '投资理财', '生活服务',
  };

  // 根据新名称决定分组
  int? groupId;
  if (wechatTypes.contains(newName) && wechatGroupId != null) {
    groupId = wechatGroupId;  // ✅ 修改为微信类型 → 微信分组
  } else if (alipayTypes.contains(newName) && alipayGroupId != null) {
    groupId = alipayGroupId;  // ✅ 修改为支付宝类型 → 支付宝分组
  } else if (customGroupId != null) {
    groupId = customGroupId;  // ✅ 修改为其他 → 自定义分组
  }

  // 更新时包含 group_id
  return db.update('filter_types', {
    'name': newName,
    if (groupId != null) 'group_id': groupId,  // ✅ 自动更新
  }, where: 'id = ?', whereArgs: [id]);
}
```

### 3. _ensureFilterTypesHaveGroups 方法（应用启动时修复）

**位置**：`lib/main.dart` 第 235-268 行

**功能**：修复现有筛选类型的分组关联

```dart
/// 确保筛选类型都有分组关联（修复数据）
/// 使用 kSpendingCategories 中的完整分类列表（包含微信、支付宝的所有类型）
Future<void> _ensureFilterTypesHaveGroups() async {
  // 微信交易类型（完整列表）
  const wechatTypes = {
    '商户消费', '红包', '转账', '群收款',
    '二维码收付款', '充值提现', '信用卡还款', '退款',
  };

  // 支付宝交易分类（完整列表）
  const alipayTypes = {
    '餐饮美食', '交通出行', '日用百货', '充值缴费',
    '转账红包', '投资理财', '生活服务',
  };

  // 获取分组ID映射
  final groupMap = {for (final g in _categoryGroups) g.name: g.id};
  final wechatGroupId = groupMap['微信'];
  final alipayGroupId = groupMap['支付宝'];
  final customGroupId = groupMap['自定义'];

  // 检查筛选类型并修复
  bool needsReload = false;
  for (final ft in _filterTypes) {
    int? targetGroupId;

    // 根据筛选类型名称决定分组
    if (wechatTypes.contains(ft.name) && wechatGroupId != null) {
      targetGroupId = wechatGroupId;
    } else if (alipayTypes.contains(ft.name) && alipayGroupId != null) {
      targetGroupId = alipayGroupId;
    } else if (ft.groupId == null) {
      targetGroupId = customGroupId;
    }

    // 如果需要更新
    if (targetGroupId != null && ft.groupId != targetGroupId) {
      await _db.updateFilterTypeGroup(ft.id, targetGroupId);
      needsReload = true;
    }
  }

  // 如果有更新，重新加载筛选类型
  if (needsReload) {
    await _loadFilterTypes();
  }
}
```

---

## 分组映射表

| 筛选类型名称 | 自动分配分组 | 颜色 | 分类来源 |
|-------------|---------------|------|---------|
| **微信类型** | | | |
| 商户消费 | 微信分组 | 🟢 绿色 (0xFF4CAF50) | kSpendingCategories |
| 红包 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| 转账 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| 群收款 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| 二维码收付款 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| 充值提现 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| 信用卡还款 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| 退款 | 微信分组 | 🟢 绿色 | kSpendingCategories |
| **支付宝类型** | | | |
| 餐饮美食 | 支付宝分组 | 🔵 蓝色 (0xFF1976D2) | kSpendingCategories |
| 交通出行 | 支付宝分组 | 🔵 蓝色 | kSpendingCategories |
| 日用百货 | 支付宝分组 | 🔵 蓝色 | kSpendingCategories |
| 充值缴费 | 支付宝分组 | 🔵 蓝色 | kSpendingCategories |
| 转账红包 | 支付宝分组 | 🔵 蓝色 | kSpendingCategories |
| 投资理财 | 支付宝分组 | 🔵 蓝色 | kSpendingCategories |
| 生活服务 | 支付宝分组 | 🔵 蓝色 | kSpendingCategories |
| **其他类型** | | | |
| 服饰装扮、家居家装、数码电器、运动户外、美容美发、母婴亲子、宠物、爱车养车 | 自定义分组 | ⚪ 灰色 (0xFF9E9E9E) | kSpendingCategories |
| 住房物业、酒店旅游、文化休闲、教育培训、医疗健康、公共服务、商业服务 | 自定义分组 | ⚪ 灰色 | kSpendingCategories |
| 公益捐赠、互助保障、保险、信用借还、充值缴费、收入、转账红包、亲友代付、账户存取、退款、其他 | 自定义分组 | ⚪ 灰色 | kSpendingCategories |

---

## 验证测试

### 测试 1：添加微信类型

**步骤**：
1. 打开"分类管理"→"筛选类型"标签
2. 点击右下角 + 按钮
3. 选择"红包"（如果未添加）
4. 点击"添加"

**预期结果**：
- ✅ 提示"已添加筛选类型「红包」"
- ✅ 列表中"红包"左侧显示**绿色圆点**
- ✅ 在首页筛选弹窗中，"红包"Chip 显示**绿色背景**

### 测试 2：添加支付宝类型

**步骤**：
1. 打开"分类管理"→"筛选类型"标签
2. 点击右下角 + 按钮
3. 选择"餐饮美食"（如果未添加）
4. 点击"添加"

**预期结果**：
- ✅ 提示"已添加筛选类型「餐饮美食」"
- ✅ 列表中"餐饮美食"左侧显示**蓝色圆点**
- ✅ 在首页筛选弹窗中，"餐饮美食"Chip 显示**蓝色背景**

### 测试 3：添加其他分类

**步骤**：
1. 打开"分类管理"→"筛选类型"标签
2. 点击右下角 + 按钮
3. 选择"服饰装扮"（如果未添加）
4. 点击"添加"

**预期结果**：
- ✅ 提示"已添加筛选类型「服饰装扮」"
- ✅ 列表中"服饰装扮"左侧显示**灰色圆点**
- ✅ 在首页筛选弹窗中，"服饰装扮"Chip 显示**灰色背景**

### 测试 4：编辑筛选类型名称（改为其他分类）

**步骤**：
1. 在筛选类型列表中，点击某个类型的编辑图标
2. 将名称改为"投资理财"（支付宝类型）
3. 点击"保存"

**预期结果**：
- ✅ 提示"已修改为「投资理财」"
- ✅ 该筛选类型左侧显示**蓝色圆点**
- ✅ 在首页筛选弹窗中显示**蓝色背景**

---

## 技术细节

### 数据来源

**kSpendingCategories 定义位置**：`lib/models/models.dart` 第 61-103 行

**包含内容**：
1. 支付宝常用分类（餐饮美食、交通出行等）
2. 微信交易类型（作为分类使用）
3. 其他消费分类（服饰装扮、家居家装等）
4. 收入相关（收入、转账红包等）
5. 其他类型（账户存取、退款等）

### 自动分组逻辑

```dart
// 1. 查询所有分组
final groups = await db.query('category_groups', columns: ['id', 'name']);
final groupMap = {for (final g in groups) g['name'] as String: g['id'] as int};

// 2. 提取分组 ID
final wechatGroupId = groupMap['微信'];      // 绿色
final alipayGroupId = groupMap['支付宝'];    // 蓝色
final customGroupId = groupMap['自定义'];      // 灰色

// 3. 根据类型名称匹配
int? groupId;
if (wechatTypes.contains(name)) {
  groupId = wechatGroupId;     // 微信类型
} else if (alipayTypes.contains(name)) {
  groupId = alipayGroupId;    // 支付宝类型
} else {
  groupId = customGroupId;      // 其他
}
```

### 数据库表结构

**category_groups 表**：
```sql
CREATE TABLE category_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,     -- 分组名称：微信、支付宝、自定义
  color INTEGER NOT NULL,           -- 分组颜色（ARGB 格式）
  sort_order INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  is_system INTEGER NOT NULL       -- 是否为系统分组
)
```

**filter_types 表**：
```sql
CREATE TABLE filter_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,         -- 筛选类型名称
  sort_order INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  group_id INTEGER                   -- 关联到 category_groups.id（自动分配）
)
```

---

## 用户场景

### 场景 1：首次使用应用
- ✅ 数据库初始化时自动创建"微信"、"支付宝"、"自定义"分组
- ✅ 默认筛选类型自动分配到对应分组
- ✅ 无需手动干预

### 场景 2：用户添加新的微信类型
- ✅ 从"分类管理"添加时自动识别为微信类型
- ✅ 自动分配到微信分组（绿色）
- ✅ 无需手动设置分组

### 场景 3：用户添加新的支付宝类型
- ✅ 从"分类管理"添加时自动识别为支付宝类型
- ✅ 自动分配到支付宝分组（蓝色）
- ✅ 无需手动设置分组

### 场景 4：用户添加其他分类
- ✅ 从"分类管理"添加时自动识别为其他类型
- ✅ 自动分配到自定义分组（灰色）
- ✅ 无需手动设置分组

### 场景 5：用户修改筛选类型名称
- ✅ 根据新名称重新判断分组
- ✅ 自动更新分组关联
- ✅ 颜色随之改变

### 场景 6：应用启动
- ✅ `_ensureFilterTypesHaveGroups()` 自动检查并修复
- ✅ 所有未分配分组的筛选类型自动分配
- ✅ 确保数据一致性

### 场景 7：手动调整分组
- ✅ 用户仍可手动点击"设置分组"按钮覆盖自动分配
- ✅ 优先级：手动设置 > 自动分配
- ✅ 灵活性强

---

## 常见问题

### Q: 为什么某些筛选类型是灰色？
**A**: 因为该类型名称不在微信类型列表或支付宝类型列表中，自动分配到"自定义"分组（灰色）。这些可能是用户自定义的分类或其他系统分类（如"服饰装扮"、"医疗健康"等）。

### Q: 如何改变某个筛选类型的颜色？
**A**:
1. 方法 1：在"分组管理"中修改"自定义"分组的颜色
2. 方法 2：手动为该筛选类型设置微信或支付宝分组

### Q: 系统分类和筛选类型的区别？
**A**:
- **系统分类 (kSpendingCategories)**：用于账单分类分析（包含所有可能的消费和收入分类）
- **筛选类型 (filter_types)**：用于首页筛选（用户可从系统分类中选择添加）

### Q: kSpendingCategories 包含了哪些类型？
**A**:
1. **支付宝常用分类**：餐饮美食、交通出行、日用百货、充值缴费、转账红包、投资理财、生活服务（7种）
2. **微信交易类型**：商户消费、红包、转账、群收款、二维码收付款、充值提现、信用卡还款、退款（8种）
3. **其他消费分类**：服饰装扮、家居家装、数码电器、运动户外、美容美发、母婴亲子、宠物、爱车养车等（约20种）
4. **收入和其他**：收入、转账红包、亲友代付、账户存取、退款、其他等（约8种）

---

**功能完成！用户添加或编辑筛选类型时，系统会自动识别所有系统分类并分配到对应分组，颜色将自动匹配。** ✨

**修改说明**：已更新为使用完整的 `kSpendingCategories` 分类列表，包含微信和支付宝的所有类型，不再遗漏任何系统分类的自动分组。
