// lib/widgets/app_shimmer.dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Drop-in shimmer wrapper respecting the app palette.
/// Usage: AppShimmer(child: YourPlaceholderWidget())
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:      isDark ? AppColors.shimmerBase      : AppColors.shimmerBaseLt,
      highlightColor: isDark ? AppColors.shimmerHighlight : AppColors.shimmerHighLt,
      child: child,
    );
  }
}

/// Pre-built shimmer shapes for common skeleton layouts.
class ShimmerBox extends StatelessWidget {
  final double width, height, borderRadius;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(
      color: Colors.white, // shimmer replaces this
      borderRadius: BorderRadius.circular(borderRadius),
    ),
  );
}

class ShimmerTransactionTile extends StatelessWidget {
  const ShimmerTransactionTile({super.key});

  @override
  Widget build(BuildContext context) => const AppShimmer(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        ShimmerBox(width: 44, height: 44, borderRadius: 22),
        SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: double.infinity, height: 14),
            SizedBox(height: 6),
            ShimmerBox(width: 100, height: 12),
          ],
        )),
        SizedBox(width: 12),
        ShimmerBox(width: 64, height: 16),
      ]),
    ),
  );
}

class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

class ShimmerNetWorthBanner extends StatelessWidget {
  const ShimmerNetWorthBanner({super.key});

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Container(
      margin: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );
}
