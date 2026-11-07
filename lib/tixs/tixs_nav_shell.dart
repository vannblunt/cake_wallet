import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'tixs_auth_bridge.dart';
import 'tixs_theme.dart';
import 'tixs_wallet_tab.dart';
import 'tixs_webview_tab.dart';

/// Bottom-navigation shell: Events | My Tickets | Wallet | Profile
///
/// WebView tabs (Events, My Tickets, Profile) are persistent via IndexedStack
/// so navigation state survives tab switches. The Wallet tab hosts the
/// self-custody Solana wallet (create / restore / dashboard).
class TixsNavShell extends StatefulWidget {
  const TixsNavShell({
    super.key,
    required this.authBridge,
  });

  final TixsAuthBridge authBridge;

  @override
  State<TixsNavShell> createState() => _TixsNavShellState();
}

class _TixsNavShellState extends State<TixsNavShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    _TabDef(label: 'Events', icon: Icons.event, url: 'https://tixs.ai/events'),
    _TabDef(label: 'My Tickets', icon: Icons.confirmation_number, url: 'https://tixs.ai/profile/tickets'),
    _TabDef(label: 'Wallet', icon: Icons.account_balance_wallet_outlined, url: null),
    _TabDef(label: 'Profile', icon: Icons.person_outline, url: 'https://tixs.ai/profile'),
  ];

  late final List<GlobalKey<_TixsWebViewTabState>> _webViewKeys = [
    GlobalKey<_TixsWebViewTabState>(),
    GlobalKey<_TixsWebViewTabState>(),
    GlobalKey<_TixsWebViewTabState>(), // unused (wallet tab)
    GlobalKey<_TixsWebViewTabState>(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TixsTheme.surface,
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          if (tab.url == null) {
            return const TixsWalletTab();
          }
          return TixsWebViewTab(
            key: _webViewKeys[i],
            initialUrl: tab.url!,
            authBridge: widget.authBridge,
          );
        }),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final String? url;
  const _TabDef({required this.label, required this.icon, required this.url});
}

// Re-export the state type so GlobalKey can reference it
// ignore: library_private_types_in_public_api
typedef _TixsWebViewTabState = State<TixsWebViewTab>;
