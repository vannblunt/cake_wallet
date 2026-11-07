import 'dart:convert';

import 'package:bip39/bip39.dart' as bip39lib;
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_core/utils/bip39_seed.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:on_chain/solana/solana.dart';

class TixsSolanaWallet {
  static const _mnemonicKey = 'tixs_solana_mnemonic';
  static const _addressKey = 'tixs_solana_address';

  final _storage = const FlutterSecureStorage();

  SolanaPrivateKey? _privateKey;
  String? _address;

  String? get address => _address;
  bool get isLoaded => _privateKey != null;

  String generateMnemonic() => bip39lib.generateMnemonic();

  bool validateMnemonic(String mnemonic) => bip39lib.validateMnemonic(mnemonic.trim());

  /// Load wallet from secure storage (call on app start).
  Future<void> load() async {
    final mnemonic = await _storage.read(key: _mnemonicKey);
    if (mnemonic != null) {
      await _derive(mnemonic);
    }
  }

  /// Create a new wallet from the given mnemonic and persist it.
  Future<void> save(String mnemonic) async {
    final cleaned = mnemonic.trim();
    if (!bip39lib.validateMnemonic(cleaned)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }
    await _storage.write(key: _mnemonicKey, value: cleaned);
    await _derive(cleaned);
  }

  /// Remove the wallet from secure storage.
  Future<void> clear() async {
    await _storage.delete(key: _mnemonicKey);
    await _storage.delete(key: _addressKey);
    _privateKey = null;
    _address = null;
  }

  /// Sign a UTF-8 challenge string; returns Base58-encoded Ed25519 signature.
  Future<String> signMessage(String message) async {
    if (_privateKey == null) throw StateError('Wallet not loaded');
    final sig = _privateKey!.sign(utf8.encode(message));
    return Base58Encoder.encode(sig);
  }

  Future<void> _derive(String mnemonic) async {
    final seed = bip39MnemonicToSeed(mnemonic);
    final bip44 = Bip44.fromSeed(seed, Bip44Coins.solana);
    final childKey = bip44.purpose.coin.account(0).change(0).addressIndex(0);
    _privateKey = SolanaPrivateKey.fromSeed(childKey.privateKey.raw);
    _address = _privateKey!.publicKey().toAddress().address;
    await _storage.write(key: _addressKey, value: _address);
  }
}
