import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import '../../../../CommonWidgets/core/language/translate_widget.dart';
import '../../../../CommonWidgets/core/providers/language_provider.dart';
import '../../../../CommonWidgets/core/providers/motion_provider.dart';
import '../../../../CommonWidgets/globals.dart';
import '../../../../CommonWidgets/shared/widgets/snackbar.dart';
import '../../../../Rating/review_service.dart';
import '../../../AppBars/pages/common_app_bar.dart';
import '../bloc/request_absence_bloc.dart';
import '../bloc/request_absence_event.dart';
import '../bloc/request_absence_state.dart';
import '../widgets/absence_create_info.dart';

/// Entry point widget for the "Request Absence / Leave" feature.
///
/// Delegates rendering to the stateful [RequestAbsenceView].
class RequestAbsencePage extends StatelessWidget {
  const RequestAbsencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RequestAbsenceView();
  }
}

/// Stateful UI for creating a new absence/leave request.
///
/// Features:
/// - Select leave type (with dynamic UI: half-day, custom hours, file upload)
/// - Date range picker with auto duration calculation
/// - Half-day (AM/PM) and custom hours support
/// - Description input
/// - File attachment (supporting document)
/// - Submit button with loading & success/error feedback
/// - Form reset on success + navigation back to dashboard
class RequestAbsenceView extends StatefulWidget {
  const RequestAbsenceView({super.key});

  @override
  State<RequestAbsenceView> createState() => _RequestAbsenceViewState();
}

class _RequestAbsenceViewState extends State<RequestAbsenceView> {
  final TextEditingController _dateFromController = TextEditingController();
  final TextEditingController _dateToController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final RequestAbsenceBloc _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bloc = context.read<RequestAbsenceBloc>();
  }

  @override
  void dispose() {
    // Reset bloc state when leaving the page
    _bloc.add(ResetRequestAbsence());

    _dateFromController.dispose();
    _dateToController.dispose();
    _durationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context);
    final translationService = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: tr(
          "Request Absence",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocConsumer<RequestAbsenceBloc, RequestAbsenceState>(
        listener: (context, state) {
          // Sync text controllers with bloc state

          _dateFromController.value = _dateFromController.value.copyWith(
            text: state.dateFrom,
          );

          _dateToController.value = _dateToController.value.copyWith(
            text: state.dateTo,
          );

          _durationController.value = _durationController.value.copyWith(
            text: state.durationDays,
          );

          _descriptionController.value = _descriptionController.value.copyWith(
            text: state.description,
          );

          // Handle success: show snackbar + navigate back to dashboard
          if (state.success) {
            CustomSnackbar.showSuccess(context, "Leave created successfully");
            Future.delayed(const Duration(seconds: 3), () {
              ReviewService().checkAndShowRating(context);
            });
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) =>
                    const CommonAppBar(initialIndex: 0),
                transitionDuration: motionProvider.reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                transitionsBuilder: (_, animation, __, child) {
                  if (motionProvider.reduceMotion) return child;
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }

          // Show error snackbar if present
          if (state.errorMessage != null) {
            CustomSnackbar.showError(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tr(
                    "Time Off Type",
                    style: TextStyle(
                      fontFamily: TextStyle(
                        fontWeight: FontWeight.w400,
                      ).fontFamily,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AbsenceCreateInfo(
                    label: "Time Off Type",
                    value: "Select Time Off Type",
                    prefixIcon: HugeIcons.strokeRoundedPhoneOff02,
                    dropdownItems: state.leaveTypes,
                    selectedId: state.selectedHolidayStatusId,
                    isEditing: true,
                    onDropdownChanged: (value) {
                      if (value != null) {
                        context.read<RequestAbsenceBloc>().add(
                          SelectLeaveType(value['id']),
                        );
                      }
                    },
                    validator: (_) => state.selectedHolidayStatusId == null
                        ? "${translationService.getCached("Required")}"
                        : null,
                  ),
                  const SizedBox(height: 12),

                  tr(
                    "Dates",
                    style: TextStyle(
                      fontFamily: TextStyle(
                        fontWeight: FontWeight.w400,
                      ).fontFamily,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AbsenceCreateInfo(
                          label: "Start Date",
                          prefixIcon: HugeIcons.strokeRoundedCalendar03,
                          value: state.dateFrom,
                          controller: _dateFromController,
                          isEditing: true,
                          isDateInput: true,
                          onDateChanged: (date) {
                            context.read<RequestAbsenceBloc>().add(
                              UpdateDateFrom(date),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Conditional half-day or end date field
                      if (state.isHalfDay && !state.isCustomHours)
                        Expanded(
                          child: AbsenceCreateInfo(
                            label: "Half Day Type",
                            value: state.halfDayType == 'am'
                                ? "Morning"
                                : "Evening",
                            isEditing: true,
                            selection: [
                              {"id": "am", "name": "Morning"},
                              {"id": "pm", "name": "Evening"},
                            ],
                            selectedKey: state.halfDayType,
                            onSelectionChanged: (val) {
                              context.read<RequestAbsenceBloc>().add(
                                UpdateHalfDayType(val!),
                              );
                            },
                          ),
                        )
                      else if (!state.isHalfDay && !state.isCustomHours)
                        Expanded(
                          child: AbsenceCreateInfo(
                            label: "End Date",
                            prefixIcon: HugeIcons.strokeRoundedCalendar03,
                            value: state.dateTo,
                            controller: _dateToController,
                            isEditing: true,
                            isDateInput: true,
                            onDateChanged: (date) {
                              context.read<RequestAbsenceBloc>().add(
                                UpdateDateTo(date),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Custom hours section (if enabled)
                  if (state.isCustomHours)
                    Row(
                      children: [
                        Expanded(
                          child: AbsenceCreateInfo(
                            label: "From",
                            value: state.hourFrom ?? "Select",
                            isEditing: true,
                            selection: List.generate(40, (i) {
                              double v = i * 0.5;
                              return {
                                "id": v.toStringAsFixed(1),
                                "name": _formatHour(v),
                              };
                            }),
                            selectedKey: state.hourFrom,
                            onSelectionChanged: (val) {
                              context.read<RequestAbsenceBloc>().add(
                                UpdateHourFrom(val!),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AbsenceCreateInfo(
                            label: "To",
                            value: state.hourTo ?? "Select",
                            isEditing: true,
                            selection: List.generate(40, (i) {
                              double v = i * 0.5;
                              return {
                                "id": v.toStringAsFixed(1),
                                "name": _formatHour(v),
                              };
                            }),
                            selectedKey: state.hourTo,
                            onSelectionChanged: (val) {
                              context.read<RequestAbsenceBloc>().add(
                                UpdateHourTo(val!),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                  // Half-day / Custom hours toggles
                  if (state.showHalfDayOptions)
                    Row(
                      children: [
                        tr(
                          "Half Day",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Checkbox(
                          value: state.isHalfDay,
                          activeColor: AppStyle.primaryColor,
                          onChanged: (v) => context
                              .read<RequestAbsenceBloc>()
                              .add(ToggleHalfDay(v ?? false)),
                        ),
                        tr(
                          "Custom Hours",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        Checkbox(
                          value: state.isCustomHours,
                          activeColor: AppStyle.primaryColor,
                          onChanged: (v) => context
                              .read<RequestAbsenceBloc>()
                              .add(ToggleCustomHours(v ?? false)),
                        ),
                      ],
                    ),

                  tr(
                    "Duration",
                    style: TextStyle(
                      fontFamily: TextStyle(
                        fontWeight: FontWeight.w400,
                      ).fontFamily,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AbsenceCreateInfo(
                    label: "Enter Duration",
                    value: state.durationDays,
                    prefixIcon: HugeIcons.strokeRoundedTimeQuarter02,
                    controller: _durationController,
                    isEditing: true,
                    isNumberInput: true,
                    isDaysInclude: true,
                    onTextChanged: (val) {
                      context.read<RequestAbsenceBloc>().add(
                        UpdateDuration(val ?? '1'),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  tr(
                    "Description",
                    style: TextStyle(
                      fontFamily: TextStyle(
                        fontWeight: FontWeight.w400,
                      ).fontFamily,
                      color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AbsenceCreateInfo(
                    label: "Enter Description",
                    value: state.description,
                    prefixIcon: HugeIcons.strokeRoundedNote,
                    controller: _descriptionController,
                    isEditing: true,
                    onTextChanged: (val) {
                      context.read<RequestAbsenceBloc>().add(
                        UpdateDescription(val ?? ''),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Supporting document (conditional)
                  if (state.showFilePicker)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        tr(
                          "Supporting Document",
                          style: TextStyle(
                            fontFamily: TextStyle(
                              fontWeight: FontWeight.w400,
                            ).fontFamily,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xff7F7F7F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AbsenceCreateInfo(
                          label: "Supporting Document",
                          prefixIcon: HugeIcons.strokeRoundedDocumentAttachment,
                          value: state.attachedFileName ?? "No file selected",
                          isEditing: true,
                          isFileInput: true,
                          onFilePicked: (file) {
                            context.read<RequestAbsenceBloc>().add(
                              AttachFile(file),
                            );
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 30),

                  // Submit button with loading state
                  BlocBuilder<RequestAbsenceBloc, RequestAbsenceState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state.isSaving
                              ? null
                              : () => context.read<RequestAbsenceBloc>().add(
                                  SubmitLeaveRequest(),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: state.isSaving
                              ? LoadingAnimationWidget.threeArchedCircle(
                                  color: isDark
                                      ? Colors.white
                                      : AppStyle.primaryColor,
                                  size: 20,
                                )
                              : tr(
                                  "Submit Request",
                                  style: TextStyle(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Formats decimal hour value to readable time string (e.g. 9.5 → "9:30 AM")
  String _formatHour(double hourValue) {
    int h = hourValue.floor();
    int m = (hourValue - h) == 0.5 ? 30 : 0;
    String period = h >= 12 ? "PM" : "AM";
    int displayHour = h % 12 == 0 ? 12 : h % 12;
    return "$displayHour:${m.toString().padLeft(2, '0')} $period";
  }
}
