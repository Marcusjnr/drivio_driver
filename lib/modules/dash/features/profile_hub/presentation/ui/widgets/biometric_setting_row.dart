import 'dart:async';

import 'package:flutter/material.dart';

import 'package:drivio_driver/modules/commons/all.dart';
import 'package:drivio_driver/modules/commons/biometric/biometric_service.dart';
import 'package:drivio_driver/modules/commons/storage/secure_store.dart';

/// Settings row for biometric sign in, ported from
/// kalabash_mobile_v2's settings page.
///
/// Turning it ON requires passing the biometric prompt there and then,
/// so nobody can enable it on a phone they merely have in hand. Turning
/// it OFF is immediate and also forgets the stored password, since the
/// only reason to keep one is to unlock it with a fingerprint.
///
/// Hidden entirely when the device has no enrolled biometric, rather
/// than shown as a dead toggle.
class BiometricSettingRow extends StatefulWidget {
  const BiometricSettingRow({super.key, this.divider = true});

  final bool divider;

  @override
  State<BiometricSettingRow> createState() => _BiometricSettingRowState();
}

class _BiometricSettingRowState extends State<BiometricSettingRow> {
  bool _available = false;
  bool _isFaceId = false;
  bool _enabled = false;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final BiometricCheckResult check =
        await locator<BiometricService>().check();
    final bool stored =
        await locator<SecureStore>().readBool(SecureKeys.enableLocalLogin);
    if (!mounted) return;
    setState(() {
      _available = check.canCheck && check.types.isNotEmpty;
      _isFaceId = check.hasFaceId;
      _enabled = stored;
      _loaded = true;
    });
  }

  Future<void> _onToggle(bool next) async {
    if (_busy) return;
    final SecureStore store = locator<SecureStore>();

    if (!next) {
      setState(() => _busy = true);
      await store.clearBiometricCredentials();
      if (!mounted) return;
      setState(() {
        _enabled = false;
        _busy = false;
      });
      AppNotifier.success(message: 'Biometric sign in is off.');
      return;
    }

    final BiometricService biometric = locator<BiometricService>();
    final BiometricCheckResult check = await biometric.check();
    if (!check.canCheck || check.types.isEmpty) {
      AppNotifier.warning(
        message: 'Set up a fingerprint or face on this phone first.',
      );
      return;
    }

    setState(() => _busy = true);
    final BiometricAuthResult result = await biometric.authenticate(
      reason: 'Confirm it is you to turn on biometric sign in',
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() => _busy = false);
      AppNotifier.error(
        message: result.errorMessage ?? 'That did not work. Try again.',
      );
      return;
    }

    // Nothing to unlock without a stored password. It is written on every
    // successful sign in, so this only bites a session restored from an
    // older build.
    final String? password = await store.readString(SecureKeys.userPassword);
    if (password == null || password.isEmpty) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppNotifier.warning(
        message: 'Sign out and sign in once, then turn this on.',
      );
      return;
    }

    await store.writeBool(SecureKeys.enableLocalLogin, true);
    if (!mounted) return;
    setState(() {
      _enabled = true;
      _busy = false;
    });
    AppNotifier.success(message: 'Biometric sign in is on.');
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || !_available) return const SizedBox.shrink();

    return FieldRow(
      label: _isFaceId ? 'Sign in with Face ID' : 'Sign in with fingerprint',
      chevron: false,
      divider: widget.divider,
      onTap: _busy ? null : () => _onToggle(!_enabled),
      right: Switch.adaptive(
        value: _enabled,
        onChanged: _busy ? null : _onToggle,
        activeThumbColor: context.coral,
      ),
    );
  }
}
