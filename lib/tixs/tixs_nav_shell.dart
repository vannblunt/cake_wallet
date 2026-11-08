import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'tixs_auth_bridge.dart';
import 'tixs_nft_service.dart';
import 'tixs_solana_wallet.dart';
import 'tixs_theme.dart';
import 'tixs_wallet_tab.dart';
import 'tixs_webview_tab.dart';

/// Bottom-navigation shell: Events | My Tickets | Wallet | Profile
///
/// WebView tabs are persistent via IndexedStack so navigation state survives
/// tab switches. The Wallet tab hosts the self-custody Solana wallet.
/// The shell owns the wallet and NFT service so WebView tabs can trigger
/// claims that update the wallet dashboard.
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

  late final TixsSolanaWallet _wallet;
  late final TixsNftService _nftService;
  late final ValueNotifier<int> _collectibleRefresh;

  static const _tabs = [
    _TabDef(label: 'Events', icon: Icons.event, url: 'https://tixs.ai/events'),
    _TabDef(label: 'My Tickets', icon: Icons.confirmation_number, url: 'https://tixs.ai/profile/tickets'),
    _TabDef(label: 'Wallet', icon: Icons.account_balance_wallet_outlined, url: null),
    _TabDef(label: 'Profile', icon: Icons.person_outline, url: 'https://tixs.ai/profile'),
  ];

  late final List<GlobalKey<_TixsWebViewTabState>> _webViewKeys = [
    GlobalKey<_TixsWebViewTabState>(),
    GlobalKey<_TixsWebViewTabState>(),
    GlobalKey<_TixsWebViewTabState>(), // unused (wallet slot)
    GlobalKey<_TixsWebViewTabState>(),
  ];

  @override
  void initState() {
    super.initState();
    _wallet = TixsSolanaWallet();
    _nftService = TixsNftService(widget.authBridge);
    _collectibleRefresh = ValueNotifier(0);
    _wallet.load(); // non-blocking; wallet tab reacts to isLoaded
  }

  @override
  void dispose() {
    _collectibleRefresh.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _handleNativeMessage(
      Map<String, dynamic> msg) async {
    final action = msg['action'] as String?;
    if (action == 'claimNft') {
      final ticketId = msg['ticketId'] as String?;
      if (ticketId == null || ticketId.isEmpty) {
        return {'success': false, 'error': 'missing ticketId'};
      }
      if (!_wallet.isLoaded) {
        return {'success': false, 'error': 'wallet_not_set_up'};
      }
      try {
        final result = await _nftService.claim(ticketId, _wallet);
        _collectibleRefresh.value++; // triggers wallet dashboard refresh
        return {
          'success': true,
          'nftMint': result.nftMint,
          'txSignature': result.txSignature,
        };
      } catch (e) {
        return {'success': false, 'error': e.toString()};
      }
    }
    return {'error': 'unknown action: $action'};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TixsTheme.surface,
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          if (tab.url == null) {
            return TixsWalletTab(
              wallet: _wallet,
              nftService: _nftService,
              refreshNotifier: _collectibleRefresh,
            );
          }
          return TixsWebViewTab(
            key: _webViewKeys[i],
            initialUrl: tab.url!,
            authBridge: widget.authBridge,
            onNativeMessage: _handleNativeMessage,
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
