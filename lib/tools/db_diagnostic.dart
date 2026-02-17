import 'package:flutter/foundation.dart';
import 'package:local_first_finance/data/category_dao.dart';
import 'package:local_first_finance/data/database_helper.dart';
import 'package:local_first_finance/models/models.dart';

/// 数据库诊断和修复工具
/// 检查分组和筛选类型的状态，并自动修复
Future<void> main() async {
  debugPrint('========== 数据库诊断工具 ==========\n');

  final db = DatabaseHelper.instance;
  await db.database; // 确保数据库已初始化
  final categoryDao = CategoryDao.instance;

  // 1. 检查分组数据
  debugPrint('【1. 检查分组数据】');
  final groups = await categoryDao.fetchCategoryGroups();
  debugPrint('分组数量: ${groups.length}');
  for (final group in groups) {
    debugPrint(
      '  - ${group.name} (ID: ${group.id}, 颜色: 0x${group.color.toRadixString(16).padLeft(8, '0')}, 系统分组: ${group.isSystem})',
    );
  }
  debugPrint('');

  // 2. 检查筛选类型数据
  debugPrint('【2. 检查筛选类型数据】');
  final filterTypes = await categoryDao.fetchFilterTypes();
  debugPrint('筛选类型数量: ${filterTypes.length}');

  int noGroupCount = 0;
  int wechatGroupCount = 0;
  int alipayGroupCount = 0;

  // 微信交易类型列表
  final wechatTypes = {
    '商户消费',
    '红包',
    '转账',
    '群收款',
    '二维码收付款',
    '充值提现',
    '信用卡还款',
    '退款',
  };

  // 支付宝交易分类列表
  final alipayTypes = {
    '餐饮美食',
    '交通出行',
    '日用百货',
    '充值缴费',
    '转账红包',
    '投资理财',
    '生活服务',
  };

  for (final ft in filterTypes) {
    final groupName = groups
        .firstWhere(
          (g) => g.id == ft.groupId,
          orElse: () => CategoryGroup(
            id: -1,
            name: '无分组',
            color: 0xFF000000,
            sortOrder: 0,
            createdAt: 0,
            isSystem: false,
          ),
        )
        .name;

    if (ft.groupId == null) {
      noGroupCount++;
      debugPrint('  ⚠️  ${ft.name} - 未分配分组');
    } else {
      if (wechatTypes.contains(ft.name)) {
        wechatGroupCount++;
        debugPrint('  ✓ ${ft.name} - 分组: $groupName');
      } else if (alipayTypes.contains(ft.name)) {
        alipayGroupCount++;
        debugPrint('  ✓ ${ft.name} - 分组: $groupName');
      } else {
        debugPrint('  ℹ️  ${ft.name} - 分组: $groupName');
      }
    }
  }

  debugPrint('\n统计:');
  debugPrint('  未分配分组的筛选类型: $noGroupCount');
  debugPrint('  微信类型已正确分配: $wechatGroupCount');
  debugPrint('  支付宝类型已正确分配: $alipayGroupCount');
  debugPrint('');

  // 3. 检查分组ID映射
  debugPrint('【3. 检查分组ID】');
  final groupMap = {for (final g in groups) g.name: g.id};
  debugPrint('  微信分组ID: ${groupMap['微信']}');
  debugPrint('  支付宝分组ID: ${groupMap['支付宝']}');
  debugPrint('  自定义分组ID: ${groupMap['自定义']}');
  debugPrint('');

  // 4. 诊断结果和建议
  debugPrint('【4. 诊断结果】');
  final needsFix = noGroupCount > 0;

  if (!needsFix) {
    debugPrint('✅ 所有筛选类型都已正确分配到分组！');
    debugPrint('   颜色应该正常显示（微信绿色、支付宝蓝色）。');
  } else {
    debugPrint('⚠️  发现 $noGroupCount 个未分配分组的筛选类型！');
    debugPrint('');
    debugPrint('【5. 修复方案】');
    debugPrint('正在自动修复...');
    await _fixDatabase(categoryDao, groups, wechatTypes, alipayTypes);
    debugPrint('✅ 修复完成！');
  }

  debugPrint('\n========== 诊断结束 ==========');
}

/// 修复数据库数据
Future<void> _fixDatabase(
  CategoryDao dao,
  List<CategoryGroup> groups,
  Set<String> wechatTypes,
  Set<String> alipayTypes,
) async {
  final groupMap = {for (final g in groups) g.name: g.id};
  final wechatGroupId = groupMap['微信'];
  final alipayGroupId = groupMap['支付宝'];
  final customGroupId = groupMap['自定义'];

  final filterTypes = await dao.fetchFilterTypes();

  for (final ft in filterTypes) {
    int? targetGroupId;

    // 根据筛选类型名称决定分组
    if (wechatTypes.contains(ft.name) && wechatGroupId != null) {
      targetGroupId = wechatGroupId;
      debugPrint('  将「${ft.name}」分配到微信分组');
    } else if (alipayTypes.contains(ft.name) && alipayGroupId != null) {
      targetGroupId = alipayGroupId;
      debugPrint('  将「${ft.name}」分配到支付宝分组');
    } else if (ft.groupId == null) {
      targetGroupId = customGroupId;
      debugPrint('  将「${ft.name}」分配到自定义分组');
    }

    // 如果需要更新
    if (targetGroupId != null && ft.groupId != targetGroupId) {
      await dao.updateFilterTypeGroup(ft.id, targetGroupId);
    }
  }

  debugPrint('\n修复后重新检查...');
  final updatedFilterTypes = await dao.fetchFilterTypes();
  final stillNoGroup =
      updatedFilterTypes.where((ft) => ft.groupId == null).length;
  if (stillNoGroup == 0) {
    debugPrint('✅ 所有筛选类型现在都已分配到分组！');
  } else {
    debugPrint('⚠️  仍有 $stillNoGroup 个筛选类型未分配分组');
  }
}
