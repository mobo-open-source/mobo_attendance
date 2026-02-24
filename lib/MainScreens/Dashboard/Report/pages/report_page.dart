import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../bloc/report_bloc.dart';
import '../bloc/report_event.dart';
import '../bloc/report_state.dart';

/// Entry point widget for the Attendance Report / Analytics screen.
///
/// Simply delegates rendering to the stateful [ReportView].
class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReportView();
  }
}

/// Stateful UI for displaying attendance analytics / reports.
///
/// Features:
/// - Search by employee name
/// - Filter & grouping bottom sheet
/// - Measure selector (Worked Hours, Over Time, Latitude, etc.)
/// - View toggle (bar chart / line chart)
/// - Horizontal-scrollable chart with dynamic sizing
/// - Pagination controls (prev/next + range display)
/// - Loading shimmer + empty state with animation
/// - Scroll-to-bottom on new data load
class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  final ScrollController _verticalScrollController = ScrollController();

  /// Maps user-friendly group labels → technical group keys used in bloc
  static const Map<String, String> groupTechnicalNames = {
    "Check In": "check_in",
    "Employee": "employee",
    "Check Out": "check_out",
  };

  static Map<String, Map<String, String>> _digitMaps = {
    'ar': {
      '0': '٠',
      '1': '١',
      '2': '٢',
      '3': '٣',
      '4': '٤',
      '5': '٥',
      '6': '٦',
      '7': '٧',
      '8': '٨',
      '9': '٩',
    },
    'fa': {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    },
    'ur': {
      '0': '۰',
      '1': '۱',
      '2': '۲',
      '3': '۳',
      '4': '۴',
      '5': '۵',
      '6': '۶',
      '7': '۷',
      '8': '۸',
      '9': '۹',
    },
    'bn': {
      '0': '০',
      '1': '১',
      '2': '২',
      '3': '৩',
      '4': '৪',
      '5': '৫',
      '6': '৬',
      '7': '৭',
      '8': '৮',
      '9': '৯',
    },
    'th': {
      '0': '๐',
      '1': '๑',
      '2': '๒',
      '3': '๓',
      '4': '๔',
      '5': '๕',
      '6': '๖',
      '7': '๗',
      '8': '๘',
      '9': '๙',
    },
    'my': {
      '0': '၀',
      '1': '၁',
      '2': '၂',
      '3': '၃',
      '4': '၄',
      '5': '၅',
      '6': '၆',
      '7': '၇',
      '8': '၈',
      '9': '၉',
    },
  };

  /// Converts Latin digits (0-9) to locale-specific native digits
  String localeNumber(String input, String locale) {
    final code = locale.split('_').first.toLowerCase();
    final map = _digitMaps[code];
    if (map == null) return input;

    map.forEach((latin, native) {
      input = input.replaceAll(latin, native);
    });
    return input;
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Smoothly scrolls to the bottom of the vertical scroll view
  /// (used after new chart data loads)
  void _scrollToBottom() {
    if (_verticalScrollController.hasClients) {
      _verticalScrollController.animateTo(
        _verticalScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Opens bottom sheet for filter & group-by selection
  void _openFilterSheet(BuildContext context) {
    final reportBloc = context.read<ReportBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => FilterGroupBySheet(reportBloc: reportBloc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();
    final locale = translationService.currentCode;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: tr(
          "Attendance Report",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  context.read<ReportBloc>().add(UpdateSearchText(value));
                },
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  hintText: translationService.getCached('Search by Employee'),
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xff1E1E1E),
                    fontSize: 15,
                  ),
                  prefixIcon: IconButton(
                    icon: Icon(
                      HugeIcons.strokeRoundedFilterHorizontal,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 18,
                    ),
                    tooltip: translationService.getCached('Filter & Group By'),
                    onPressed: () => _openFilterSheet(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BlocBuilder<ReportBloc, ReportState>(
                builder: (context, state) {
                  final hasFilters = state.selectedFilters.isNotEmpty;
                  final hasGroupBy =
                      (state.selectedGroupByOptions?.isNotEmpty ?? false);

                  if (!hasFilters && !hasGroupBy) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: tr(
                        "No filters applied",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  String? groupDisplayName;
                  if (hasGroupBy &&
                      state.selectedGroupByOptions?.isNotEmpty == true) {
                    final selectedTech = state.selectedGroupByOptions!.first;
                    groupDisplayName = groupTechnicalNames.keys.firstWhere(
                      (key) => groupTechnicalNames[key] == selectedTech,
                      orElse: () => selectedTech,
                    );
                  }

                  return Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Row(
                          children: [
                            if (hasFilters)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white70 : Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      localeNumber(
                                        state.selectedFilters.length.toString(),
                                        locale,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    tr(
                                      "Active",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasGroupBy) ...[
                              if (hasFilters) const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white70 : Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      HugeIcons.strokeRoundedLayer,
                                      size: 16,
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    tr(
                                      groupDisplayName ?? "Group",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              BlocBuilder<ReportBloc, ReportState>(
                builder: (context, state) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          '${state.pageRange} / ${state.totalCount}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          HugeIcons.strokeRoundedArrowLeft01,
                          size: 25,
                          color: state.currentPage > 0
                              ? (isDark ? Colors.white70 : Colors.black87)
                              : (isDark
                                    ? Colors.grey[800]
                                    : Colors.grey.withOpacity(0.7)),
                        ),
                        onPressed: state.currentPage > 0
                            ? () => context.read<ReportBloc>().add(
                                LoadGraphData(page: state.currentPage - 1),
                              )
                            : null,
                      ),
                      IconButton(
                        icon: Icon(
                          HugeIcons.strokeRoundedArrowRight01,
                          size: 25,
                          color:
                              (state.currentPage + 1) * state.itemsPerPage <
                                  state.totalCount
                              ? (isDark ? Colors.white70 : Colors.black87)
                              : (isDark
                                    ? Colors.grey[800]
                                    : Colors.grey.withOpacity(0.7)),
                        ),
                        onPressed:
                            (state.currentPage + 1) * state.itemsPerPage <
                                state.totalCount
                            ? () => context.read<ReportBloc>().add(
                                LoadGraphData(page: state.currentPage + 1),
                              )
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),

          // Measure selector + view toggle (bar/line)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BlocBuilder<ReportBloc, ReportState>(
                  builder: (context, state) {
                    return Container(
                      height: 45,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? Colors.grey[500]! : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          value: state.selectedMeasure,

                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 13,
                          ),

                          onChanged: (value) {
                            if (value != null) {
                              context.read<ReportBloc>().add(
                                UpdateMeasure(value),
                              );
                            }
                          },
                          buttonStyleData: const ButtonStyleData(
                            height: 42,
                            padding: EdgeInsets.only(left: 0, right: 6),
                          ),
                          iconStyleData: const IconStyleData(
                            icon: Icon(Icons.keyboard_arrow_down, size: 16),
                            iconSize: 16,
                          ),

                          dropdownStyleData: DropdownStyleData(
                            maxHeight: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isDark ? Colors.grey[900] : Colors.white,
                            ),
                          ),

                          items:
                              const [
                                'Latitude',
                                'Longitude',
                                'Out Latitude',
                                'Out Longitude',
                                'Over Time',
                                'Worked Hours',
                              ].map((measure) {
                                return DropdownMenuItem<String>(
                                  value: measure,
                                  child: Transform.translate(
                                    offset: const Offset(-6, 0),
                                    child: tr(measure),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                BlocBuilder<ReportBloc, ReportState>(
                  builder: (context, state) {
                    return Row(
                      children: [
                        _viewIcon(
                          icon: Icons.bar_chart,
                          selected: state.selectedView == 'bar',
                          onTap: () => context.read<ReportBloc>().add(
                            const UpdateView('bar'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _viewIcon(
                          icon: HugeIcons.strokeRoundedChartLineData03,
                          selected: state.selectedView == 'line',
                          onTap: () => context.read<ReportBloc>().add(
                            const UpdateView('line'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Main chart area
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 0.0,
            ),
            child: SizedBox(
              height: 550,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black26
                          : Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: BlocBuilder<ReportBloc, ReportState>(
                  builder: (context, state) {
                    if (!state.isLoading && state.graphData.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _scrollToBottom();
                      });
                    }
                    if (state.isLoading) {
                      return Center(
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 50,
                        ),
                      );
                    }
                    if (state.graphData.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/empty_ghost.json',
                              width: 300,
                              height: 300,
                              fit: BoxFit.contain,
                              repeat: true,
                              animate: true,
                            ),
                            tr(
                              'No records found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            if (state.selectedFilters.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              tr(
                                'Try adjusting your filter',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () {
                                  context.read<ReportBloc>().add(
                                    ClearAllFiltersAndGroupBy(),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? Colors.white
                                      : AppStyle.primaryColor,
                                  side: BorderSide(
                                    color: isDark
                                        ? Colors.grey[600]!
                                        : AppStyle.primaryColor.withOpacity(
                                            0.3,
                                          ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: tr(
                                  'Clear All Filters',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: _verticalScrollController,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Column(
                                    children: [
                                      SizedBox(height: 10),
                                      ReportChart(state: state),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reusable view toggle icon (bar / line)
  Widget _viewIcon({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : isDark
              ? Colors.grey[850]
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[500]! : Colors.grey[300]!),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

/// Renders the main attendance chart (bar or line) based on current state.
///
/// Dynamically sizes horizontally based on data length.
/// Handles different measures (Worked Hours, Over Time, Latitude, etc.).
/// Calculates appropriate Y-axis range and formats X-axis labels.
class ReportChart extends StatelessWidget {
  final ReportState state;

  const ReportChart({super.key, required this.state});

  /// Safely converts any value to double (handles null, bool, int, String, etc.)
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is bool) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Extracts the numeric value for the selected measure from a data item
  double getMeasureValue(Map<String, dynamic> item, String measure) {
    switch (measure) {
      case 'Worked Hours':
        return _toDouble(item['worked_hours_sum'] ?? item['worked_hours']);
      case 'Over Time':
        return _toDouble(item['overtime_hours_sum'] ?? item['overtime_hours']);
      case 'Latitude':
        return _toDouble(item['in_latitude_avg'] ?? item['in_latitude']);
      case 'Out Latitude':
        return _toDouble(item['out_latitude_avg'] ?? item['out_latitude']);
      case 'Longitude':
        return _toDouble(item['in_longitude_avg'] ?? item['in_longitude']);
      case 'Out Longitude':
        return _toDouble(item['out_longitude_avg'] ?? item['out_longitude']);
      default:
        return _toDouble(item['__count'] ?? item['employee_id_count']);
    }
  }

  /// Determines reasonable min/max Y-axis values based on data and measure type
  ({double minY, double maxY}) getChartYAxisRange() {
    if (state.graphData.isEmpty) return (minY: 0, maxY: 10);
    final isGeoMeasure = [
      'Latitude',
      'Out Latitude',
      'Longitude',
      'Out Longitude',
    ].contains(state.selectedMeasure);
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (var item in state.graphData) {
      double val = getMeasureValue(item, state.selectedMeasure);
      if (val < minVal) minVal = val;
      if (val > maxVal) maxVal = val;
    }
    if (isGeoMeasure) {
      double padding = (maxVal - minVal).abs() * 0.1;
      if (padding == 0) padding = 1;
      return (minY: minVal - padding, maxY: maxVal + padding);
    } else {
      return (minY: 0, maxY: maxVal * 1.2 > 0 ? maxVal * 1.2 : 10);
    }
  }

  /// Generates readable X-axis label from data item
  /// (employee name or formatted date based on grouping unit)
  String getXAxisLabel(Map<String, dynamic> item) {
    // Employee grouping
    if (item.containsKey('employee_id') &&
        item['employee_id'] is List &&
        item['employee_id'].length >= 2) {
      return item['employee_id'][1].toString();
    }

    // Date grouping
    for (final entry in item.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key.startsWith('check_in:') || key.startsWith('check_out:')) {
        final parts = key.split(':');
        if (parts.length != 2) continue;
        final unit = parts[1];
        switch (unit) {
          case 'year':
            return value.toString();
          case 'quarter':
            return value.toString();
          case 'month':
            if (value is String && value.contains('-')) {
              final ym = value.split('-');
              final year = ym[0];
              final month = int.tryParse(ym[1]) ?? 1;
              const months = [
                '',
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec',
              ];
              return '${months[month]} $year';
            }
            return value.toString();
          case 'week':
            return 'Week $value';
          case 'day':
            if (value is String && value.contains('-')) {
              final parts = value.split('-');
              final month = int.parse(parts[1]);
              final day = int.parse(parts[2]);
              const months = [
                '',
                'Jan',
                'Feb',
                'Mar',
                'Apr',
                'May',
                'Jun',
                'Jul',
                'Aug',
                'Sep',
                'Oct',
                'Nov',
                'Dec',
              ];
              return '$day ${months[month]}';
            }
            return value.toString();
        }
      }
    }
    return 'Unknown';
  }

  /// Generates gradient-like shade for bars (darker for later indices)
  Color getPrimaryShade(int index, int total, bool isDark) {
    final double opacity = 0.8 + (0.6 * (index / total));
    final color = isDark
        ? Colors.white.withOpacity(opacity.clamp(0.8, 1.0))
        : AppStyle.primaryColor.withOpacity(opacity.clamp(0.8, 1.0));

    return color;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double itemWidth = 80.0;
    final mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double horizontalPadding = 52.0;
    final double availableWidth = screenWidth - horizontalPadding;
    final double dataBasedWidth = state.graphData.length * itemWidth;
    final double chartWidth = dataBasedWidth > availableWidth
        ? dataBasedWidth
        : availableWidth;

    switch (state.selectedView) {
      case 'bar':
        return SizedBox(
          width: chartWidth,
          height: 500,
          child: BarChart(_buildBarChartData(isDark)),
        );
      case 'line':
        return SizedBox(
          width: chartWidth + 50,
          height: 500,
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: LineChart(_buildLineChartData(isDark)),
          ),
        );
      default:
        return Center(child: tr("No chart available"));
    }
  }

  /// Builds data configuration for bar chart view
  BarChartData _buildBarChartData(bool isDark) {
    final yRange = getChartYAxisRange();
    return BarChartData(
      minY: yRange.minY,
      maxY: yRange.maxY,
      barGroups: List.generate(state.graphData.length, (index) {
        final item = state.graphData[index];
        final double value = getMeasureValue(item, state.selectedMeasure);
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              width: 30,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
                bottom: Radius.zero,
              ),
              color: isDark ? Colors.white : AppStyle.primaryColor,
            ),
          ],
        );
      }),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= state.graphData.length)
                return const SizedBox.shrink();
              final name = getXAxisLabel(state.graphData[index]);
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 8,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            interval: (yRange.maxY - yRange.minY) / 5,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 8,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: (yRange.maxY - yRange.minY) / 5,
        getDrawingHorizontalLine: (value) => FlLine(
          color: isDark
              ? Colors.grey.shade700.withOpacity(0.5)
              : Colors.grey.shade400.withOpacity(0.7),
          strokeWidth: 1.0,
          dashArray: [7, 5],
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
            width: 1,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
            width: 1,
          ),
          top: BorderSide.none,
          right: BorderSide.none,
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final item = state.graphData[group.x];
            final name = getXAxisLabel(item);
            final val = getMeasureValue(item, state.selectedMeasure);
            return BarTooltipItem(
              '$name\n${state.selectedMeasure}: ${val.toStringAsFixed(2)}',
              TextStyle(color: Colors.white),
            );
          },
        ),
      ),
    );
  }

  /// Builds data configuration for line chart view
  LineChartData _buildLineChartData(bool isDark) {
    final yRange = getChartYAxisRange();
    final List<FlSpot> spots = List.generate(state.graphData.length, (i) {
      return FlSpot(
        i.toDouble(),
        getMeasureValue(state.graphData[i], state.selectedMeasure),
      );
    });

    final LineChartBarData line = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: isDark
          ? Colors.white.withOpacity(0.6)
          : AppStyle.primaryColor.withOpacity(0.6),
      barWidth: 1,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: isDark ? Colors.white : AppStyle.primaryColor,
          strokeWidth: 1,
          strokeColor: Colors.white,
        ),
      ),
    );

    return LineChartData(
      minY: yRange.minY,
      maxY: yRange.maxY,
      lineBarsData: [line],
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        horizontalInterval: (yRange.maxY - yRange.minY) / 5,
        getDrawingHorizontalLine: (value) => FlLine(
          color: isDark
              ? Colors.grey.shade700.withOpacity(0.5)
              : Colors.grey.shade400.withOpacity(0.7),
          strokeWidth: 1.0,
          dashArray: [7, 5],
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
            width: 1,
          ),
          bottom: BorderSide(
            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
            width: 1,
          ),
          top: BorderSide.none,
          right: BorderSide.none,
        ),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 60,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= state.graphData.length)
                return const SizedBox.shrink();
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  getXAxisLabel(state.graphData[index]),
                  style: TextStyle(
                    fontSize: 8,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            interval: (yRange.maxY - yRange.minY) / 5,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 8,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              final label = getXAxisLabel(state.graphData[index]);
              final value = spot.y;
              return LineTooltipItem(
                '$label\n${state.selectedMeasure}: ${value.toStringAsFixed(1)}',
                TextStyle(color: Colors.white),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting filters & grouping options in the report screen.
///
/// Uses temporary states in the bloc for preview-before-apply behavior.
class FilterGroupBySheet extends StatelessWidget {
  final ReportBloc reportBloc;

  const FilterGroupBySheet({super.key, required this.reportBloc});

  static const Map<String, String> filterTechnicalNames = {
    "My Attendance": "my_attendance",
    "My Team": "my_team",
    "At Work": "at_work",
    "Errors": "errors",
    "Last 7 Days": "last_7_days",
  };

  static const Map<String, String> groupTechnicalNames = {
    "Check In": "check_in",
    "Employee": "employee",
    "Check Out": "check_out",
  };

  static const Map<String, String> dateUnits = {
    "Year": "year",
    "Quarter": "quarter",
    "Month": "month",
    "Week": "week",
    "Day": "day",
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final translationService = context.read<LanguageProvider>();

    return DefaultTabController(
      length: 2,
      child: BlocProvider.value(
        value: reportBloc,
        child: BlocBuilder<ReportBloc, ReportState>(
          builder: (context, state) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232323) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                tr(
                                  'Filter & Group By',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black54,
                                  ),
                                  splashRadius: 20,
                                ),
                              ],
                            ),
                          ),

                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TabBar(
                              indicator: BoxDecoration(
                                color: isDark
                                    ? Color(0xFF2A2A2A)
                                    : AppStyle.primaryColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Color(0xFF2A2A2A).withOpacity(0.3)
                                        : AppStyle.primaryColor.withOpacity(
                                            0.3,
                                          ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              indicatorPadding: const EdgeInsets.all(4),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelColor: Colors.white,
                              unselectedLabelColor: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              unselectedLabelStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                              tabs: [
                                Tab(
                                  height: 48,
                                  text: translationService.getCached('Filter'),
                                ),
                                Tab(
                                  height: 48,
                                  text: translationService.getCached(
                                    'Group By',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: TabBarView(
                              children: [
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(20),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: filterTechnicalNames.keys.map((
                                      label,
                                    ) {
                                      final tech = filterTechnicalNames[label]!;
                                      final selected = state.selectedFilters
                                          .contains(tech);
                                      return FilterChip(
                                        label: tr(
                                          label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: selected
                                                ? Colors.white
                                                : (isDark
                                                      ? Colors.white70
                                                      : Colors.black87),
                                          ),
                                        ),
                                        selected: selected,
                                        selectedColor: isDark
                                            ? Color(0xFF131313)
                                            : AppStyle.primaryColor,
                                        backgroundColor: isDark
                                            ? const Color(0xFF2A2A2A)
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        checkmarkColor: Colors.white,
                                        onSelected: (val) {
                                          final newFilters = List<String>.from(
                                            state.selectedFilters,
                                          );
                                          if (val) {
                                            newFilters.add(tech);
                                          } else {
                                            newFilters.remove(tech);
                                          }
                                          reportBloc.add(
                                            UpdateFilters(newFilters),
                                          );
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),

                                ListView(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  children: groupTechnicalNames.keys.map((
                                    label,
                                  ) {
                                    final tech = groupTechnicalNames[label]!;
                                    final isSelected = state
                                        .selectedGroupByOptions
                                        .contains(tech);

                                    if (label == "Check In" ||
                                        label == "Check Out") {
                                      final isCheckIn = label == "Check In";
                                      final currentUnits = isCheckIn
                                          ? state.selectedCheckInUnits
                                          : state.selectedCheckOutUnits;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              reportBloc.add(
                                                UpdateGroupBy(
                                                  groupBy: tech,
                                                  unit: 'day',
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                                left: 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isSelected
                                                        ? Icons
                                                              .radio_button_checked
                                                        : Icons
                                                              .radio_button_unchecked,
                                                    color: isSelected
                                                        ? (isDark
                                                              ? Colors.white
                                                              : AppStyle
                                                                    .primaryColor)
                                                        : Colors.grey,
                                                    size: 22,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  tr(
                                                    label,
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black87,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            ...dateUnits.keys.map((unitLabel) {
                                              final unitTech =
                                                  dateUnits[unitLabel]!;
                                              final unitSelected = currentUnits
                                                  .contains(unitTech);
                                              return GestureDetector(
                                                onTap: () {
                                                  reportBloc.add(
                                                    UpdateGroupBy(
                                                      groupBy: tech,
                                                      unit: unitTech,
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 18,
                                                      ),
                                                  margin: const EdgeInsets.only(
                                                    bottom: 6,
                                                    left: 40,
                                                  ),

                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        unitSelected
                                                            ? Icons
                                                                  .radio_button_checked
                                                            : Icons
                                                                  .radio_button_unchecked,
                                                        color: unitSelected
                                                            ? (isDark
                                                                  ? Colors.white
                                                                  : AppStyle
                                                                        .primaryColor)
                                                            : Colors.grey,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      tr(
                                                        unitLabel,
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black87,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                        ],
                                      );
                                    }

                                    return GestureDetector(
                                      onTap: () {
                                        reportBloc.add(
                                          const UpdateGroupBy(
                                            groupBy: 'employee',
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                          left: 12,
                                        ),

                                        child: Row(
                                          children: [
                                            Icon(
                                              isSelected
                                                  ? Icons.radio_button_checked
                                                  : Icons
                                                        .radio_button_unchecked,
                                              color: isSelected
                                                  ? (isDark
                                                        ? Colors.white
                                                        : AppStyle.primaryColor)
                                                  : Colors.grey,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            tr(
                                              label,
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[850]
                                  : Colors.grey[50],
                              border: Border(
                                top: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[200]!,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      reportBloc.add(
                                        ClearAllFiltersAndGroupBy(),
                                      );
                                      Navigator.pop(context);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.grey[600]!
                                            : Colors.grey[300]!,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: tr(
                                      'Clear All',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      reportBloc.add(
                                        const LoadGraphData(page: 0),
                                      );
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: tr(
                                      'Apply',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.black
                                            : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (state.filterLoading)
                        Center(
                          child: LoadingAnimationWidget.staggeredDotsWave(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            size: 50,
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
