import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error_mapper.dart';
import '../models/ride.dart';
import 'service_providers.dart';

class SearchRidesState {
  final String? selectedCommune;
  final String? selectedDirection;
  final String? selectedCampusId;
  final DateTime? selectedDate;
  final List<Map<String, dynamic>> campuses;
  final String? campusesError;
  final bool loadingCampuses;
  final List<Ride> results;
  final bool loading;
  final bool searched;

  const SearchRidesState({
    this.selectedCommune,
    this.selectedDirection,
    this.selectedCampusId,
    this.selectedDate,
    this.campuses = const [],
    this.campusesError,
    this.loadingCampuses = true,
    this.results = const [],
    this.loading = false,
    this.searched = false,
  });

  SearchRidesState copyWith({
    String? selectedCommune,
    String? selectedDirection,
    String? selectedCampusId,
    DateTime? selectedDate,
    bool clearDate = false,
    List<Map<String, dynamic>>? campuses,
    String? campusesError,
    bool clearCampusesError = false,
    bool? loadingCampuses,
    List<Ride>? results,
    bool? loading,
    bool? searched,
  }) {
    return SearchRidesState(
      selectedCommune: selectedCommune ?? this.selectedCommune,
      selectedDirection: selectedDirection ?? this.selectedDirection,
      selectedCampusId: selectedCampusId ?? this.selectedCampusId,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      campuses: campuses ?? this.campuses,
      campusesError:
          clearCampusesError ? null : (campusesError ?? this.campusesError),
      loadingCampuses: loadingCampuses ?? this.loadingCampuses,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      searched: searched ?? this.searched,
    );
  }
}

class SearchRidesNotifier extends StateNotifier<SearchRidesState> {
  SearchRidesNotifier(this._ref) : super(const SearchRidesState()) {
    loadCampuses();
  }

  final Ref _ref;

  Future<void> loadCampuses() async {
    state = state.copyWith(loadingCampuses: true, clearCampusesError: true);
    final reference = _ref.read(referenceDataServiceProvider);
    try {
      final rows = await reference.getCampusesWithUniversity();
      state = state.copyWith(
        campuses: rows,
        campusesError: reference.lastCallUsedFallback
            ? 'No se pudo cargar desde Supabase. Se usan datos de referencia locales.'
            : null,
        loadingCampuses: false,
      );
    } catch (e) {
      state = state.copyWith(
        loadingCampuses: false,
        campusesError: AppErrorMapper.toMessage(
          e,
          fallback: 'No se pudo cargar la lista de campus',
        ),
      );
    }
  }

  Future<void> search() async {
    state = state.copyWith(loading: true, searched: true);
    try {
      final rideService = _ref.read(rideServiceProvider);
      final rows = await rideService.searchRides(
        campusId: state.selectedCampusId,
        originCommune: state.selectedCommune,
        direction: state.selectedDirection,
        date: state.selectedDate,
      );
      state = state.copyWith(results: rows, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  void setCommune(String? value) {
    state = state.copyWith(selectedCommune: value);
  }

  void setDirection(String? value) {
    state = state.copyWith(selectedDirection: value);
  }

  void setCampus(String? value) {
    state = state.copyWith(selectedCampusId: value);
  }

  void setDate(DateTime? value) {
    state = state.copyWith(
      selectedDate:
          value == null ? null : DateTime(value.year, value.month, value.day),
    );
  }

  void clearFilters() {
    state = state.copyWith(
      selectedCommune: null,
      selectedDirection: null,
      selectedCampusId: null,
      clearDate: true,
      results: const [],
      searched: false,
    );
  }
}

final searchRidesProvider =
    StateNotifierProvider<SearchRidesNotifier, SearchRidesState>(
  (ref) => SearchRidesNotifier(ref),
);
