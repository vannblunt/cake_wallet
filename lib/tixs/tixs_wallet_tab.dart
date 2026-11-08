import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tixs_solana_wallet.dart';
import 'tixs_theme.dart';

class TixsWalletTab extends StatefulWidget {
  const TixsWalletTab({super.key});

  @override
  State<TixsWalletTab> createState() => _TixsWalletTabState();
}

class _TixsWalletTabState extends State<TixsWalletTab> {
  final _wallet = TixsSolanaWallet();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _wallet.load().then((_) => setState(() => _loading = false));
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: TixsTheme.primary));
    }
    if (_wallet.isLoaded) {
      return _WalletDashboard(wallet: _wallet, onClear: () async {
        await _wallet.clear();
        _refresh();
      });
    }
    return _WalletEmpty(wallet: _wallet, onWalletSaved: _refresh);
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _WalletEmpty extends StatelessWidget {
  const _WalletEmpty({required this.wallet, required this.onWalletSaved});
  final TixsSolanaWallet wallet;
  final VoidCallback onWalletSaved;

  @override
  Widget build(BuildContext context) {
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
              'Solana Wallet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TixsTheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'A self-custody Solana wallet lets you claim event tickets '
              'as on-chain NFTs. You can browse events and use tickets without it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: TixsTheme.onSurfaceMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1030),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4C1D95)),
              ),
              child: const Text(
                '⚠ Your Tixs account cannot recover your wallet. '
                'You are responsible for saving your recovery phrase.',
                style: TextStyle(
                    color: Color(0xFFFBBF24), fontSize: 12, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _openCreate(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: TixsTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create New Wallet',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _openRestore(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: TixsTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Restore Existing Wallet',
                  style: TextStyle(color: TixsTheme.primary, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    final mnemonic = wallet.generateMnemonic();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CreateWalletPage(
        mnemonic: mnemonic,
        wallet: wallet,
        onSaved: onWalletSaved,
      ),
    ));
  }

  void _openRestore(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          _RestoreWalletPage(wallet: wallet, onSaved: onWalletSaved),
    ));
  }
}

// ── Create wallet ─────────────────────────────────────────────────────────────

class _CreateWalletPage extends StatefulWidget {
  const _CreateWalletPage(
      {required this.mnemonic,
      required this.wallet,
      required this.onSaved});
  final String mnemonic;
  final TixsSolanaWallet wallet;
  final VoidCallback onSaved;

  @override
  State<_CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends State<_CreateWalletPage> {
  bool _confirmed = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final words = widget.mnemonic.split(' ');
    return Scaffold(
      backgroundColor: TixsTheme.surface,
      appBar: AppBar(
        backgroundColor: TixsTheme.surface,
        title: const Text('Recovery Phrase',
            style: TextStyle(color: TixsTheme.onSurface)),
        iconTheme: const IconThemeData(color: TixsTheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Write these 12 words down in order and store them somewhere safe. '
                'You will need them to recover your wallet.',
                style: TextStyle(
                    color: TixsTheme.onSurfaceMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              _MnemonicGrid(words: words),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.mnemonic));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied to clipboard')));
                },
                icon: const Icon(Icons.copy, color: TixsTheme.primary, size: 16),
                label: const Text('Copy phrase',
                    style: TextStyle(color: TixsTheme.primary)),
              ),
              const Spacer(),
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                activeColor: TixsTheme.primary,
                title: const Text(
                  'I have saved my recovery phrase',
                  style: TextStyle(color: TixsTheme.onSurface, fontSize: 14),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (_confirmed && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TixsTheme.primary,
                  disabledBackgroundColor: TixsTheme.surfaceCard,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create Wallet',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.wallet.save(widget.mnemonic);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Restore wallet ────────────────────────────────────────────────────────────

class _RestoreWalletPage extends StatefulWidget {
  const _RestoreWalletPage({required this.wallet, required this.onSaved});
  final TixsSolanaWallet wallet;
  final VoidCallback onSaved;

  @override
  State<_RestoreWalletPage> createState() => _RestoreWalletPageState();
}

class _RestoreWalletPageState extends State<_RestoreWalletPage> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TixsTheme.surface,
      appBar: AppBar(
        backgroundColor: TixsTheme.surface,
        title: const Text('Restore Wallet',
            style: TextStyle(color: TixsTheme.onSurface)),
        iconTheme: const IconThemeData(color: TixsTheme.onSurface),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter your 12 or 24 word recovery phrase, '
                'with words separated by spaces.',
                style: TextStyle(
                    color: TixsTheme.onSurfaceMuted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                maxLines: 5,
                style: const TextStyle(color: TixsTheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'word1 word2 word3 ...',
                  hintStyle:
                      const TextStyle(color: TixsTheme.onSurfaceMuted),
                  filled: true,
                  fillColor: TixsTheme.surfaceCard,
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _restore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TixsTheme.primary,
                  disabledBackgroundColor: TixsTheme.surfaceCard,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Restore Wallet',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restore() async {
    final phrase = _ctrl.text.trim();
    if (!widget.wallet.validateMnemonic(phrase)) {
      setState(() => _error = 'Invalid recovery phrase — check spelling and word count');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.wallet.save(phrase);
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }
}

// ── Wallet dashboard ──────────────────────────────────────────────────────────

class _WalletDashboard extends StatelessWidget {
  const _WalletDashboard({required this.wallet, required this.onClear});
  final TixsSolanaWallet wallet;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final address = wallet.address ?? '';
    final short = address.length > 16
        ? '${address.substring(0, 8)}…${address.substring(address.length - 8)}'
        : address;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Solana Wallet',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  const Text('— SOL',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(short,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontFamily: 'monospace')),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy,
                            color: Colors.white70, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: address));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Address copied')));
                        },
                        tooltip: 'Copy address',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Collectibles',
                style: TextStyle(
                    color: TixsTheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TixsTheme.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.collections_outlined,
                      size: 40, color: TixsTheme.onSurfaceMuted),
                  SizedBox(height: 8),
                  Text('No collectibles yet',
                      style: TextStyle(color: TixsTheme.onSurfaceMuted)),
                  SizedBox(height: 4),
                  Text('Claim an NFT ticket to see it here',
                      style: TextStyle(
                          color: TixsTheme.onSurfaceMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () => _confirmRemove(context),
              child: const Text('Remove wallet from this device',
                  style: TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TixsTheme.surfaceCard,
        title: const Text('Remove wallet?',
            style: TextStyle(color: TixsTheme.onSurface)),
        content: const Text(
          'This removes the wallet from this device. '
          'Make sure you have your recovery phrase before continuing.',
          style: TextStyle(color: TixsTheme.onSurfaceMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: TixsTheme.primary))),
          TextButton(
              onPressed: () { Navigator.pop(ctx); onClear(); },
              child: const Text('Remove',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

// ── Mnemonic grid ─────────────────────────────────────────────────────────────

class _MnemonicGrid extends StatelessWidget {
  const _MnemonicGrid({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.6,
      ),
      itemCount: words.length,
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: TixsTheme.surfaceCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TixsTheme.divider),
        ),
        alignment: Alignment.center,
        child: Text(
          '${i + 1}. ${words[i]}',
          style: const TextStyle(
              color: TixsTheme.onSurface,
              fontSize: 12,
              fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
