import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'tixs_auth_bridge.dart';
import 'tixs_solana_wallet.dart';

class TixsCollectible {
  final String mint;
  final String name;
  final String? imageUri;
  final String? collectionName;

  const TixsCollectible({
    required this.mint,
    required this.name,
    this.imageUri,
    this.collectionName,
  });

  factory TixsCollectible.fromJson(Map<String, dynamic> j) => TixsCollectible(
        mint: j['mint'] as String? ?? '',
        name: j['name'] as String? ?? 'NFT Ticket',
        imageUri: j['imageUri'] as String?,
        collectionName: j['collectionName'] as String?,
      );

  factory TixsCollectible.fromDasJson(Map<String, dynamic> j) {
    final content = j['content'] as Map<String, dynamic>? ?? {};
    final metadata = content['metadata'] as Map<String, dynamic>? ?? {};
    final links = content['links'] as Map<String, dynamic>? ?? {};
    final grouping = (j['grouping'] as List?)?.cast<Map>().firstWhere(
          (g) => g['group_key'] == 'collection',
          orElse: () => {},
        );
    return TixsCollectible(
      mint: j['id'] as String? ?? '',
      name: metadata['name'] as String? ?? 'NFT Ticket',
      imageUri: links['image'] as String?,
      collectionName: grouping?['group_value'] as String?,
    );
  }
}

class NftClaimResult {
  final String assetAddress;
  final String network;
  final String explorerUrl;
  const NftClaimResult({
    required this.assetAddress,
    required this.network,
    this.explorerUrl = '',
  });
}

/// Orchestrates the NFT claim flow: challenge → sign → claim.
/// Private keys never leave the device; only the Ed25519 signature is sent.
class TixsNftService {
  static const _baseUrl = 'https://tixs.ai';
  // Helius devnet RPC supports Metaplex DAS (getAssetsByOwner).
  // Standard api.devnet.solana.com does not.
  static const _devnetDas = 'https://devnet.helius-rpc.com/?api-key=65a0c74b-f2f1-4098-8876-d0097d1c61d6';

  final TixsAuthBridge _auth;

  TixsNftService(this._auth);

  Future<NftClaimResult> claim(
    String ticketId,
    TixsSolanaWallet wallet,
  ) async {
    if (!wallet.isLoaded) throw StateError('Wallet not loaded');

    final baseHeaders = await _auth.apiHeaders();
    // Add Origin so the backend allows the native-app request.
    final headers = {...baseHeaders, 'Origin': _baseUrl};

    // 1. Fetch challenge — ticketId is the path segment, wallet address in body
    final challengeRes = await http.post(
      Uri.parse('$_baseUrl/api/tickets/$ticketId/nft/challenge'),
      headers: headers,
      body: jsonEncode({'wallet': wallet.address}),
    ).timeout(const Duration(seconds: 15));

    if (challengeRes.statusCode != 200) {
      throw Exception('Challenge failed (${challengeRes.statusCode}): ${challengeRes.body}');
    }

    final message =
        (jsonDecode(challengeRes.body) as Map<String, dynamic>)['message']
            as String;

    // 2. Sign challenge locally — private key never leaves the device;
    //    TixsSolanaWallet.signMessage() returns a Base58-encoded Ed25519 signature.
    final signature = await wallet.signMessage(message);

    // 3. Submit claim
    final claimRes = await http.post(
      Uri.parse('$_baseUrl/api/tickets/$ticketId/nft/claim'),
      headers: headers,
      body: jsonEncode({
        'wallet': wallet.address,
        'message': message,
        'signature': signature,
      }),
    ).timeout(const Duration(seconds: 30));

    if (claimRes.statusCode != 200 && claimRes.statusCode != 201) {
      throw Exception('Claim failed (${claimRes.statusCode}): ${claimRes.body}');
    }

    final d = jsonDecode(claimRes.body) as Map<String, dynamic>;
    final claim = d['claim'] as Map<String, dynamic>? ?? d;
    return NftClaimResult(
      assetAddress: claim['assetAddress'] as String? ?? '',
      network: claim['network'] as String? ?? 'devnet',
      explorerUrl: claim['explorer'] as String? ?? '',
    );
  }

  /// Fetches NFTs owned by this wallet. Tries Tixs backend first; falls back
  /// to Metaplex DAS via the Solana devnet RPC.
  Future<List<TixsCollectible>> fetchCollectibles(String walletAddress) async {
    try {
      final headers = await _auth.apiHeaders();
      final res = await http.get(
        Uri.parse('$_baseUrl/api/nft/my-tickets'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list
            .map((e) => TixsCollectible.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[TixsNft] backend fetch error: $e');
    }
    return _fetchViaDas(walletAddress);
  }

  Future<List<TixsCollectible>> _fetchViaDas(String walletAddress) async {
    try {
      final res = await http.post(
        Uri.parse(_devnetDas),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': '1',
          'method': 'getAssetsByOwner',
          'params': {
            'ownerAddress': walletAddress,
            'page': 1,
            'limit': 20,
          },
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = ((data['result'] as Map?)?['items'] as List?) ?? [];
      return items
          .map((e) => TixsCollectible.fromDasJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TixsNft] DAS fetch error: $e');
      return [];
    }
  }
}
