import 'dart:convert';

enum TransactionType { expense, income, transfer, ignore }

/// 分类分组（用于视觉区分，如微信绿/支付宝蓝）
class CategoryGroup {
  CategoryGroup({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    this.isSystem = false,
  });

  final int id;
  final String name;
  /// 颜色值，存储为 ARGB 整数（如 0xFF4CAF50）
  final int color;
  final int sortOrder;
  final int createdAt;
  /// 是否为系统预置分组（微信、支付宝、自定义），系统分组不可改名、不可删除
  final bool isSystem;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'is_system': isSystem ? 1 : 0,
    };
  }

  static CategoryGroup fromMap(Map<String, Object?> map) {
    return CategoryGroup(
      id: map['id'] as int,
      name: map['name'] as String,
      color: map['color'] as int,
      sortOrder: map['sort_order'] as int,
      createdAt: map['created_at'] as int,
      isSystem: (map['is_system'] as int? ?? 0) == 1,
    );
  }
}

/// 自定义分类（用于账单分类/分析统计）
class CustomCategory {
  CustomCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    this.groupId,
  });

  final int id;
  final String name;
  final int sortOrder;
  final int createdAt;
  final int? groupId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'group_id': groupId,
    };
  }

  static CustomCategory fromMap(Map<String, Object?> map) {
    return CustomCategory(
      id: map['id'] as int,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      createdAt: map['created_at'] as int,
      groupId: map['group_id'] as int?,
    );
  }
}

/// 筛选类型（用于首页交易类型筛选）
class FilterType {
  FilterType({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    this.groupId,
  });

  final int id;
  final String name;
  final int sortOrder;
  final int createdAt;
  final int? groupId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'created_at': createdAt,
      'group_id': groupId,
    };
  }

  static FilterType fromMap(Map<String, Object?> map) {
    return FilterType(
      id: map['id'] as int,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      createdAt: map['created_at'] as int,
      groupId: map['group_id'] as int?,
    );
  }
}

class TransactionRecord {
  TransactionRecord({
    required this.id,
    this.source = 'Alipay',
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.counterparty,
    required this.description,
    required this.account,
    required this.originalData,
    this.category,
    this.transactionCategory,
    this.note,
  });

  final String id;
  final String source;
  final TransactionType type;
  final int amount;
  final int timestamp;
  final String counterparty;
  final String description;
  final String account;
  final String originalData;
  /// 消费分类（餐饮美食、服饰装扮等，用于分析统计）
  final String? category;
  /// 交易类型（商户消费、红包、网购等，用于筛选）
  final String? transactionCategory;
  /// 用户备注
  final String? note;

  /// 复制并修改部分字段
  TransactionRecord copyWith({
    String? category,
    String? note,
  }) {
    return TransactionRecord(
      id: id,
      source: source,
      type: type,
      amount: amount,
      timestamp: timestamp,
      counterparty: counterparty,
      description: description,
      account: account,
      originalData: originalData,
      category: category ?? this.category,
      transactionCategory: transactionCategory,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'source': source,
      'type': type.name.toUpperCase(),
      'amount': amount,
      'timestamp': timestamp,
      'counterparty': counterparty,
      'description': description,
      'account': account,
      'original_data': originalData,
      'category': category,
      'transaction_category': transactionCategory,
      'note': note,
    };
  }

  static TransactionRecord fromMap(Map<String, Object?> map) {
    return TransactionRecord(
      id: map['id'] as String,
      source: _normalizeSource(map['source'] as String? ?? 'Alipay'),
      type: _typeFromString(map['type'] as String),
      amount: map['amount'] as int,
      timestamp: map['timestamp'] as int,
      counterparty: map['counterparty'] as String,
      description: map['description'] as String,
      account: map['account'] as String,
      originalData: map['original_data'] as String,
      category: map['category'] as String?,
      transactionCategory: map['transaction_category'] as String?,
      note: map['note'] as String?,
    );
  }

  static String _normalizeSource(String value) {
    final upper = value.toUpperCase();
    if (upper == 'WECHAT') {
      return 'WeChat';
    }
    if (upper == 'ALIPAY') {
      return 'Alipay';
    }
    return value.isEmpty ? 'Alipay' : value;
  }

  static TransactionType _typeFromString(String value) {
    switch (value.toUpperCase()) {
      case 'EXPENSE':
        return TransactionType.expense;
      case 'INCOME':
        return TransactionType.income;
      case 'TRANSFER':
        return TransactionType.transfer;
      case 'IGNORE':
        return TransactionType.ignore;
    }
    return TransactionType.ignore;
  }
}

String encodeOriginalData(List<dynamic> row) {
  return jsonEncode(row);
}
