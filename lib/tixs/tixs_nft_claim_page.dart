import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tixs_auth_bridge.dart';
import 'tixs_theme.dart';

// ignore: depend_on_referenced_packages
import 'package:cw_core/wallet_base.dart';

/// Native NFT claim UI for Tixs Metaplex Core collectibles.
///
/// Flow:
/// 1. Show ticket info and wallet address.
/// 2. User taps "Claim Collectible" — show disclaimer dialog.
/// 3. After approval: fetch challenge → sign with Solana key → submit claim.
/// 4. Show result (minted asset address + Explorer link).
///
/// Private keys never leave the device. The Tixs backend receives only the
/// public wallet address and an Ed25519 signature of the challenge message.
class TixsNftClaimPage extends StatefulWidget {
  const TixsNftClaimPage({
    super.key,
    required this.ticketToken,
    required this.authBridge,
    required this.wallet,
  });

  final String ticketToken;
  final TixsAuthBridge authBridge;
  final WalletBase wallet;

  @override
  State<TixsNftClaimPage> createState() => _TixsNftClaimPageState();
}

class _TixsNftClaimPageState extends State<TixsNftClaimPage> {
  _ClaimState _state = _ClaimState.idle;
  String? _error;
  String? _assetAddress;
  String? _explorerUrl;
  String? _claimNetwork;

  String get _walletAddress {
    // For Solana wallets the primary address is the base58 public key
    return widget.wallet.walletAddresses.address;
  }

  Future<void> _startClaim() async {
    final confirmed = await _showDisclaimerDialog();
    if (!confirmed) return;

    setState(() {
      _state = _ClaimState.fetchingChallenge;
      _error = null;
    });

    try {
      final headers = await widget.authBridge.apiHeaders();
      final challengeResponse = await _post(
        '/api/tickets/${widget.ticketToken}/nft/challenge',
        headers,
        {'wallet': _walletAddress},
      );

      final message = challengeResponse['message'] as String;
      final network = challengeResponse['network'] as String? ?? 'devnet';

      setState(() => _state = _ClaimState.signing);

      // Sign the message with the Solana wallet private key
      // wallet.signMessage() uses Ed25519 and returns base64
      final base64Sig = await widget.wallet.signMessage(message);
      // Tixs backend expects base58 — convert
      final sigBytes = base64Decode(base64Sig);
      final base58Sig = _base58Encode(sigBytes);

      setState(() => _state = _ClaimState.minting);

      final claimResponse = await _post(
        '/api/tickets/${widget.ticketToken}/nft/claim',
        headers,
        {
          'wallet': _walletAddress,
          'message': message,
          'signature': base58Sig,
        },
      );

      final claim = claimResponse['claim'] as Map<String, dynamic>;
      setState(() {
        _state = _ClaimState.success;
        _assetAddress = claim['assetAddress'] as String?;
        _claimNetwork = claim['network'] as String? ?? network;
        _explorerUrl = claim['explorer'] as String?;
      });
    } catch (e) {
      setState(() {
        _state = _ClaimState.error;
        _error = e is _ApiException ? e.message : 'An error occurred. Please try again.';
      });
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    // Using dart:io HttpClient to get cookie support
    final uri = Uri.https('tixs.ai', path);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      headers.forEach(request.headers.set);
      request.write(jsonEncode(body));
      final response = await request.close();
      final raw = await response.transform(utf8.decoder).join();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        final msg = json['error'] as String? ?? 'Error ${response.statusCode}';
        throw _ApiException(response.statusCode, msg);
      }
      return json;
    } finally {
      client.close();
    }
  }

  Future<bool> _showDisclaimerDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: TixsTheme.surfaceCard,
            title: const Text(
              'Claim Collectible',
              style: TextStyle(color: TixsTheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Solana wallet will sign a message to claim this collectible NFT.',
                  style: TextStyle(color: TixsTheme.onSurfaceMuted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Wallet: ${_walletAddress.substring(0, 8)}…${_walletAddress.substring(_walletAddress.length - 6)}',
                  style: const TextStyle(color: TixsTheme.onSurface, fontSize: 13, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Important: This collectible does not transfer or affect your event admission. '
                  'Your Tixs account cannot recover your wallet — keep your recovery phrase safe.',
                  style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: TixsTheme.onSurfaceMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: TixsTheme.primary),
                child: const Text('Sign & Claim'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TixsTheme.surface,
      appBar: AppBar(title: const Text('Claim Collectible')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            if (_state == _ClaimState.idle || _state == _ClaimState.error)
              ElevatedButton(
                onPressed: _startClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TixsTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Claim Collectible', style: TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TixsTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TixsTheme.divider),
      ),
      child: switch (_state) {
        _ClaimState.idle => _infoContent(),
        _ClaimState.fetchingChallenge => _loadingContent('Preparing claim…'),
        _ClaimState.signing => _loadingContent('Signing with wallet…'),
        _ClaimState.minting => _loadingContent('Minting collectible on Solana…'),
        _ClaimState.success => _successContent(),
        _ClaimState.error => _errorContent(),
      },
    );
  }

  Widget _infoContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solana Wallet', style: TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${_walletAddress.substring(0, 12)}…',
            style: const TextStyle(color: TixsTheme.onSurface, fontFamily: 'monospace', fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Claim a Metaplex Core collectible for this event ticket. '
            'The collectible is a public on-chain record of attendance.',
            style: TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 13),
          ),
        ],
      );

  Widget _loadingContent(String label) => Row(
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TixsTheme.primary)),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: TixsTheme.onSurface)),
        ],
      );

  Widget _successContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF34D399), size: 24),
              SizedBox(width: 10),
              Text('Collectible Minted!', style: TextStyle(color: Color(0xFF34D399), fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_assetAddress != null) ...[
            const SizedBox(height: 12),
            Text('Asset', style: const TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 12)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => Clipboard.setData(ClipboardData(text: _assetAddress!)),
              child: Text(
                _assetAddress!,
                style: const TextStyle(color: TixsTheme.onSurface, fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
          if (_explorerUrl != null) ...[
            const SizedBox(height: 12),
            Text(
              'View on Solana Explorer →',
              style: const TextStyle(color: TixsTheme.primary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Note: This collectible does not affect your admission ticket.',
            style: TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 12),
          ),
        ],
      );

  Widget _errorContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: TixsTheme.error, size: 20),
              SizedBox(width: 8),
              Text('Claim Failed', style: TextStyle(color: TixsTheme.error, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_error ?? 'Unknown error', style: const TextStyle(color: TixsTheme.onSurfaceMuted, fontSize: 13)),
        ],
      );

  static const _alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  static String _base58Encode(Uint8List bytes) {
    var value = BigInt.zero;
    for (final b in bytes) {
      value = value * BigInt.from(256) + BigInt.from(b);
    }
    var result = '';
    while (value > BigInt.zero) {
      final rem = value % BigInt.from(58);
      result = _alphabet[rem.toInt()] + result;
      value ~/= BigInt.from(58);
    }
    for (final b in bytes) {
      if (b == 0) result = '1$result'; else break;
    }
    return result;
  }
}

enum _ClaimState { idle, fetchingChallenge, signing, minting, success, error }

class _ApiException implements Exception {
  final int status;
  final String message;
  _ApiException(this.status, this.message);
}
