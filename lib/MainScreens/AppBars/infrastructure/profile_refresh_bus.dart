import 'dart:async';

/// A simple event bus to notify listeners when a user profile should be refreshed.
///
/// This class uses a broadcast `StreamController` to allow multiple subscribers
/// to listen for profile refresh events. Any part of the app can trigger a refresh
/// by calling [notifyProfileRefresh], and all listeners will be notified.
///
/// Example usage:
/// ```dart
/// // Listen for profile refresh events
/// ProfileRefreshBus.onProfileRefresh.listen((_) {
///   // Refresh profile data here
/// });
///
/// // Trigger a profile refresh
/// ProfileRefreshBus.notifyProfileRefresh();
/// ```
class ProfileRefreshBus {
  // Broadcast stream controller allows multiple listeners
  static final _profileController = StreamController<void>.broadcast();

  /// Stream that emits an event whenever the profile should be refreshed.
  static Stream<void> get onProfileRefresh => _profileController.stream;


  /// Notify all subscribers that the profile should be refreshed.
  ///
  /// Adds a `null` event to the stream, which triggers all listeners.
  static void notifyProfileRefresh() {
    _profileController.add(null);
  }
}
