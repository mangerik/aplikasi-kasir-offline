import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Kunci otomatis setelah sekian menit tanpa aktivitas (PRD v1.1 §8.3.B).
///
/// Dua janji yang dijaga widget ini:
/// 1. **Keranjang tidak pernah dibuang** (AC-8.12). Mengunci hanya
///    mengubah keadaan sesi; provider keranjang tidak disentuh sama
///    sekali, sehingga layar PIN benar-benar sekadar "menutupi" layar
///    Kasir — bukan mengulang transaksi dari nol di depan pembeli.
/// 2. **Waktu di latar belakang ikut dihitung.** HP yang dikantongi
///    setengah jam lalu dibuka lagi harus tetap terkunci; kalau tidak,
///    fiturnya hanya berlaku untuk orang yang menatap layar.
///
/// Mati secara default (`auto_lock_minutes = 0`) — dan saat mati, tidak
/// ada satu pun timer yang dijalankan.
class AutoLockScope extends ConsumerStatefulWidget {
  const AutoLockScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoLockScope> createState() => _AutoLockScopeState();
}

class _AutoLockScopeState extends ConsumerState<AutoLockScope>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Duration? get _timeout {
    final session = ref.read(sessionProvider);
    if (!session.multiUserEnabled || session.user == null || session.locked) {
      return null;
    }
    return ref.read(multiUserSettingsProvider).value?.autoLockDuration;
  }

  void _touch() {
    _lastActivity = DateTime.now();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    final timeout = _timeout;
    if (timeout == null) return;
    _timer = Timer(timeout, _lock);
  }

  void _lock() {
    _timer?.cancel();
    ref.read(sessionProvider.notifier).lock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _timer?.cancel();
      return;
    }
    final timeout = _timeout;
    if (timeout == null) return;
    if (DateTime.now().difference(_lastActivity) >= timeout) {
      _lock();
    } else {
      _restart();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Timer disetel ulang saat setelan/sesi berubah — mis. tepat setelah
    // kasir baru masuk, atau setelah pemilik mengubah durasinya.
    ref.listen(sessionProvider, (previous, next) => _touch());
    ref.listen(multiUserSettingsProvider, (previous, next) => _touch());

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _touch(),
      child: widget.child,
    );
  }
}
