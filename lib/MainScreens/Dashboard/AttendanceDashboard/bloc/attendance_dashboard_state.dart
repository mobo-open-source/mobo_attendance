part of 'attendance_dashboard_bloc.dart';

/// Immutable state class for the Attendance Dashboard screen.
///
/// Holds UI-relevant data such as:
/// - Loading & error states
/// - Current user check-in status & times
/// - Today's worked hours (live updating) & monthly summary
/// - Recent check-in/out timeline
/// - Admin / Leave Manager-specific statistics (staff counts, punctuality, absenteeism)
/// - Pending leave requests (for Leave Manager roles)
/// - Profile information
///
/// Uses [Equatable] for efficient state comparison in the BLoC pattern.
class AttendanceDashboardState extends Equatable {
  final bool isLoading;
  final bool isCheckInLoading;
  final bool isTimerLoading;
  final bool isCheckIn;
  final String? userName;
  final Uint8List? profileImageBytes;
  final String checkInTime;
  final String lastCheckOutTime;
  final String workedHoursText;
  final String monthlyHoursText;
  final List<Map<String, String>> recentActivity;
  final bool accessForAdmin;
  final bool accessForLeaveManager;
  final bool leaveAction;
  final bool catchError;
  final bool connectionError;
  final bool isAppNotInstalled;

  final int? staffCount;
  final int? staffPresentCount;
  final int? staffAbsentCount;
  final int? leavePendingCount;
  final int? staffOnTimeCount;
  final int? staffLateInCount;
  final int? staffEarlyInCount;
  final List<Map<String, dynamic>> pendingLeaves;
  final AttendanceStatus? attendanceStatus;

  final String? errorMessage;

  final List<int>? staffPresentIds;
  final List<int>? staffAbsentIds;
  final List<int>? onTimeIds;
  final List<int>? lateInIds;
  final List<int>? earlyInIds;
  final List<Map<String, dynamic>> last7DaysAbsenteeismTrend;

  const AttendanceDashboardState({
    this.isLoading = true,
    this.leaveAction = false,
    this.isCheckInLoading = false,
    this.isTimerLoading = false,
    this.isCheckIn = false,
    this.userName,
    this.profileImageBytes,
    this.checkInTime = "--:--",
    this.lastCheckOutTime = "--:--",
    this.workedHoursText = "--:--:--",
    this.monthlyHoursText = "--",
    this.recentActivity = const [],
    this.accessForAdmin = false,
    this.accessForLeaveManager = false,
    this.staffCount,
    this.staffPresentCount,
    this.staffAbsentCount,
    this.leavePendingCount,
    this.staffOnTimeCount,
    this.staffLateInCount,
    this.staffEarlyInCount,
    this.pendingLeaves = const [],
    this.attendanceStatus,
    this.errorMessage,
    this.staffPresentIds,
    this.staffAbsentIds,
    this.onTimeIds,
    this.lateInIds,
    this.earlyInIds,
    this.last7DaysAbsenteeismTrend = const [],
    this.catchError = false,
    this.connectionError = false,
    this.isAppNotInstalled = false,

  });

  /// Creates a new state instance with some fields overridden.
  AttendanceDashboardState copyWith({
    bool? isLoading,
    bool? leaveAction,
    bool? isCheckInLoading,
    bool? isTimerLoading,
    bool? isCheckIn,
    String? userName,
    Uint8List? profileImageBytes,
    String? checkInTime,
    String? lastCheckOutTime,
    String? workedHoursText,
    String? monthlyHoursText,
    List<Map<String, String>>? recentActivity,
    bool? accessForAdmin,
    bool? accessForLeaveManager,
    int? staffCount,
    int? staffPresentCount,
    int? staffAbsentCount,
    int? leavePendingCount,
    int? staffOnTimeCount,
    int? staffLateInCount,
    int? staffEarlyInCount,
    List<Map<String, dynamic>>? pendingLeaves,
    AttendanceStatus? attendanceStatus,
    String? errorMessage,
    List<int>? staffPresentIds,
    List<int>? staffAbsentIds,
    List<int>? onTimeIds,
    List<int>? lateInIds,
    List<int>? earlyInIds,
    List<Map<String, dynamic>>? last7DaysAbsenteeismTrend,
    bool? catchError,
    bool? connectionError,
    bool? isAppNotInstalled,


  }) {
    return AttendanceDashboardState(
      isLoading: isLoading ?? this.isLoading,
      leaveAction: leaveAction ?? this.leaveAction,
      isCheckInLoading: isCheckInLoading ?? this.isCheckInLoading,
      isTimerLoading: isTimerLoading ?? this.isTimerLoading,
      isCheckIn: isCheckIn ?? this.isCheckIn,
      userName: userName ?? this.userName,
      profileImageBytes: profileImageBytes ?? this.profileImageBytes,
      checkInTime: checkInTime ?? this.checkInTime,
      lastCheckOutTime: lastCheckOutTime ?? this.lastCheckOutTime,
      workedHoursText: workedHoursText ?? this.workedHoursText,
      monthlyHoursText: monthlyHoursText ?? this.monthlyHoursText,
      recentActivity: recentActivity ?? this.recentActivity,
      accessForAdmin: accessForAdmin ?? this.accessForAdmin,
      accessForLeaveManager: accessForLeaveManager ?? this.accessForLeaveManager,
      staffCount: staffCount ?? this.staffCount,
      staffPresentCount: staffPresentCount ?? this.staffPresentCount,
      staffAbsentCount: staffAbsentCount ?? this.staffAbsentCount,
      leavePendingCount: leavePendingCount ?? this.leavePendingCount,
      staffOnTimeCount: staffOnTimeCount ?? this.staffOnTimeCount,
      staffLateInCount: staffLateInCount ?? this.staffLateInCount,
      staffEarlyInCount: staffEarlyInCount ?? this.staffEarlyInCount,
      pendingLeaves: pendingLeaves ?? this.pendingLeaves,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      errorMessage: errorMessage,
      staffPresentIds: staffPresentIds ?? this.staffPresentIds,
      staffAbsentIds: staffAbsentIds ?? this.staffAbsentIds,
      onTimeIds: onTimeIds ?? this.onTimeIds,
      lateInIds: lateInIds ?? this.lateInIds,
      earlyInIds: earlyInIds ?? this.earlyInIds,
      last7DaysAbsenteeismTrend: last7DaysAbsenteeismTrend ?? this.last7DaysAbsenteeismTrend,
      catchError: catchError ?? this.catchError,
      connectionError: connectionError ?? this.connectionError,
      isAppNotInstalled: isAppNotInstalled ?? this.isAppNotInstalled,

    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    leaveAction,
    isCheckInLoading,
    isTimerLoading,
    isCheckIn,
    userName,
    profileImageBytes,
    checkInTime,
    lastCheckOutTime,
    workedHoursText,
    monthlyHoursText,
    recentActivity,
    accessForAdmin,
    accessForLeaveManager,
    staffCount,
    staffPresentCount,
    staffAbsentCount,
    leavePendingCount,
    staffOnTimeCount,
    staffLateInCount,
    staffEarlyInCount,
    pendingLeaves,
    attendanceStatus,
    errorMessage,
    staffPresentIds,
    staffAbsentIds,
    onTimeIds,
    lateInIds,
    earlyInIds,
    catchError,
    connectionError,
    isAppNotInstalled
  ];
}