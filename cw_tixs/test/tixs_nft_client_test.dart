import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cw_tixs/tixs_nft_client.dart';

void main() {
  group('TixsNftClient', () {
    const walletAddress = '7EcDhSYGxXyscszYEp35KHN8vvw3svAuLKTzXwCFLtV1';
    const ticketToken = 'test-ticket-token-123';

    Map<String, String> mockHeaders() => {
          'Content-Type': 'application/json',
          'Cookie': '__Host-tixs-session=test-session',
          'Origin': 'https://tixs.ai',
        };

    test('fetchChallenge returns message and network', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/tickets/$ticketToken/nft/challenge');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['wallet'], walletAddress);

        return http.Response(
          jsonEncode({
            'message': 'Tixs NFT collectible claim\nSite: https://tixs.ai\nNetwork: devnet\n'
                'Asset: 9xyz\nWallet: $walletAddress\nNonce: abc123\n'
                'Expires: 2026-01-01T00:00:00.000Z\n'
                'This signature claims a public collectible. It does not transfer admission or authorize a payment.',
            'network': 'devnet',
          }),
          200,
        );
      });

      final client = TixsNftClient(headersProvider: mockHeaders, httpClient: mockClient);
      final challenge = await client.fetchChallenge(
        ticketToken: ticketToken,
        walletAddress: walletAddress,
      );

      expect(challenge.network, 'devnet');
      expect(challenge.message, contains('Tixs NFT collectible claim'));
      expect(challenge.message, contains('does not transfer admission'));
    });

    test('submitClaim returns minted result', () async {
      const assetAddress = 'AssetAddr123';
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/tickets/$ticketToken/nft/claim');
        return http.Response(
          jsonEncode({
            'claim': {
              'state': 'minted',
              'assetAddress': assetAddress,
              'network': 'devnet',
              'explorer': 'https://explorer.solana.com/address/$assetAddress?cluster=devnet',
            }
          }),
          200,
        );
      });

      final client = TixsNftClient(headersProvider: mockHeaders, httpClient: mockClient);
      final result = await client.submitClaim(
        ticketToken: ticketToken,
        walletAddress: walletAddress,
        message: 'test message',
        base58Signature: 'base58sig123',
      );

      expect(result.isMinted, true);
      expect(result.assetAddress, assetAddress);
      expect(result.network, 'devnet');
      expect(result.explorerUrl, contains('devnet'));
    });

    test('fetchChallenge throws NftApiException on error', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': 'This ticket is not available for a new NFT claim.'}),
            409,
          ));

      final client = TixsNftClient(headersProvider: mockHeaders, httpClient: mockClient);
      expect(
        () => client.fetchChallenge(ticketToken: ticketToken, walletAddress: walletAddress),
        throwsA(isA<NftApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    });

    test('fetchChallenge throws on 401 (not signed in)', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': 'Sign in with the account that received this ticket to claim its collectible.'}),
            401,
          ));

      final client = TixsNftClient(headersProvider: mockHeaders, httpClient: mockClient);
      expect(
        () => client.fetchChallenge(ticketToken: ticketToken, walletAddress: walletAddress),
        throwsA(isA<NftApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });
}
