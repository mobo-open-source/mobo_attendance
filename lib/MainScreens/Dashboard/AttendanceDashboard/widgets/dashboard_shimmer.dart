import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmering placeholder UI that mimics the layout of the Attendance Dashboard
/// while real data is being loaded.
///
/// Displays skeleton placeholders for:
/// - Header card (greeting + profile picture)
/// - Check-in/out button
/// - Statistics cards (hours, check-in time, etc.)
/// - Recent activity list
///
/// Automatically adapts colors based on dark/light theme.
class DashboardShimmer extends StatelessWidget {
  /// Whether the app is currently in dark mode
  final bool isDark;

  const DashboardShimmer({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Shimmer base/highlight colors optimized for dark & light themes
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 16),
            _button(),
            const SizedBox(height: 16),
            _statsRow(),
            const SizedBox(height: 16),
            _statsRow(),
            const SizedBox(height: 16),
            _list(),
          ],
        ),
      ),
    );
  }

  /// Reusable gray rectangle placeholder
  Widget _box({double height = 20, double width = double.infinity}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// Placeholder for the top greeting + profile avatar section
  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(height: 18, width: 180),
                const SizedBox(height: 8),
                _box(height: 14, width: 220),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const CircleAvatar(radius: 30, backgroundColor: Colors.white),
        ],
      ),
    );
  }

  /// Placeholder for the large Check In / Check Out button
  Widget _button() => _box(height: 52);

  /// Placeholder for a row containing two statistic cards
  /// (e.g. Hours + Check In time, or Present + Absent in admin view)
  Widget _statsRow() {
    return Row(
      children: [
        Expanded(child: _box(height: 110)),
        const SizedBox(width: 16),
        Expanded(child: _box(height: 110)),
      ],
    );
  }

  /// Placeholder for the "Recent Activity" list
  /// (shows 3 fake activity items with avatar + text lines)
  Widget _list() {
    return Column(
      children: List.generate(
        3,
            (_) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const CircleAvatar(radius: 18, backgroundColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _box(height: 14, width: 160),
                    const SizedBox(height: 6),
                    _box(height: 12, width: 220),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
