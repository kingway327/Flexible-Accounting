// 分类常量定义
// 微信和支付宝的交易分类常量，用于分类筛选和数据处理。

/// Google Material Design 颜色列表 (500 shades)
const List<int> kGoogleColors = [
  0xFFF44336, // Red
  0xFFE91E63, // Pink
  0xFF9C27B0, // Purple
  0xFF673AB7, // Deep Purple
  0xFF3F51B5, // Indigo
  0xFF2196F3, // Blue
  0xFF03A9F4, // Light Blue
  0xFF00BCD4, // Cyan
  0xFF009688, // Teal
  0xFF4CAF50, // Green
  0xFF8BC34A, // Light Green
  0xFFCDDC39, // Lime
  0xFFFFEB3B, // Yellow
  0xFFFFC107, // Amber
  0xFFFF9800, // Orange
  0xFFFF5722, // Deep Orange
  0xFF795548, // Brown
  0xFF9E9E9E, // Grey
  0xFF607D8B, // Blue Grey
];

/// 微信交易类型（8 类，包含退款处理）
const List<String> kWechatTransactionTypes = [
  '商户消费',
  '红包',
  '转账',
  '群收款',
  '二维码收付款',
  '充值提现',
  '信用卡还款',
  '退款',
];

/// 支付宝交易分类（39 类）
const List<String> kAlipayCategories = [
  // 日常消费
  '餐饮美食',
  '服饰装扮',
  '日用百货',
  '家居家装',
  '数码电器',
  '运动户外',
  '美容美发',
  '母婴亲子',
  '宠物',
  '交通出行',
  '爱车养车',
  '住房物业',
  '酒店旅游',
  '文化休闲',
  '教育培训',
  '医疗健康',
  '生活服务',
  '公共服务',
  '商业服务',
  '公益捐赠',
  '互助保障',
  // 金融
  '投资理财',
  '保险',
  '信用借还',
  '充值缴费',
  // 转账相关
  '收入',
  '转账红包',
  '亲友代付',
  '账户存取',
  '退款',
  // 其他
  '其他',
];

/// 所有系统分类（微信 8 类 + 支付宝 39 类 = 47 类）
const List<String> kSystemCategories = [
  ...kWechatTransactionTypes,
  ...kAlipayCategories,
];

const List<String> kSpendingCategories = kSystemCategories;
