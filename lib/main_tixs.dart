import 'package:flutter/material.dart';
import 'tixs/tixs_app.dart';

/// Tixs app entry point.
///
/// Build target: `flutter run -t lib/main_tixs.dart`
/// (or `flutter build ios -t lib/main_tixs.dart` etc.)
///
/// This keeps the Cake Wallet entry point (main.dart) completely untouched.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TixsApp());
}
