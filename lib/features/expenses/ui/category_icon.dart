import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/expense.dart';

extension ExpenseCategoryIcon on ExpenseCategory {
  IconData get icon => switch (this) {
    ExpenseCategory.lodging => Icons.hotel_outlined,
    ExpenseCategory.food => Icons.restaurant_outlined,
    ExpenseCategory.transport => Icons.directions_car_outlined,
    ExpenseCategory.cafe => Icons.local_cafe_outlined,
    ExpenseCategory.drink => Icons.sports_bar_outlined,
    ExpenseCategory.activity => Icons.star_outline,
    ExpenseCategory.shopping => Icons.shopping_bag_outlined,
    ExpenseCategory.etc => Icons.category_outlined,
  };
}

/// 지출 목록 앞의 카테고리 아이콘 칸.
class CategoryTile extends StatelessWidget {
  const CategoryTile(this.category, {super.key});

  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: ToriColors.tile,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(category.icon, size: 22, color: ToriColors.acornCap),
    );
  }
}
