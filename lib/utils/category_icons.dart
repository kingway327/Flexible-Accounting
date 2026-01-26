import 'package:flutter/material.dart';

/// 分类图标映射
/// 包含所有 47 个系统分类的图标（微信 8 类 + 支付宝 39 类）
const Map<String, IconData> kCategoryIcons = {
  // 微信交易类型 (8 类)
  '商户消费': Icons.store_outlined,
  '红包': Icons.redeem_outlined,
  '转账': Icons.swap_horiz_outlined,
  '群收款': Icons.groups_outlined,
  '二维码收付款': Icons.qr_code_outlined,
  '充值提现': Icons.account_balance_wallet_outlined,
  '信用卡还款': Icons.credit_card_outlined,
  '退款': Icons.replay_outlined,

  // 支付宝 - 日常消费
  '餐饮美食': Icons.restaurant_outlined,
  '服饰装扮': Icons.checkroom_outlined,
  '日用百货': Icons.shopping_bag_outlined,
  '家居家装': Icons.home_outlined,
  '数码电器': Icons.devices_outlined,
  '运动户外': Icons.fitness_center_outlined,
  '美容美发': Icons.content_cut_outlined,
  '母婴亲子': Icons.child_care_outlined,
  '宠物': Icons.pets_outlined,
  '交通出行': Icons.directions_car_outlined,
  '爱车养车': Icons.car_repair_outlined,
  '住房物业': Icons.apartment_outlined,
  '酒店旅游': Icons.luggage_outlined,
  '文化休闲': Icons.local_movies_outlined,
  '教育培训': Icons.school_outlined,
  '医疗健康': Icons.local_hospital_outlined,
  '生活服务': Icons.miscellaneous_services_outlined,
  '公共服务': Icons.account_balance_outlined,
  '商业服务': Icons.business_outlined,
  '公益捐赠': Icons.volunteer_activism_outlined,
  '互助保障': Icons.health_and_safety_outlined,

  // 支付宝 - 金融
  '投资理财': Icons.trending_up_outlined,
  '保险': Icons.verified_user_outlined,
  '信用借还': Icons.credit_score_outlined,
  '充值缴费': Icons.payment_outlined,

  // 支付宝 - 转账相关
  '收入': Icons.arrow_downward_outlined,
  '转账红包': Icons.card_giftcard_outlined,
  '亲友代付': Icons.group_outlined,
  '账户存取': Icons.savings_outlined,

  // 其他
  '其他': Icons.more_horiz_outlined,
};

/// 获取分类图标（无匹配时返回默认图标）
///
/// 参数:
/// - [category] 分类名称
///
/// 返回: 对应的图标，如果没有匹配则返回默认图标 Icons.category_outlined
IconData getCategoryIcon(String category) {
  return kCategoryIcons[category] ?? Icons.category_outlined;
}

/// 获取分类图标 Widget（带颜色）
///
/// 参数:
/// - [category] 分类名称
/// - [size] 图标大小（默认 24）
/// - [color] 图标颜色（默认使用主题的 primary 颜色）
///
/// 返回: 包含图标的 Icon Widget
Icon getCategoryIconWidget(
  String category, {
  double size = 24,
  Color? color,
}) {
  return Icon(
    getCategoryIcon(category),
    size: size,
    color: color,
  );
}
