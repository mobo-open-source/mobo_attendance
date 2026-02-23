import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../../LoginPages/credetials/services/app_install_check.dart';
import '../services/attendance_dashboard_service.dart';

part 'attendance_dashboard_event.dart';

part 'attendance_dashboard_state.dart';

/// Manages the attendance dashboard state using the BLoC pattern.
///
/// Handles check-in/check-out logic, live worked hours timer,
/// admin/Leave Manager statistics, profile data, recent activity timeline,
/// and periodic refresh when company context changes.
class AttendanceDashboardBloc
    extends Bloc<AttendanceDashboardEvent, AttendanceDashboardState> {
  final AttendanceDashboardService _service;
  Timer? _timer;
  DateTime? _todayCheckInDateTime;
  bool timerLoading = false;
  late final StreamSubscription companySub;

  AttendanceDashboardBloc(this._service)
    : super(const AttendanceDashboardState()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<CheckInRequested>(_onCheckIn);
    on<CheckOutRequested>(_onCheckOut);
    on<RefreshDashboard>(_onRefresh);
    on<_InternalUpdateWorkedHours>(_onInternalUpdateWorkedHours);

    // Listen to company refresh events (usually triggered by organization switch)
    companySub = CompanyRefreshBus.stream.listen((_) {
      _timer?.cancel();
      _todayCheckInDateTime = null;
      add(LoadDashboardData());
    });
  }

  /// Loads all dashboard data including:
  ///   - User profile & image
  ///   - Check-in status & today's attendance record
  ///   - Worked hours (current day + monthly)
  ///   - Admin/Leave Manager statistics (if permitted)
  ///   - Pending leaves (if Leave Manager role)
  ///   - Recent activity timeline
  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<AttendanceDashboardState> emit,
  ) async {
    emit(
      state.copyWith(isLoading: true, errorMessage: null, catchError: false, connectionError: false),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName') ?? 'User';

      final profileList = await _service.loadProfile();
      final accessForAdmin = await _service.isAdmin();
      bool isAppNotInstalled = false;
      bool accessForLeaveManager = false;
      bool success = await AppInstallCheck().checkLeaveModule();
      if(!success){
        isAppNotInstalled = true;
      }else {
        isAppNotInstalled = false;
        accessForLeaveManager = await _service.isHrLeaveManager();
      }

      final isCheckedIn = await _service.isEmployeeAlreadyCheckedIn();
      final monthlyHours = await _service.getCurrentMonthWorkedHours();
      Uint8List? profileImageBytes;
      if (profileList.isNotEmpty && profileList[0]['image_1920'] != null) {
        final base64Image = profileList[0]['image_1920'];
        if (base64Image.isNotEmpty) {
          profileImageBytes = base64Decode(base64Image);
        }
      }
      int? staffCount,
          staffPresentCount,
          staffAbsentCount,
          leavePendingCount,
          staffOnTimeCount,
          staffLateInCount,
          staffEarlyInCount;

      List<Map<String, dynamic>> pendingLeaves = [];

      List<int>? staffPresentIds,
          staffAbsentIds,
          onTimeIds,
          lateInIds,
          earlyInIds;

      AttendanceStatus? attendanceStatus;
      List<Map<String, dynamic>> last7DaysAbsenteeismTrend = [];

      // Leave Manager permissions
      if (!accessForAdmin && accessForLeaveManager) {
        try{
          leavePendingCount = await _service.pendingLeaveCount();
          pendingLeaves = await _service.pendingLeaves();
          isAppNotInstalled = false;
        }catch(e){
          bool success = await AppInstallCheck().checkLeaveModule();
          if(!success){
            isAppNotInstalled = true;
          }else {
            leavePendingCount = 0;
            pendingLeaves = [];
            isAppNotInstalled = false;
          }
        }
      }

      // Admin-only statistics
      if (accessForAdmin) {
        staffCount = await _service.staffCount();
        last7DaysAbsenteeismTrend = await _service
            .getAbsenteeismTrendLast7Days();

        final presentEmployee = await _service.getPresentEmployees();
        staffPresentCount = presentEmployee['count'];
        staffPresentIds = List<int>.from(presentEmployee['employeeIds'] ?? []);

        final absentEmployee = await _service.getAbsentEmployees(staffPresentIds);
        staffAbsentCount = absentEmployee['count'];
        staffAbsentIds = List<int>.from(absentEmployee['employeeIds'] ?? []);
        try{
        leavePendingCount = await _service.pendingLeaveCount();
        pendingLeaves = await _service.pendingLeaves();
        isAppNotInstalled = false;
        }catch(e){

          bool success = await AppInstallCheck().checkLeaveModule();

          if(!success){
            isAppNotInstalled = true;
          }else {
            leavePendingCount = 0;
            pendingLeaves = [];
            isAppNotInstalled = false;
          }
        }
        attendanceStatus = await _service.getTodayAttendanceStatusCounts();
        staffOnTimeCount = attendanceStatus?.onTime;
        staffLateInCount = attendanceStatus?.lateIn;
        staffEarlyInCount = attendanceStatus?.earlyIn;

        onTimeIds = attendanceStatus?.onTimeIds;
        lateInIds = attendanceStatus?.lateInIds;
        earlyInIds = attendanceStatus?.earlyInIds;
      }
      final record = await _service.checkInDetails();

      String checkInTime = "00:00";
      String lastCheckOutTime = "--:--";
      String workedHoursText = "--:--:--";
      List<Map<String, String>> recentActivity = [];

      if (record != null) {
        recentActivity = _formatAttendanceTimeline(record['records']);

        if (record['firstCheckIn'] != null) {
          final dt = DateTime.parse('${record['firstCheckIn']}Z').toLocal();
          checkInTime = DateFormat('hh:mm a').format(dt);
        }

        if (record['lastCheckOut'] != null && record['lastCheckOut'] != false) {
          final dt = DateTime.parse('${record['lastCheckOut']}Z').toLocal();
          lastCheckOutTime = DateFormat('hh:mm a').format(dt);
        }

        final totalWorkedHours = (record['totalWorkedHours'] ?? 0.0).toDouble();
        final activeCheckIn = record['activeCheckIn'];

        if (activeCheckIn != null) {
          timerLoading = true;

          final activeDT = DateTime.parse('$activeCheckIn' + 'Z').toLocal();
          final todayMidnight = DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          );
          _todayCheckInDateTime = activeDT.isBefore(todayMidnight)
              ? todayMidnight
              : activeDT;
          _startTimer(totalWorkedHours);
        } else {
          timerLoading = false;
          final duration = Duration(seconds: (totalWorkedHours * 3600).round());
          workedHoursText = _formatDuration(duration);
        }
      }

      emit(
        state.copyWith(
          isLoading: false,
          catchError: false,
          connectionError: false,
          leaveAction: false,
          isTimerLoading: timerLoading,
          userName: userName,
          profileImageBytes: profileImageBytes,
          isCheckIn: isCheckedIn,
          checkInTime: checkInTime,
          lastCheckOutTime: lastCheckOutTime,
          workedHoursText: workedHoursText,
          monthlyHoursText: monthlyHours.toStringAsFixed(2),
          recentActivity: recentActivity,
          accessForAdmin: accessForAdmin,
          accessForLeaveManager: accessForLeaveManager,
          staffCount: staffCount,
          staffPresentCount: staffPresentCount,
          staffAbsentCount: staffAbsentCount,
          leavePendingCount: leavePendingCount,
          staffOnTimeCount: staffOnTimeCount,
          staffLateInCount: staffLateInCount,
          staffEarlyInCount: staffEarlyInCount,
          pendingLeaves: pendingLeaves,
          isAppNotInstalled:isAppNotInstalled,
          staffPresentIds: staffPresentIds,
          staffAbsentIds: staffAbsentIds,
          onTimeIds: onTimeIds,
          lateInIds: lateInIds,
          earlyInIds: earlyInIds,
          attendanceStatus: attendanceStatus,
          last7DaysAbsenteeismTrend: last7DaysAbsenteeismTrend,
        ),
      );
    } on SocketException catch (_) {
      emit(state.copyWith(
        isLoading: false,
        leaveAction: false,
        catchError: false,
        connectionError: true,
      ));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          leaveAction: false,
          catchError: true,
        ),
      );
    }
  }

  /// Starts a periodic timer that updates the currently worked hours
  /// every second when the employee is checked in.
  void _startTimer(double baseWorkedHours) {
    _timer?.cancel();
    final baseDuration = Duration(seconds: (baseWorkedHours * 3600).round());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_todayCheckInDateTime == null) return;
      final elapsed = DateTime.now().difference(_todayCheckInDateTime!);
      final total = baseDuration + elapsed;
      add(_InternalUpdateWorkedHours(_formatDuration(total)));
    });
  }

  /// Internal event handler — updates only the worked hours display.
  void _onInternalUpdateWorkedHours(
    _InternalUpdateWorkedHours event,
    Emitter<AttendanceDashboardState> emit,
  ) {
    emit(
      state.copyWith(workedHoursText: event.hoursText, isTimerLoading: false),
    );
  }

  /// Converts raw attendance records into a sorted timeline
  /// suitable for UI display (Check In / Check Out events).
  List<Map<String, String>> _formatAttendanceTimeline(List<dynamic> records) {
    List<Map<String, String>> timeline = [];
    final timeFormat = DateFormat('hh:mm a');

    for (var att in records) {
      final checkIn = att['check_in']?.toString();
      final checkOut = att['check_out']?.toString();
      final inModeRaw = att['in_mode']?.toString() ?? '--';
      final outModeRaw = att['out_mode']?.toString() ?? '--';
      final inMode = inModeRaw[0].toUpperCase() + inModeRaw.substring(1);
      final outMode = outModeRaw[0].toUpperCase() + outModeRaw.substring(1);

      if (checkIn != null && checkIn.isNotEmpty && checkIn != "false") {
        final formatted = timeFormat.format(
          DateTime.parse('${checkIn}Z').toLocal(),
        );
        timeline.add({'type': 'Check In', 'time': formatted, 'mode': inMode});
      }
      if (checkOut != null && checkOut.isNotEmpty && checkOut != "false") {
        final formatted = timeFormat.format(
          DateTime.parse('${checkOut}Z').toLocal(),
        );
        timeline.add({'type': 'Check Out', 'time': formatted, 'mode': outMode});
      }
    }

    timeline.sort((a, b) => a['time']!.compareTo(b['time']!));
    return timeline;
  }

  /// Formats Duration object into HH:mm:ss string (with leading zeros).
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  /// Handles check-in request:
  ///   - Gets current location & IP
  ///   - Sends check-in record to backend
  ///   - Triggers dashboard refresh on success
  Future<void> _onCheckIn(
    CheckInRequested event,
    Emitter<AttendanceDashboardState> emit,
  ) async {
    emit(state.copyWith(isCheckInLoading: true));
    try {
      final info = await getLocationAndNetworkInfo();
      final nowStr = _normalizeDate(_getCurrentDateTime());
      final data = {
        'check_in': nowStr,
        'in_mode': 'systray',
        'in_latitude': info["latitude"],
        'in_longitude': info["longitude"],
        'in_country_name': info["country"] ?? '',
        'in_ip_address': info["ip"],
        'in_browser': 'Flutter App',
      };

      final success = await _service.createAttendanceDetails(data);
      if (success) {
        add(RefreshDashboard());
      } else {
        emit(state.copyWith(errorMessage: "Check-in failed"));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Something went wrong, Please try again later.",
        ),
      );
    } finally {
      emit(state.copyWith(isCheckInLoading: false));
    }
  }

  /// Handles check-out request (similar flow to check-in)
  Future<void> _onCheckOut(
    CheckOutRequested event,
    Emitter<AttendanceDashboardState> emit,
  ) async {
    emit(state.copyWith(isCheckInLoading: true));
    try {
      final info = await getLocationAndNetworkInfo();
      final data = {
        'check_out': _normalizeDate(_getCurrentDateTime()),
        'out_mode': 'systray',
        'out_latitude': info["latitude"],
        'out_longitude': info["longitude"],
        'out_country_name': info["country"] ?? '',
        'out_ip_address': info["ip"],
        'out_browser': 'Flutter App',
      };
      final success = await _service.writeAttendanceDetails(data);
      if (success) {
        _timer?.cancel();
        _todayCheckInDateTime = null;
        add(RefreshDashboard());
      } else {
        emit(state.copyWith(errorMessage: "Check-out failed"));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: "Something went wrong, Please try again later.",
        ),
      );
    } finally {
      emit(state.copyWith(isCheckInLoading: false));
    }
  }

  /// Simple refresh trigger — reloads all dashboard data
  void _onRefresh(
    RefreshDashboard event,
    Emitter<AttendanceDashboardState> emit,
  ) {
    add(LoadDashboardData());
  }

  /// Collects current location and public IP address.
  /// Used for geo-tagging attendance records.
  @visibleForTesting
  Future<Map<String, dynamic>> getLocationAndNetworkInfo() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    String country = placemarks.first.country ?? "Unknown";
    String ip = "Unknown";

    try {
      final response = await http.get(
        Uri.parse("https://api.ipify.org?format=json"),
      );
      if (response.statusCode == 200) {
        ip = jsonDecode(response.body)["ip"];
      }
    } catch (_) {}

    return {
      "latitude": position.latitude,
      "longitude": position.longitude,
      "country": country,
      "ip": ip,
    };
  }

  /// Returns current date-time in backend-expected format (without seconds)
  String _getCurrentDateTime() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  /// Ensures date string has seconds component (adds :00 if missing)
  String _normalizeDate(String date) => date.length == 16 ? "$date:00" : date;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

class _InternalUpdateWorkedHours extends AttendanceDashboardEvent {
  final String hoursText;

  const _InternalUpdateWorkedHours(this.hoursText);

  @override
  List<Object> get props => [hoursText];
}
