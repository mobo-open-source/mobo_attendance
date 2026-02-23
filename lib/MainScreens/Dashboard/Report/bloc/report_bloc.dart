import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/report_service.dart';
import 'report_event.dart';
import 'report_state.dart';

/// Manages the state and business logic for the Reports screen (attendance analytics).
///
/// Features:
/// - Loads paginated graph data for attendance visualization
/// - Supports keyword search
/// - Filtering by various criteria (passed as list)
/// - Grouping by check-in or check-out date (with unit: day/month/year/etc.)
/// - Measure selection (e.g. count, average hours, etc.)
/// - View mode toggle (e.g. bar chart, line chart)
/// - Error handling and loading states
class ReportBloc extends Bloc<ReportEvent, ReportState> {
  final ReportService _service = ReportService();

  ReportBloc() : super(const ReportState()) {
    on<InitializeReport>(_onInitialize);
    on<LoadGraphData>(_onLoadGraphData);
    on<UpdateSearchText>(_onUpdateSearchText);
    on<UpdateFilters>(_onUpdateFilters);
    on<UpdateGroupBy>(_onUpdateGroupBy);
    on<ClearAllFiltersAndGroupBy>(_onClearAll);
    on<UpdateMeasure>(_onUpdateMeasure);
    on<UpdateView>(_onUpdateView);
  }

  /// Called once when the report screen is initialized.
  /// Triggers the first data load from page 0.
  Future<void> _onInitialize(
    InitializeReport event,
    Emitter<ReportState> emit,
  ) async {
    add(const LoadGraphData(page: 0));
  }

  /// Core data fetching handler for graph / report data.
  ///
  /// Builds grouping parameters based on current state,
  /// fetches paginated data from service, and updates total count.
  Future<void> _onLoadGraphData(
    LoadGraphData event,
    Emitter<ReportState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, filterLoading: true));

    try {
      String? dateGroupBy;
      String? dateGroupByUnit;

      // Determine active date grouping (check_in or check_out)
      if (state.selectedGroupByOptions.contains('check_in')) {
        dateGroupBy = 'check_in';
        dateGroupByUnit = state.selectedCheckInUnits.isEmpty
            ? 'day'
            : state.selectedCheckInUnits.first;
      } else if (state.selectedGroupByOptions.contains('check_out')) {
        dateGroupBy = 'check_out';
        dateGroupByUnit = state.selectedCheckOutUnits.isEmpty
            ? 'day'
            : state.selectedCheckOutUnits.first;
      }

      final graphData = await _service.fetchAttendanceForGraph(
        page: event.page,
        itemsPerPage: state.itemsPerPage,
        searchText: state.searchText,
        filters: state.selectedFilters,
        dateGroupBy: dateGroupBy,
        dateGroupByUnit: dateGroupByUnit,
        measure: state.selectedMeasure,
      );

      final totalCount = await _service.fetchAttendanceTotalCount(
        filters: state.selectedFilters,
        searchText: state.searchText,
      );

      emit(
        state.copyWith(
          isLoading: false,
          filterLoading: false,
          graphData: graphData,
          totalCount: totalCount,
          currentPage: event.page,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          filterLoading: false,
          errorMessage: 'Failed to load data: $e',
        ),
      );
    }
  }

  /// Updates search text and triggers data reload from page 0
  void _onUpdateSearchText(UpdateSearchText event, Emitter<ReportState> emit) {
    emit(state.copyWith(searchText: event.text));
    add(const LoadGraphData(page: 0));
  }

  /// Updates active filters and keeps current page (no auto-refresh)
  void _onUpdateFilters(UpdateFilters event, Emitter<ReportState> emit) {
    emit(state.copyWith(selectedFilters: event.filters));
  }

  /// Changes grouping criteria (check_in or check_out) and unit
  void _onUpdateGroupBy(UpdateGroupBy event, Emitter<ReportState> emit) {
    final newGroupBy = [event.groupBy];
    final newCheckInUnits = event.groupBy == 'check_in'
        ? [event.unit ?? 'day']
        : <String>[];
    final newCheckOutUnits = event.groupBy == 'check_out'
        ? [event.unit ?? 'day']
        : <String>[];

    emit(
      state.copyWith(
        selectedGroupByOptions: newGroupBy,
        selectedCheckInUnits: newCheckInUnits,
        selectedCheckOutUnits: newCheckOutUnits,
      ),
    );
  }

  /// Resets all filters, search, grouping and reloads data from page 0
  void _onClearAll(ClearAllFiltersAndGroupBy event, Emitter<ReportState> emit) {
    emit(
      state.copyWith(
        selectedFilters: [],
        selectedGroupByOptions: [],
        selectedCheckInUnits: [],
        selectedCheckOutUnits: [],
        searchText: '',
      ),
    );
    add(const LoadGraphData(page: 0));
  }

  /// Changes the measure/metric to display (e.g. count, average hours)
  void _onUpdateMeasure(UpdateMeasure event, Emitter<ReportState> emit) {
    emit(state.copyWith(selectedMeasure: event.measure));
    add(const LoadGraphData(page: 0));
  }

  /// Switches visualization mode (bar chart and line chart.)
  void _onUpdateView(UpdateView event, Emitter<ReportState> emit) {
    emit(state.copyWith(selectedView: event.view));
  }
}
