import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Read and display Metaplex Core assets (mpl-core program).
///
/// Tixs collectibles are Metaplex Core assets, NOT Token Metadata NFTs.
/// Cake Wallet's existing Solana module handles Token Metadata only.
/// This class reads Core asset accounts directly via Solana RPC.
///
/// MPL Core program ID: CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d
class MetaplexCoreReader {
  static const _coreProgram = 'CoREENxT6tW1HoK8ypY1SxRMZTcVPm7R94rH4PZNhX7d';

  final String rpcUrl;
  final http.Client _http;

  MetaplexCoreReader({required this.rpcUrl, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  /// Fetch a Core asset by its on-chain address.
  Future<CoreAsset?> fetchAsset(String assetAddress) async {
    try {
      final accountData = await _getAccountInfo(assetAddress);
      if (accountData == null) return null;

      final asset = _decodeCoreAsset(assetAddress, accountData);
      if (asset == null) return null;

      // Fetch off-chain metadata if URI present
      if (asset.uri != null && asset.uri!.isNotEmpty) {
        final meta = await _fetchOffchainMetadata(asset.uri!);
        return asset.copyWith(offchainName: meta?['name'], imageUrl: meta?['image']);
      }
      return asset;
    } catch (e) {
      debugPrint('[MetaplexCore] fetchAsset error for $assetAddress: $e');
      return null;
    }
  }

  /// Fetch all Core assets owned by [ownerAddress] via getProgramAccounts.
  Future<List<CoreAsset>> fetchAssetsForOwner(String ownerAddress) async {
    try {
      final response = await _rpc('getProgramAccounts', [
        _coreProgram,
        {
          'encoding': 'base64',
          'filters': [
            {'memcmp': {'offset': 1, 'bytes': ownerAddress}},
          ],
        },
      ]);

      final accounts = response as List<dynamic>? ?? [];
      final assets = <CoreAsset>[];

      for (final acct in accounts) {
        final pubkey = acct['pubkey'] as String?;
        final dataList = (acct['account']?['data'] as List<dynamic>?);
        if (pubkey == null || dataList == null) continue;

        final bytes = base64Decode(dataList[0] as String);
        final asset = _decodeCoreAsset(pubkey, bytes);
        if (asset != null) assets.add(asset);
      }

      // Enrich with off-chain metadata in parallel
      final enriched = await Future.wait(
        assets.map((a) async {
          if (a.uri == null || a.uri!.isEmpty) return a;
          try {
            final meta = await _fetchOffchainMetadata(a.uri!);
            return a.copyWith(offchainName: meta?['name'], imageUrl: meta?['image']);
          } catch (_) {
            return a;
          }
        }),
      );
      return enriched;
    } catch (e) {
      debugPrint('[MetaplexCore] fetchAssetsForOwner error: $e');
      return [];
    }
  }

  Future<Uint8List?> _getAccountInfo(String address) async {
    final result = await _rpc('getAccountInfo', [
      address,
      {'encoding': 'base64'},
    ]);

    final value = result?['value'];
    if (value == null) return null;
    final data = value['data'] as List<dynamic>?;
    if (data == null || data.isEmpty) return null;
    return base64Decode(data[0] as String);
  }

  /// Minimal MPL Core V1 asset deserialization.
  /// Layout (little-endian):
  ///   [0]      u8   key (3 = AssetV1)
  ///   [1..32]  Pubkey  owner
  ///   [33..64] Pubkey  update_authority (or collection address when variant=0)
  ///   [65]     bool    mutable
  ///   [66..N]  String  name (u32 len prefix)
  ///   [N+4..M] String  uri  (u32 len prefix)
  CoreAsset? _decodeCoreAsset(String address, Uint8List data) {
    try {
      if (data.length < 70) return null;
      final key = data[0];
      // Key 3 = AssetV1
      if (key != 3) return null;

      final owner = _base58Encode(data.sublist(1, 33));

      int offset = 65; // skip update_authority (32b) + mutable (1b)
      final nameLen = _readU32LE(data, offset);
      offset += 4;
      if (offset + nameLen > data.length) return null;
      final name = utf8.decode(data.sublist(offset, offset + nameLen));
      offset += nameLen;

      if (offset + 4 > data.length) return null;
      final uriLen = _readU32LE(data, offset);
      offset += 4;
      String? uri;
      if (uriLen > 0 && offset + uriLen <= data.length) {
        uri = utf8.decode(data.sublist(offset, offset + uriLen));
      }

      return CoreAsset(
        address: address,
        owner: owner,
        name: name,
        uri: uri,
      );
    } catch (e) {
      debugPrint('[MetaplexCore] decode error for $address: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchOffchainMetadata(String uri) async {
    try {
      if (!uri.startsWith('https://')) return null;
      final r = await _http.get(Uri.parse(uri)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<dynamic> _rpc(String method, List<dynamic> params) async {
    final r = await _http.post(
      Uri.parse(rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': method,
        'params': params,
      }),
    ).timeout(const Duration(seconds: 20));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (body['error'] != null) {
      throw Exception('RPC error: ${body['error']}');
    }
    return body['result'];
  }

  static int _readU32LE(Uint8List data, int offset) =>
      data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);

  // Minimal base58 encode for display (Solana addresses are base58)
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

  void dispose() => _http.close();
}

class CoreAsset {
  final String address;
  final String owner;
  final String name;
  final String? uri;
  final String? offchainName;
  final String? imageUrl;

  const CoreAsset({
    required this.address,
    required this.owner,
    required this.name,
    this.uri,
    this.offchainName,
    this.imageUrl,
  });

  String get displayName => offchainName ?? name;

  String explorerUrl({String network = 'mainnet-beta'}) {
    final cluster = network == 'devnet' ? '?cluster=devnet' : '';
    return 'https://explorer.solana.com/address/$address$cluster';
  }

  CoreAsset copyWith({String? offchainName, String? imageUrl}) => CoreAsset(
        address: address,
        owner: owner,
        name: name,
        uri: uri,
        offchainName: offchainName ?? this.offchainName,
        imageUrl: imageUrl ?? this.imageUrl,
      );
}
