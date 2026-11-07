import 'package:flutter/material.dart';
import 'tixs_auth_bridge.dart';
import 'tixs_nav_shell.dart';
import 'tixs_theme.dart';
import 'tixs_wallet_tab.dart';

/// Tixs app root.
///
/// Instantiate and return this from main() when TIXS_MODE is enabled.
/// The existing Cake app is unchanged; this is a parallel entry point.
///
/// Usage in main_tixs.dart:
///   void main() async {
///     WidgetsFlutterBinding.ensureInitialized();
///     runApp(const TixsApp());
///   }
class TixsApp extends StatelessWidget {
  const TixsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tixs',
      debugShowCheckedModeBanner: false,
      theme: TixsTheme.darkTheme(),
      home: TixsHome(),
    );
  }
}

class TixsHome extends StatefulWidget {
  const TixsHome({super.key});

  @override
  State<TixsHome> createState() => _TixsHomeState();
}

class _TixsHomeState extends State<TixsHome> {
  late final TixsAuthBridge _authBridge;

  @override
  void initState() {
    super.initState();
    _authBridge = TixsAuthBridge();
  }

  @override
  Widget build(BuildContext context) {
    return TixsNavShell(
      authBridge: _authBridge,
      walletTab: const TixsWalletTab(),
    );
  }
}
