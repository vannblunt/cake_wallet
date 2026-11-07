import 'dart:convert';
import 'package:http/http.dart' as http;

/// Tixs NFT challenge/claim API client.
///
/// The flow:
/// 1. [fetchChallenge] — POST /api/tickets/:token/nft/challenge
///    Returns a plain-text message and the Solana network name.
/// 2. Caller signs the message bytes with the Solana private key (Ed25519).
///    The base58-encoded signature is passed to [submitClaim].
/// 3. [submitClaim] — POST /api/tickets/:token/nft/claim
///    Returns [NftClaimResult] on success.
///
/// Both calls require the Tixs session cookie, supplied via [headers].
/// Private keys are never sent here; signing happens in the wallet layer.
class TixsNftClient {
  static const _baseUrl = 'https://tixs.ai';

  final Future<Map<String, String>> Function() headersProvider;
  final http.Client _http;

  TixsNftClient({
    required this.headersProvider,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Future<NftChallenge> fetchChallenge({
    required String ticketToken,
    required String walletAddress,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/tickets/$ticketToken/nft/challenge');
    final headers = await headersProvider();
    final response = await _http
        .post(uri, headers: headers, body: jsonEncode({'wallet': walletAddress}))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw NftApiException._fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return NftChallenge(
      message: json['message'] as String,
      network: json['network'] as String? ?? 'devnet',
    );
  }

  Future<NftClaimResult> submitClaim({
    required String ticketToken,
    required String walletAddress,
    required String message,
    required String base58Signature,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/tickets/$ticketToken/nft/claim');
    final headers = await headersProvider();
    final response = await _http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'wallet': walletAddress,
            'message': message,
            'signature': base58Signature,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw NftApiException._fromResponse(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final claim = json['claim'] as Map<String, dynamic>;
    return NftClaimResult(
      state: claim['state'] as String,
      assetAddress: claim['assetAddress'] as String?,
      network: claim['network'] as String? ?? 'devnet',
      explorerUrl: claim['explorer'] as String?,
    );
  }

  Future<NftClaimResult?> getClaimStatus(String ticketToken) async {
    final uri = Uri.parse('$_baseUrl/api/tickets/$ticketToken/nft');
    final headers = await headersProvider();
    final response = await _http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['state'] != null) {
        return NftClaimResult(
          state: json['state'] as String,
          assetAddress: json['assetAddress'] as String?,
          network: json['network'] as String? ?? 'devnet',
          explorerUrl: json['explorer'] as String?,
        );
      }
    }
    return null;
  }

  void dispose() => _http.close();
}

class NftChallenge {
  final String message;
  final String network;
  const NftChallenge({required this.message, required this.network});
}

class NftClaimResult {
  final String state; // 'minting' | 'minted'
  final String? assetAddress;
  final String network;
  final String? explorerUrl;

  const NftClaimResult({
    required this.state,
    this.assetAddress,
    required this.network,
    this.explorerUrl,
  });

  bool get isMinted => state == 'minted';
}

class NftApiException implements Exception {
  final int statusCode;
  final String message;

  const NftApiException({required this.statusCode, required this.message});

  factory NftApiException._fromResponse(http.Response r) {
    String msg;
    try {
      msg = (jsonDecode(r.body) as Map<String, dynamic>)['error'] as String? ??
          r.reasonPhrase ??
          'Unknown error';
    } catch (_) {
      msg = r.reasonPhrase ?? 'Unknown error';
    }
    return NftApiException(statusCode: r.statusCode, message: msg);
  }

  @override
  String toString() => 'NftApiException($statusCode): $message';
}
