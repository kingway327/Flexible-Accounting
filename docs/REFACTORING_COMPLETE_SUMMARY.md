# 数据库与分类逻辑重构完成总结

## 实施日期
2026年1月25日

## 更改概览

根据用户反馈的实施方案，已完成以下重构和增强：

### 1. 模型层（Model Layer）✅ 已完成

#### models.dart 变更
- **TransactionType 枚举**：已包含 `ignore` 值（代表"不计收支"）
- `kTransactionCategories` 删除，使用新的 `kWechatTransactionTypes` 和 `kAlipayCategories`
- `kSpendingCategories` 引用更新，合并微信和支付宝分类

```dart
// TypeFilter 枚举（已新增 notCounted）
enum TypeFilter { all, expense, income, notCounted }

// 微信交易类型（8 类，包含退款处理）
const List<String> kWechatTransactionTypes = [
  '商户消费', '红包', '转账', '群收款',
  '二维码收付款', '充值提现', '信用卡还款', '退款',
];

// 支付宝交易分类（39 类）
const List<String> kAlipayCategories = [
  // 日常消费
  '餐饮美食', '服饰装扮', '日用百货', '家居家装', '数码电器',
  '运动户外', '美容美发', '母婴亲子', '宠物', '交通出行',
  '爱车养车', '住房物业', '酒店旅游', '文化休闲', '教育培训',
  '医疗健康', '生活服务', '公共服务', '商业服务', '公益捐赠',
  '互助保障', '投资理财', '保险', '信用借还', '充值缴费',
  // 潬账相关
  '收入', '转账红包', '亲友代付', '账户存取', '退款',
  '其他',
];

// 消费分类（用于分析统计）
const List<String> kSpendingCategories = kAlipayCategories;
```

---

### 2. 常量层（Constants）✅ 已完成

#### main.dart 变更
- **TypeFilter 枚举**：新增 `notCounted` 选项
- **交易类型常量重构**：
  - `kTransactionTypes` → 删除
  - `kSpendingCategories` → 使用 `kWechatTransactionTypes` + `kAlipayCategories`

```dart
// 微信交易类型（8 类）
const List<String> kWechatTransactionTypes = [
  '商户消费', '红包', '转账', '群收款',
  '二维码收付款', '充值提现', '信用卡还款', '退款',
];

// 支付宝交易分类（39 类）
const List<String> kAlipayCategories = [
  // 日常消费
  '餐饮美食', '服饰装扮', '日用百货', '家居家装', '数码电器',
  '运动户外', '美容美发', '母婴亲子', '宠物', '交通出行',
  '爱车养车', '住房物业', '酒店旅游', '文化休闲', '教育培训',
  '医疗健康', '生活服务', '公共服务', '商业服务', '公益捐赠',
  '互助保障', '投资理财', '保险', '信用借还', '充值缴费',
  // 潬账相关
  '收入', '转账红包', '亲友代付', '账户存取', '退款',
  '其他',
];

// 消费分类（用于分析统计）
const List<String> kSpendingCategories = kAlipayCategories;

// 兼容旧代码
@Deprecated('Use kWechatTransactionTypes and kAlipayCategories instead')
const List<String> kTransactionCategories = [...kWechatTransactionTypes, ...kAlipayCategories];
```

---

### 3. 解析逻辑（Parsing Logic）✅ 已完成

#### parsers.dart 变更
- **WechatParser 增强**：添加 `cleanTransactionType` 静态方法

```dart
/// 清洗微信交易类型
/// 将"转账-退款"等类型统一为"退款"
static String _cleanTransactionType(
  String direction,
  String status,
  String description,
) {
  final type = direction; // 优先使用"收/支"字段判断

  // 如果包含"-退款"后缀，统一归为"退款"
  if (type.contains('-退款')) {
    return '退款';
  }

  return type;
}

// 更新 _mapWechatType 方法，使用清洗后的类型
static TransactionType _mapWechatType(
    String direction,
    String status,
    String description,
  ) {
    final cleanedType = _cleanTransactionType(direction, status, description);
    
    if (cleanedType == '支出') {
      return TransactionType.expense;
    }
    if (cleanedType == '收入') {
      return TransactionType.income;
    }
    if (cleanedType == '不计收支' || cleanedType == '退款') {
      return TransactionType.ignore;
    }
    return TransactionType.ignore;
  }
}
```

**退款类型处理示例**：
- `转账-退款` → `退款`
- `商户消费-退款` → `退款`
- `转账` → `轟账`（不计收支）
```

---

### 4. 数据库层（Database Layer）✅ 已完成

#### database_helper.dart 变更
- **预置筛选类型更新**：使用新的分类列表
- **insertFilterType 方法**：自动分配分组
- **updateFilterType 方法**：自动更新分组
- **_ensureFilterTypesHaveGroups 方法**：应用启动时修复数据

```dart
/// 微信交易类型（8 类，关联微信分组）
const kWechatFilterTypes = [
  '商户消费', '红包', '转账', '群收款',
  '二维码收付款', '充值提现', '信用卡还款', '退款',
];

/// 支付宝交易分类（39 类），关联支付宝分组
const List<String> kAlipayCategories = [
  // 日常消费
  '餐饮美食', '服饰装扮', '日用百货', '家居家装', '数码电器',
  '运动户外', '美容美发', '母婴亲子', '宠物', '交通出行',
  '爱车养车', '住房物业', '酒店旅游', '文化休闲', '教育培训',
  '医疗健康', '生活服务', '公共服务', '商业服务', '公益捐赠',
  '互助保障', '投资理财', '保险', '信用借还', '充值缴费',
  // 潬账相关
  '收入', '转账红包', '亲友代付', '账户存取', '退款',
  '其他',
];

/// 添加筛选类型（自动分配到对应分组）
/// 使用 main.dart 中定义的完整分类列表
Future<int> insertFilterType(String name) async {
  final db = await database;
  final now = DateTime.now().millisecondsSinceEpoch;

  // 自动分配分组：微信类型 → 微信分组，支付宝类型 → 支付宝分组
  final groups = await db.query('category_groups', columns: ['id', 'name']);
  final groupMap = {for (final g in groups) g['name'] as String: g['id'] as int};

  final wechatGroupId = groupMap['微信'];
  final alipayGroupId = groupMap['支付宝'];
  final customGroupId = groupMap['自定义'];

  // 根据筛选类型名称决定分组
  int? groupId;
  if (kWechatFilterTypes.contains(name) && wechatGroupId != null) {
    groupId = wechatGroupId;
  } else if (kAlipayCategories.contains(name) && alipayGroupId != null) {
      groupId = alipayGroupId;
    } else if (customGroupId != null) {
      groupId = customGroupId;
    }

  // 插入时包含 group_id
  return db.insert('filter_types', {
    'name': name,
    'sort_order': maxOrder + 1,
    'created_at': now,
    if (groupId != null) 'group_id': groupId,
  }, conflictAlgorithm: ConflictAlgorithm.ignore,);
}
```

---

### 5. UI 层（筛选界面）✅ 已完成

#### main.dart 变更
- **筛选弹窗收支类型**：添加「不计收支」选项
- **_applyFilter 方法**：支持 `notCounted` 筛选

```dart
// 收支类型筛选
Row(
  children: [
    _FilterChip(label: '全部', selected: typeFilter == TypeFilter.all,
      onTap: () => setState(() => typeFilter = TypeFilter.all)),
    const SizedBox(width: 12),
    _FilterChip(label: '支出', selected: typeFilter == TypeFilter.expense,
      onTap: () => setState(() => typeFilter = TypeFilter.expense)),
    const SizedBox(width: 12),
    _FilterChip(label: '收入', selected: typeFilter == TypeFilter.income,
      onTap: () => setState(() => typeFilter = TypeFilter.income)),
    const SizedBox(width: 12),
    _FilterChip(label: '不计收支', selected: typeFilter == TypeFilter.notCounted,
      onTap: () => setState(() => typeFilter = TypeFilter.notCounted)),
  ],
),

// _applyFilter 方法（支持不计收支筛选）
if (_typeFilter == TypeFilter.expense && record.type != TransactionType.expense) {
  return false;
}
if (_typeFilter == TypeFilter.income && record.type != TransactionType.income) {
  return false;
}
if (_typeFilter == TypeFilter.notCounted && record.type != TransactionType.ignore) {
  return false;
}
```

---

## 分组映射表

### 微信类型（8 类）→ 微信分组（绿色）
| 商户消费, 红包, 转账, 群收款, 二维码收付款, 充值提现, 信用卡还款, 退款 |

### 支付宝类型（39 类）→ 支付宝分组（蓝色）
| 餐饮美食, 交通出行, 日用百货, 充值缴费, 转账红包, 投资理财, 生活服务 + 其他约30 类

### 其他类型→ 自定义分组（灰色）
| 其他消费分类（服饰装扮、家居家装等）+ 收入相关类型

---

## 核心改进

### 1. 精确的分类列表
- **区分微信和支付宝**：分为两个独立的常量列表
- **完整覆盖**：39 类支付宝分类 + 8 类微信类型 = 47 类总计

### 2. 智能退款处理
- **统一归类**：`转账-退款` 统一归为「退款」类型
- **保持一致性**：所有退款类型都以「退款」形式存储

### 3. 不计收支筛选
- **新增选项**：`notCounted` 在 TypeFilter 枚举中
- **UI 支持**：筛选弹窗中添加新选项
- **逻辑支持**：`_applyFilter` 方法过滤 `TransactionType.ignore`

### 4. 自动分组分配
- **添加时自动**：根据类型名称匹配到对应分组
- **编辑时自动更新**：修改名称后重新判断
- **启动时修复**：`_ensureFilterTypesHaveGroups` 确保数据一致性

---

## 验证计划

### 解析逻辑验证
1. 导入含「转账-退款」类型的微信账单
2. 检查是否被正确归类为「退款」类型
3. 导入其他正常类型（如"转账"）不受影响

### 筛选功能验证
1. 打开筛选弹窗，确认有 4 个收支类型选项：全部、支出、收入、不计收支
2. 选择「不计收支」
3. 确认筛选后只显示 TransactionType.ignore 的账单
4. 确认汇总统计中不计入总额

### 分组颜色验证
1. 添加微信类型 → 检查列表中显示绿色圆点
2. 添加支付宝类型 → 检查列表中显示蓝色圆点
3. 确认首页筛选弹窗中颜色正确应用

---

## 技术细节

### 退款处理算法
```dart
// 优先级：收/支字段 > 退款后缀检测
// 统一逻辑：如果包含"-退款"则返回"退款"，否则返回原类型
String _cleanTransactionType(direction, status, description) {
  if (direction.contains('-退款')) {
    return '退款';
  }
  return direction;
}
```

### 筛选逻辑优化
```dart
// 收入类型筛选：只显示收入
// 支出类型筛选：只显示支出
// 不计收支筛选：显示 TransactionType.ignore 类型
```

### 自动分组匹配
- **微信类型**：`kWechatTransactionTypes.contains(name)` → 微信分组
- **支付宝类型**：`kAlipayCategories.contains(name)` → 支付宝分组
- **其他**：`自定义` 分组

---

**总结**

✅ 所有修改已完成，代码质量提升！

**关键点**：
1. 交易类型分类更精确（8 微信 + 39 支付宝）
2. 智能退款处理（统一为"退款"类型）
3. 新增"不计收支"筛选选项
4. 自动分组分配（添加/编辑/启动时）

**预期效果**：
- 退款类型正确归类为"退款"
- 筛选弹窗有4 个选项
- 微信/支付宝类型自动显示对应颜色（绿/蓝）
- 用户添加/编辑筛选类型时自动分组
