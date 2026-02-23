import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_attendance/MainScreens/Employees/EmployeeList/services/employee_list_service.dart';

import '../../../../CommonWidgets/core/company/infrastructure/company_refresh_bus.dart';

part 'employee_list_event.dart';

part 'employee_list_state.dart';

/// Manages the state and business logic for the **Employee List** screen.
///
/// Features:
/// - Paginated employee fetching (40 per page)
/// - Real-time search by name
/// - Filter application (My Team, My Department, Newly Hired, Archived)
/// - Grouping by Manager/Department/Job/Skills/Tags/Start Date
/// - Permission-aware actions (archive/delete if permitted)
/// - Image visibility check (HR/manager/admin only)
/// - Skill/tag name enrichment for grouped views
/// - Company refresh bus integration (reload on company change)
/// - Error/connection/empty state handling
class EmployeeListBloc extends Bloc<EmployeeListEvent, EmployeeListState> {
  final EmployeeListService employeeService = EmployeeListService();
  final int itemsPerPage = 40;

  /// Human-readable → technical filter names
  final Map<String, String> filterTechnicalNames = {
    "My Team": "my_team",
    "My Department": "my_department",
    "Newly Hired": "newly_hired",
    "Archived": "archived",
  };

  /// Human-readable → technical group-by names
  final Map<String, String> groupTechnicalNames = {
    "Manager": "manager",
    "Department": "department",
    "Job": "job",
    "Skills": "skills",
    "Tags": "tags",
    "Start Date": "start_date",
  };

  /// Start date grouping units
  final Map<String, String> startDateUnits = {
    "Year": "year",
    "Quarter": "quarter",
    "Month": "month",
    "Week": "week",
    "Day": "day",
  };

  late final StreamSubscription companySub;

  EmployeeListBloc({
    List<int>? preAppliedEmployeeIds,
    String? preAppliedFilterName,
    bool? preApplied,
  }) : super(
         EmployeeListState(
           preFilteredEmployeeIds: preAppliedEmployeeIds,
           currentFilterTitle: preAppliedFilterName,
         ),
       ) {
    on<InitializeEmployeeList>(_onInitialize);
    on<FetchEmployees>(_onFetchEmployees);
    on<ApplyFiltersAndGroupBy>(_onApplyFiltersAndGroupBy);
    on<ClearFilters>(_onClearFilters);
    on<ReloadEmployeeList>(_onReload);
    on<ToggleGroupExpanded>(_onToggleGroupExpanded);
    on<ArchiveEmployee>(_onArchiveEmployee);
    on<DeleteEmployee>(_onDeleteEmployee);

    // Listen to company refresh bus (reload list when company changes)
    companySub = CompanyRefreshBus.stream.listen((_) {
      add(InitializeEmployeeList());
    });
  }

  /// Initializes the bloc: checks image permission, then triggers first fetch
  Future<void> _onInitialize(
    InitializeEmployeeList event,
    Emitter<EmployeeListState> emit,
  ) async {
    try {
      if (!event.silent) {
        emit(state.copyWith(isLoading: true));
      }
      await employeeService.initializeClient();
      final access = await employeeService.userCanSeeEmployeeImage();

      emit(state.copyWith(accessForAction: access));

      add(FetchEmployees(page: 0, searchQuery: ''));
    } on SocketException catch (_) {
      emit(state.copyWith(isLoading: false, catchError: false, connectionError: true));
    } catch (e) {
      emit(state.copyWith(isLoading: false, catchError: true, connectionError: false));
    }
  }

  /// Core fetch handler: loads paginated employees + count, applies filters/grouping
  Future<void> _onFetchEmployees(
    FetchEmployees event,
    Emitter<EmployeeListState> emit,
  ) async {
    // Prevent duplicate fetches for same page (except page 0)
    if (event.page == state.currentPage && event.page != 0) return;

    emit(
      state.copyWith(
        pageLoading: event.isUserPagination,
        searchQuery: event.searchQuery,
        warningMessage: null,
        errorMessage: null,
        catchError: false,
        connectionError: false,
      ),
    );
    final archived = state.selectedFilters.contains("archived");
    final newlyHired = state.selectedFilters.contains("newly_hired");
    final myTeam = state.selectedFilters.contains("my_team");
    final myDepartment = state.selectedFilters.contains("my_department");
    final active = !archived;

    try {
      // 1. Get total count with current filters
      final count = await employeeService.EmployeeCount(
        searchText: event.searchQuery,
        active: active,
        newlyHired: newlyHired,
        myTeam: myTeam,
        myDepartment: myDepartment,
        employeeIds: state.preFilteredEmployeeIds,
        preApplied: state.preFilteredEmployeeIds != null,
      );

      // 2. Check image permission (affects fields fetched)
      final access = await employeeService.userCanSeeEmployeeImage();

      // 3. Fetch current page of employees
      final rawEmployees = await employeeService.fetchEmployees(
        event.page,
        itemsPerPage,
        searchQuery: event.searchQuery,
        active: active,
        newlyHired: newlyHired,
        myTeam: myTeam,
        myDepartment: myDepartment,
        employeeIds: state.preFilteredEmployeeIds,
        preApplied: state.preFilteredEmployeeIds != null,
      );

      // 4. Enrich with skill/tag names if grouping by them
      String? selectedGroupBy = state.selectedGroupBy;
      if (selectedGroupBy == "skills") {
        await employeeService.loadSkill(rawEmployees);
      } else if (selectedGroupBy == "tags") {
        await employeeService.loadTags(rawEmployees);
      }

      // 5. Apply grouping if active
      List<Map<String, dynamic>> groupedEmployees = [];
      if (selectedGroupBy != null && selectedGroupBy.isNotEmpty) {
        groupedEmployees = _groupEmployees(
          rawEmployees,
          selectedGroupBy,
          state.selectedStartDateUnit ?? "day",
        );
      } else {
        groupedEmployees = [];
      }

      // 6. Calculate displayed count for pagination UI
      final previousPagesCount = event.page * itemsPerPage;
      final displayedCount = previousPagesCount + rawEmployees.length;

      emit(
        state.copyWith(
          employees: rawEmployees,
          groupedEmployees: groupedEmployees,
          currentPage: event.page,
          totalCount: count,
          displayedCount: displayedCount.clamp(0, count),
          pageLoading: false,
          filterLoading: false,
          isLoading: false,
          warningMessage: null,
          errorMessage: null,
          accessForAction: access,
          catchError: false,
          connectionError: false,
        ),
      );
    } on SocketException catch (_) {
      emit(
        state.copyWith(
          employees: [],
          groupedEmployees: [],
          pageLoading: false,
          filterLoading: false,
          isLoading: false,
          warningMessage: null,
          catchError: false,
          connectionError: true,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          employees: [],
          groupedEmployees: [],
          pageLoading: false,
          filterLoading: false,
          isLoading: false,
          warningMessage: null,
          catchError: true,
          connectionError: false,
          errorMessage: null,
        ),
      );
    }
  }

  /// Applies new filters/group-by and triggers a full refresh (page 0)
  Future<void> _onApplyFiltersAndGroupBy(
    ApplyFiltersAndGroupBy event,
    Emitter<EmployeeListState> emit,
  ) async {
    emit(
      state.copyWith(
        filterLoading: true,
        selectedFilters: event.filters,
        selectedGroupBy: event.groupBy,
        selectedStartDateUnit: event.startDateUnit,
        groupExpanded: {},
      ),
    );

    add(FetchEmployees(page: 0, searchQuery: state.searchQuery));
  }

  /// Clears all filters/group-by and refreshes the list
  Future<void> _onClearFilters(
    ClearFilters event,
    Emitter<EmployeeListState> emit,
  ) async {
    emit(
      state.copyWith(
        filterLoading: true,
        selectedFilters: const [],
        selectedGroupBy: '',
        selectedStartDateUnit: 'day',
        groupExpanded: const {},
        groupedEmployees: const [],
      ),
    );

    add(FetchEmployees(page: 0, searchQuery: state.searchQuery));
  }

  /// Reloads the list from scratch (clears filters/search)
  void _onReload(ReloadEmployeeList event, Emitter<EmployeeListState> emit) {
    emit(
      state.copyWith(
        selectedFilters: [],
        selectedGroupBy: '',
        selectedStartDateUnit: 'day',
        groupExpanded: {},
        groupedEmployees: [],
        searchQuery: '',
      ),
    );
    add(FetchEmployees(page: 0, searchQuery: ''));
  }

  /// Toggles expanded/collapsed state of a grouped section
  void _onToggleGroupExpanded(
    ToggleGroupExpanded event,
    Emitter<EmployeeListState> emit,
  ) {
    final updated = Map<String, bool>.from(state.groupExpanded);
    updated[event.groupName] = !(updated[event.groupName] ?? true);
    emit(state.copyWith(groupExpanded: updated));
  }

  /// Archives selected employee (sets active = false)
  Future<void> _onArchiveEmployee(
    ArchiveEmployee event,
    Emitter<EmployeeListState> emit,
  ) async {
    final result = await employeeService.archiveEmployee(event.employeeId);
    if (result == null) {
      // Success → refresh list
      add(FetchEmployees(page: 0, searchQuery: state.searchQuery));
      return;
    }

    if (result['warning'] == true) {
      final message = result['warningMessage'] ?? "Something went wrong";

      emit(state.copyWith(warningMessage: message));
    } else {
      final message = result['errorMessage'] ?? "Something went wrong";
      emit(state.copyWith(errorMessage: message));
    }
  }

  /// Permanently deletes selected employee
  Future<void> _onDeleteEmployee(
    DeleteEmployee event,
    Emitter<EmployeeListState> emit,
  ) async {
    final result = await employeeService.deleteEmployee(event.employeeId);
    if (result == null) {
      // Success → refresh list
      add(FetchEmployees(page: 0, searchQuery: state.searchQuery));
      return;
    }
    if (result['warning'] == true) {
      final message = result['warningMessage'] ?? "Something went wrong";

      emit(state.copyWith(warningMessage: message));
    } else {
      final message = result['errorMessage'] ?? "Something went wrong";

      emit(state.copyWith(errorMessage: message));
    }
  }

  /// Groups raw employees into sections based on selected group-by criteria
  List<Map<String, dynamic>> _groupEmployees(
    List<Map<String, dynamic>> employees,
    String groupBy,
    String startDateUnit,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var emp in employees) {
      String key = "Unknown";

      if (groupBy == "manager") {
        key = (emp["parent_id"] is List && emp["parent_id"].isNotEmpty)
            ? emp["parent_id"][1]
            : "None";
      } else if (groupBy == "department") {
        key = (emp["department_id"] is List && emp["department_id"].isNotEmpty)
            ? emp["department_id"][1]
            : "None";
      } else if (groupBy == "job") {
        key = (emp["job_id"] is List && emp["job_id"].isNotEmpty)
            ? emp["job_id"][1]
            : "None";
      } else if (groupBy == "skills") {
        key = (emp["skill_names"] is List && emp["skill_names"].isNotEmpty)
            ? (emp["skill_names"] as List).join(", ")
            : "None";
      } else if (groupBy == "tags") {
        key = (emp["tag_names"] is List && emp["tag_names"].isNotEmpty)
            ? (emp["tag_names"] as List).join(", ")
            : "None";
      } else if (groupBy == "start_date") {
        String? dateStr;
        if (emp["create_date"] is String) {
          dateStr = emp["create_date"];
        } else if (emp["create_date"] is List &&
            emp["create_date"].length > 1) {
          dateStr = emp["create_date"][1];
        }

        String dateKey = "No Date";
        if (dateStr != null && dateStr.isNotEmpty) {
          try {
            final date = DateTime.parse(dateStr);
            switch (startDateUnit) {
              case "year":
                dateKey = "${date.year}";
                break;
              case "quarter":
                int quarter = ((date.month - 1) ~/ 3) + 1;
                dateKey = "Q$quarter ${date.year}";
                break;
              case "month":
                dateKey = "${date.month}-${date.year}";
                break;
              case "week":
                int week =
                    ((date.day +
                            DateTime(date.year, date.month, 1).weekday -
                            1) ~/
                        7) +
                    1;
                dateKey = "Week $week ${date.year}";
                break;
              case "day":
                dateKey = "${date.day}-${date.month}-${date.year}";
                break;
            }
          } catch (e) {
            dateKey = "Invalid Date";
          }
        }
        key = dateKey;
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(emp);
    }

    final groups = grouped.entries
        .map((e) => {"group": e.key, "employees": e.value})
        .toList();

    return groups;
  }
}
