import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/hardware_config.dart';

/// 盲文板点阵可视化
///
/// 按照硬件规格绘制竖 27 点 × 横 24 点的盲文板。
/// 每个盲文字符由 2 列 × 3 行共 6 点组成，字符间留出间隔。
/// [litDots] 为已打印（点亮）的点位集合，行主序索引：row * cols + col。
class BrailleBoardView extends StatelessWidget {
  final Set<int> litDots;
  final bool showBorder;

  const BrailleBoardView({super.key, required this.litDots, this.showBorder = true});

  static const int cols = HardwareConfig.boardDotColumns;
  static const int rows = HardwareConfig.boardDotRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: cols / rows,
      child: CustomPaint(
        painter: _BrailleBoardPainter(
          litDots: litDots,
          litColor: theme.colorScheme.primary,
          dotColor: theme.colorScheme.onSurface.withValues(alpha: 0.18),
          boardBg: theme.colorScheme.surfaceContainerHighest,
          showBorder: showBorder,
        ),
      ),
    );
  }
}

class _BrailleBoardPainter extends CustomPainter {
  final Set<int> litDots;
  final Color litColor;
  final Color dotColor;
  final Color boardBg;
  final bool showBorder;

  _BrailleBoardPainter({
    required this.litDots,
    required this.litColor,
    required this.dotColor,
    required this.boardBg,
    required this.showBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cols = BrailleBoardView.cols;
    final rows = BrailleBoardView.rows;
    final charsPerRow = cols ~/ 2; // 每字符 2 列
    final charRows = rows ~/ 3; // 每字符 3 行

    // 字符内点间距与字符间距
    const dotGapFactor = 0.30; // 字符内点间距 = 点径的倍数
    const charGapFactor = 0.55; // 字符间距 = 点径的倍数

    // 计算点径: 让整体容纳在 size 内
    // 单字符横向占 2 点径 + 1 内间隙
    // 所有字符横向总占: charsPerRow*(2+dotGapFactor) + (charsPerRow-1)*charGapFactor 个点径
    final unitX = charsPerRow * (2 + dotGapFactor) + max(0, charsPerRow - 1) * charGapFactor;
    final unitY = charRows * (3 + dotGapFactor) + max(0, charRows - 1) * charGapFactor;

    final r = min(size.width / unitX, size.height / unitY);
    final dotRadius = r * 0.5;
    final startX = (size.width - unitX * r) / 2 + dotRadius;
    final startY = (size.height - unitY * r) / 2 + dotRadius;

    // 画板背景
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r * 1.2)),
      Paint()..color = boardBg,
    );
    if (showBorder) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          Radius.circular(r * 1.2),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.black.withValues(alpha: 0.12),
      );
    }

    final litPaint = Paint()..color = litColor;
    final dotPaint = Paint()..color = dotColor;

    for (var row = 0; row < rows; row++) {
      final charRow = row ~/ 3;
      final inCharRow = row % 3;
      final y = startY + r * (charRow * (3 + dotGapFactor) + inCharRow);

      for (var col = 0; col < cols; col++) {
        final charCol = col ~/ 2;
        final inCharCol = col % 2;
        final x = startX + r * (charCol * (2 + dotGapFactor) + inCharCol);

        final idx = row * cols + col;
        final lit = litDots.contains(idx);
        canvas.drawCircle(Offset(x, y), dotRadius, lit ? litPaint : dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BrailleBoardPainter oldDelegate) {
    return oldDelegate.litDots != litDots ||
        oldDelegate.litColor != litColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.boardBg != boardBg ||
        oldDelegate.showBorder != showBorder;
  }
}
