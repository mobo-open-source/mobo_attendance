import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmering loading placeholder that mimics the layout of the employee details screen.
///
/// Used during initial data loading in `EmployeeFormPage` to provide a smooth,
/// skeleton-screen-like experience while the real employee data is being fetched.
///
/// Features:
/// - Dark/light theme aware shimmer colors
/// - Circular avatar placeholder
/// - Name/job/department placeholders
/// - Multiple horizontal shimmering lines simulating resume/skills/HR sections
/// - Responsive width (fills available space)
class ShimmerEmployeeDetails extends StatelessWidget {
  /// Whether dark mode is active (affects base/highlight colors)
  final bool isDark;

  const ShimmerEmployeeDetails({Key? key, required this.isDark}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Shimmer base color (background of placeholders)
    Color baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;

    // Shimmer highlight color (moving gradient that creates the shine effect)
    Color highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile header placeholder (avatar + name/job) ────────────────
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: baseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 20, color: baseColor),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 16, color: baseColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ── Generic content lines (simulate resume / skills / settings) ─────
            ...List.generate(6, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Section title placeholder
            Container(
              width: 100,
              height: 20,
              color: baseColor,
            ),
            const SizedBox(height: 8),
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  width: double.infinity,
                  height: 16,
                  color: baseColor,
                ),
              );
            }),

            const SizedBox(height: 24),

            // Another section title (e.g. "HR Settings")
            Container(width: 150, height: 20, color: baseColor),
            const SizedBox(height: 12),
            ...List.generate(4, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  width: double.infinity,
                  height: 16,
                  color: baseColor,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
