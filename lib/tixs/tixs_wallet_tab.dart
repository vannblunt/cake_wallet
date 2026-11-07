import 'package:flutter/material.dart';
import 'tixs_theme.dart';

/// Wallet tab shell for the Tixs app.
///
/// This wraps Cake's existing wallet management UI narrowed to the Solana
/// wallet. When no Solana wallet is set up, shows a setup prompt.
/// Collectibles (Metaplex Core assets) are shown below the SOL balance.
///
/// Wallet setup is optional — users who skip it can still use all event and
/// ticket features via the WebView tabs.
class TixsWalletTab extends StatelessWidget {
  const TixsWalletTab({
    super.key,
    this.walletWidget,
    this.collectiblesWidget,
  });

  /// Cake's existing dashboard/wallet widget for Solana.
  /// Pass null when no wallet is loaded yet.
  final Widget? walletWidget;

  /// Collectibles list widget from MetaplexCoreReader. Optional.
  final Widget? collectiblesWidget;

  @override
  Widget build(BuildContext context) {
    if (walletWidget != null) {
      return Column(
        children: [
          Expanded(child: walletWidget!),
          if (collectiblesWidget != null)
            SizedBox(height: 240, child: collectiblesWidget!),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: TixsTheme.primary),
            const SizedBox(height: 20),
            const Text(
              'Wallet (Optional)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TixsTheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A self-custody Solana wallet lets you claim event collectibles '
              'as on-chain NFTs. You can browse events and use your tickets without it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1030),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4C1D95)),
              ),
              child: const Text(
                '⚠ Your Tixs account cannot recover your wallet. '
                'You are responsible for saving your recovery phrase.',
                style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _openWalletSetup(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: TixsTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Set Up Wallet', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _openWalletRestore(context),
              child: const Text(
                'Restore existing wallet',
                style: TextStyle(color: TixsTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWalletSetup(BuildContext context) {
    // Navigate to Cake's existing new wallet flow filtered to Solana.
    // Route: Routes.newWallet with WalletType.solana argument.
    // Exact navigation depends on di.dart being initialized.
    // Placeholder until DI is wired for Tixs mode.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet setup coming soon. DI initialization required.'),
        backgroundColor: TixsTheme.surfaceCard,
      ),
    );
  }

  void _openWalletRestore(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet restore coming soon.'),
        backgroundColor: TixsTheme.surfaceCard,
      ),
    );
  }
}

/// Compact collectibles list for the wallet tab.
class TixsCollectiblesList extends StatelessWidget {
  const TixsCollectiblesList({super.key, required this.collectibles});

  final List<_CollectiblePreview> collectibles;

  @override
  Widget build(BuildContext context) {
    if (collectibles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Collectibles',
              style: TextStyle(color: TixsTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
        ),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: collectibles.length,
            itemBuilder: (_, i) => _CollectibleCard(item: collectibles[i]),
          ),
        ),
      ],
    );
  }
}

class _CollectiblePreview {
  final String name;
  final String? imageUrl;
  final String address;
  const _CollectiblePreview({required this.name, this.imageUrl, required this.address});
}

class _CollectibleCard extends StatelessWidget {
  final _CollectiblePreview item;
  const _CollectibleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: TixsTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TixsTheme.divider),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                  : const Center(child: Icon(Icons.image_not_supported, color: TixsTheme.onSurfaceMuted)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: TixsTheme.onSurface, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
