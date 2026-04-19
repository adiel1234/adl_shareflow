import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a pending invite code received from a deep link (shareflow://join/{code}).
/// Set to null once the join dialog has been shown.
final pendingInviteCodeProvider = StateProvider<String?>((ref) => null);
