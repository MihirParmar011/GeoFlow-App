import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/nominatim_service.dart';
import '../../domain/entities/place_entity.dart';

/// Provides Nominatim search state for the map screen.
///
/// Manages debounced search queries, loading state, and result list.
final nominatimServiceProvider = Provider<NominatimService>((ref) {
  return NominatimService();
});

/// The current search query text.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search results from Nominatim, auto-updating when the query changes.
///
/// Includes a 500ms debounce to avoid spamming the API per Map_V1 spec.
final searchResultsProvider = FutureProvider<List<PlaceEntity>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.trim().isEmpty) return [];

  // Debounce: wait 500ms before executing the search
  await Future.delayed(const Duration(milliseconds: 500));

  // If the query changed during the delay, this provider will be cancelled
  // and re-run by Riverpod automatically.
  if (ref.watch(searchQueryProvider) != query) {
    return [];
  }

  final service = ref.read(nominatimServiceProvider);
  return service.searchPlaces(query);
});
