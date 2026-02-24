import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../../../CommonWidgets/globals.dart';

/// Visual hierarchy widget that displays an employee's reporting chain (manager → grand-manager → etc.).
///
/// Expects a list of employee maps in **top-down order** (index 0 = employee, last = top manager).
///
/// Visual style:
/// - Circular avatar (base64 image, network image, or first-letter placeholder)
/// - Name + job title
/// - Vertical connecting lines between levels
/// - No lines after the last (top) manager
class OrganizationChart extends StatelessWidget {
  /// Ordered list of employee maps from the chain (bottom → top)
  /// Each map should contain at least: 'name', optionally: 'job_title', 'image_1920'
  final List<Map<String, dynamic>> chain;

  const OrganizationChart({Key? key, required this.chain}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tr(
          "Organization Chart",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),

        // Render each level in the hierarchy
        ...List.generate(chain.length, (index) {
          final emp = chain[index];
          final bool isLast = index == chain.length - 1;
          final String name = emp["name"] ?? "Unknown";

          final String? imageUrl = emp["image_1920"] is String
              ? emp["image_1920"]
              : null;
          final String? jobTitle = emp["job_title"] is String
              ? emp["job_title"]
              : null;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical connecting line (only between levels)
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 24.0),
                      child: Column(
                        children: [
                          // Line coming down from previous node
                          Container(
                            width: 2,
                            height: 50,
                            color: AppStyle.primaryColor,
                          ),
                          // Small continuation line if not the last node
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 24,
                              color: AppStyle.primaryColor,
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),

                  // Avatar + name + job title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: buildImage(imageUrl, name: name),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  emp['name'] ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  jobTitle ?? "N/A",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Extra spacing after the employee (first) node
              if (index == 0) const SizedBox(height: 16),
            ],
          );
        }),
      ],
    );
  }

  /// Renders employee avatar — supports base64, network URL, or fallback placeholder
  Widget buildImage(String? img, {String? name}) {
    if (img == null || img.isEmpty) {
      return _placeholder(name);
    }

    final bool isBase64 = img.startsWith("data:image") || img.length > 500;

    if (isBase64) {
      try {
        // Extract base64 part if data URI
        final base64String = img.contains(",") ? img.split(",").last : img;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          height: 55,
          width: 55,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _placeholder(name),
        );
      } catch (e) {
        return _placeholder(name);
      }
    }

    // Assume network URL
    return Image.network(
      img,
      height: 55,
      width: 55,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(name),
    );
  }

  /// Fallback circular avatar with first letter or person icon
  Widget _placeholder(String? name) {
    final firstLetter = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : "";
    return Container(
      height: 55,
      width: 55,
      decoration: BoxDecoration(
        color: AppStyle.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(55 / 2),
      ),
      alignment: Alignment.center,
      child: firstLetter.isNotEmpty
          ? Text(
              firstLetter,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppStyle.primaryColor,
              ),
            )
          : const Icon(Icons.person, size: 30, color: AppStyle.primaryColor),
    );
  }
}
