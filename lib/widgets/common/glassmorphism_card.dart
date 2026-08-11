import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blur = 15.0,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(20.0),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    
    // Default semi-transparent glass colors with luxury gold border touches
    final defaultBgColor = isDark 
        ? const Color(0xFF141420).withValues(alpha: 0.7) 
        : Colors.white.withValues(alpha: 0.9);
    final defaultBorderColor = isDark 
        ? const Color(0xFFFFD700).withValues(alpha: 0.12) 
        : const Color(0xFFD4AF37).withValues(alpha: 0.18);

    Widget cardContent = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? defaultBgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? defaultBorderColor,
          width: 1.5,
        ),
      ),
      child: child,
    );

    if (!disableAnimations && blur > 0.0) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: cardContent,
        ),
      );
    } else {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      );
    }

    return RepaintBoundary(child: cardContent);
  }
}
