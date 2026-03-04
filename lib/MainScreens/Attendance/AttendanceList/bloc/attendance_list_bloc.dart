import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';
import '../../../../Rating/review_service.dart';
import '../services/attendance_list_service.dart';

part 'attendance_list_event.dart';

part 'attendance_list_state.dart';

/// Bloc responsible for managing the state of the attendance list in the application.
///
/// This Bloc handles loading attendance records, applying filters, searching,
/// clearing filters, deleting attendance entries, and toggling group expansion states.
/// It listens to the [CompanyRefreshBus] to automatically refresh the attendance list
/// when the company data is updated.
class AttendanceListBloc
    extends Bloc<AttendanceListEvent, AttendanceListState> {
  /// The service responsible for fetching and modifying attendance data.
  final AttendanceListService _service;

  /// Subscription to the [CompanyRefreshBus] to refresh attendance data when
  /// company changes occur.
  late final StreamSubscription companySub;

  /// Creates an [AttendanceListBloc] with the provided [_service].
  ///
  /// Registers event handlers for loading attendance, applying filters,
  /// searching, clearing filters, deleting attendance entries, and toggling
  /// group expansions.
  ///
  /// Also subscribes to [CompanyRefreshBus] to reload the attendance list
  /// whenever company data is refreshed.
  AttendanceListBloc(this._service) : super(AttendanceInitial()) {
    on<LoadAttendance>(_onLoadAttendance);
    on<ApplyFilters>(_onApplyFilters);
    on<SearchAttendance>(_onSearchAttendance);
    on<ClearFilters>(_onClearFilters);
    on<DeleteAttendance>(_onDeleteAttendance);
    on<ToggleGroupExpansion>(_onToggleGroupExpansion);
    companySub = CompanyRefreshBus.stream.listen((_) {
      add(LoadAttendance(page: 0));
    });
  }

  /// Handles the [LoadAttendance] event.
  ///
  /// Fetches attendance records from the service, supports pagination, preserves
  /// group expansion states, and emits [AttendanceLoaded] or error states.
  ///
  /// Parameters from the event:
  /// - [page]: Page number for pagination.
  /// - [searchText]: Optional text to filter attendance by search.
  /// - [myAttendance], [myTeam], [atWork], [errors], [last7days]: Optional filter flags.
  /// - [selectedFilters], [selectedGroupBy], [selectedCheckInUnit], [selectedCheckOutUnit]:
  ///   Current UI filter and grouping selections.
  Future<void> _onLoadAttendance(
    LoadAttendance event,
    Emitter<AttendanceListState> emit,
  ) async {
    final previousState = state;

    if (previousState is! AttendanceLoaded && event.page == 0) {
      emit(AttendanceLoading());
    }
    if (previousState is AttendanceLoaded) {
      emit(previousState.copyWith(isPaging: true));
    }

    try {
      final attendance = await _service.fetchAttendance(
        event.page,
        40,
        searchText: event.searchText,
        myAttendance: event.myAttendance,
        myTeam: event.myTeam,
        atWork: event.atWork,
        Errors: event.errors,
        last7days: event.last7days,
      );

      final totalCount = await _service.AttendanceCount(
        searchText: event.searchText,
        myAttendance: event.myAttendance,
        myTeam: event.myTeam,
        atWork: event.atWork,
        Errors: event.errors,
        last7days: event.last7days,
      );
      final access = await _service.canManageSkills();

      Map<String, bool> preservedExpanded = {};
      if (previousState is AttendanceLoaded) {
        preservedExpanded = previousState.groupExpanded;
      }

      emit(
        AttendanceLoaded(
          attendance: attendance,
          totalCount: totalCount,
          currentPage: event.page,
          selectedFilters: event.selectedFilters,
          selectedGroupBy: event.selectedGroupBy,
          selectedCheckInUnit: event.selectedCheckInUnit,
          selectedCheckOutUnit: event.selectedCheckOutUnit,
          searchText: event.searchText ?? '',
          groupExpanded: preservedExpanded,
          accessForAction: access,
          isPaging: false,
        ),
      );
    } catch (e) {
      final isNetworkError =
          e.toString().contains("SocketException") ||
              e.toString().contains("Connection refused");
      if (isNetworkError) {
        emit(
          AttendanceLoaded(
            connectionError: true,
            attendance: const [],
            totalCount: 0,
            currentPage: 0,
            isPaging: false,
          ),
        );
        return;
      }

      if (previousState is AttendanceLoaded) {
        emit(
          previousState.copyWith(
            catchError: true,
            isPaging: false,
            connectionError: false,
          ),
        );
      } else {
        emit(
          AttendanceLoaded(
            catchError: true,
            attendance: [],
            totalCount: 0,
            currentPage: 0,
            isPaging: false,
            connectionError: false,
          ),
        );
      }
    }
  }

  /// Handles the [ApplyFilters] event.
  ///
  /// Transforms selected filters into appropriate flags and triggers a reload
  /// of the attendance list by adding a [LoadAttendance] event.
  Future<void> _onApplyFilters(
    ApplyFilters event,
    Emitter<AttendanceListState> emit,
  ) async {
    add(
      LoadAttendance(
        page: 0,
        selectedFilters: event.selectedFilters,
        selectedGroupBy: event.selectedGroupBy,
        selectedCheckInUnit: event.selectedCheckInUnit,
        selectedCheckOutUnit: event.selectedCheckOutUnit,
        searchText: event.searchText,
        myAttendance: event.selectedFilters.contains('my_attendance'),
        myTeam: event.selectedFilters.contains('my_team'),
        atWork: event.selectedFilters.contains('at_work'),
        errors: event.selectedFilters.contains('errors'),
        last7days: event.selectedFilters.contains('last_7_days'),
      ),
    );
  }

  /// Handles the [SearchAttendance] event.
  ///
  /// Initiates a reload of the attendance list with the current search text
  /// and filters.
  Future<void> _onSearchAttendance(
    SearchAttendance event,
    Emitter<AttendanceListState> emit,
  ) async {
    add(
      LoadAttendance(
        page: 0,
        selectedFilters: event.selectedFilters,
        selectedGroupBy: event.selectedGroupBy,
        selectedCheckInUnit: event.selectedCheckInUnit,
        selectedCheckOutUnit: event.selectedCheckOutUnit,
        searchText: event.searchText,
        myAttendance: event.selectedFilters.contains('my_attendance'),
        myTeam: event.selectedFilters.contains('my_team'),
        atWork: event.selectedFilters.contains('at_work'),
        errors: event.selectedFilters.contains('errors'),
        last7days: event.selectedFilters.contains('last_7_days'),
      ),
    );
  }

  /// Handles the [ClearFilters] event.
  ///
  /// Resets all filters and triggers a reload of the attendance list.
  Future<void> _onClearFilters(
    ClearFilters event,
    Emitter<AttendanceListState> emit,
  ) async {
    add(
      const LoadAttendance(
        page: 0,
        selectedFilters: [],
        selectedGroupBy: null,
        selectedCheckInUnit: null,
        selectedCheckOutUnit: null,
        searchText: '',
      ),
    );
  }

  /// Handles the [DeleteAttendance] event.
  ///
  /// Attempts to delete an attendance record by [event.id]. If successful,
  /// reloads the current page and emits [AttendanceDeletedSuccess]. If deletion
  /// fails, emits an error message.
  Future<void> _onDeleteAttendance(
    DeleteAttendance event,
    Emitter<AttendanceListState> emit,
  ) async {
    final currentState = state;
    if (currentState is AttendanceLoaded) {
      try {
        final errorMessage = await _service.deleteAttendance(event.id);
        if (errorMessage == null) {
          add(
            LoadAttendance(
              page: currentState.currentPage,
              selectedFilters: currentState.selectedFilters,
              selectedGroupBy: currentState.selectedGroupBy,
              selectedCheckInUnit: currentState.selectedCheckInUnit,
              selectedCheckOutUnit: currentState.selectedCheckOutUnit,
              searchText: currentState.searchText,
              myAttendance: currentState.selectedFilters.contains(
                'my_attendance',
              ),
              myTeam: currentState.selectedFilters.contains('my_team'),
              atWork: currentState.selectedFilters.contains('at_work'),
              errors: currentState.selectedFilters.contains('errors'),
              last7days: currentState.selectedFilters.contains('last_7_days'),
            ),
          );
          emit(AttendanceDeletedSuccess());
        } else {
          emit(currentState.copyWith(errorMessage: errorMessage));
        }
      } catch (e) {
        emit(
          currentState.copyWith(
            errorMessage: "Something went wrong, Please try again later.",
          ),
        );
      }
    }
  }

  /// Handles the [ToggleGroupExpansion] event.
  ///
  /// Toggles the expansion state of a group in the attendance list UI.
  void _onToggleGroupExpansion(
    ToggleGroupExpansion event,
    Emitter<AttendanceListState> emit,
  ) {
    if (state is AttendanceLoaded) {
      final current = state as AttendanceLoaded;
      final updated = Map<String, bool>.from(current.groupExpanded);
      updated[event.groupName] = !(updated[event.groupName] ?? true);

      emit(current.copyWith(groupExpanded: updated));
    }
  }
}
