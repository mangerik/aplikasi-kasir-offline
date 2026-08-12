import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pin_throttle.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../domain/entities/app_user.dart';
import '../../settings/widgets/pin_keypad.dart';
import '../providers/auth_providers.dart';
import '../widgets/user_avatar.dart';
import 'forgot_pin_screen.dart';

/// Layar **Masuk** (PRD v1.1 §8.3.B, §8.6) — rute di luar shell navigasi.
///
/// Alurnya **pilih nama dulu, baru PIN** (K-8.2), bukan PIN saja. Dua
/// alasan yang keduanya penting: dua orang boleh punya PIN yang sama persis
/// tanpa saling menimpa (AC-8.15), dan pencatatan "siapa yang melayani"
/// tidak pernah ambigu.
///
/// Desain (docs/ui-redesign-foundation.md): satu pertanyaan besar di atas
/// ("Siapa yang bertugas?"), kartu nama besar (≥64dp) di zona jempol, lalu
/// keypad PIN yang di-*reuse* apa adanya dari `pin_keypad.dart` supaya
/// rasanya sama dengan gerbang PIN yang sudah dikenal pengguna.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  AppUser? _selected;
  String? _errorText;
  bool _checking = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Terkunci otomatis → pengguna yang sama langsung dibawa ke keypad;
    // dia hanya perlu membuka kunci, bukan memilih namanya lagi.
    final session = ref.read(sessionProvider);
    if (session.locked) _selected = session.user;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Menjalankan detik mundur saat keypad sedang terkunci, supaya angka
  /// yang tampil tidak berhenti di layar sementara waktunya sebenarnya
  /// sudah lewat.
  void _startCountdown() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final remaining = ref
          .read(sessionProvider.notifier)
          .throttle
          .remaining(DateTime.now());
      setState(() {
        _errorText = remaining == null ? null : PinThrottle.waitMessage(remaining);
      });
      if (remaining == null) timer.cancel();
    });
  }

  Future<void> _submit(String pin) async {
    final user = _selected;
    if (user == null) return;

    final controller = ref.read(sessionProvider.notifier);
    final remaining = controller.throttle.remaining(DateTime.now());
    if (remaining != null) {
      setState(() => _errorText = PinThrottle.waitMessage(remaining));
      _startCountdown();
      return;
    }

    setState(() {
      _checking = true;
      _errorText = null;
    });

    final authenticated = await ref
        .read(userRepoProvider)
        .authenticate(userId: user.id, pin: pin);
    if (!mounted) return;

    if (authenticated == null) {
      final next = await controller.registerFailure();
      if (!mounted) return;
      final wait = next.remaining(DateTime.now());
      setState(() {
        _checking = false;
        _errorText = wait == null
            ? 'PIN salah, coba lagi.'
            : PinThrottle.waitMessage(wait);
      });
      if (wait != null) _startCountdown();
      return;
    }

    await controller.signIn(authenticated);
    // Tidak ada `Navigator.pop` di sini: gerbangnya ada di `redirect`
    // router, jadi begitu sesi berubah router sendiri yang memindahkan
    // layar (AC-8.4 — satu jalur penjagaan, bukan dua).
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(activeUsersProvider);
    final locked = ref.watch(sessionProvider).locked;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
            child: usersAsync.when(
              loading: () => const AppLoadingView(),
              error: (error, _) => AppErrorView(
                message: 'Daftar pengguna gagal dimuat.',
                onRetry: () => ref.invalidate(activeUsersProvider),
              ),
              data: (users) => _selected == null
                  ? _UserPicker(
                      users: users,
                      onSelected: (user) => setState(() {
                        _selected = user;
                        _errorText = null;
                      }),
                    )
                  : _PinStep(
                      user: _selected!,
                      locked: locked,
                      checking: _checking,
                      errorText: _errorText,
                      onBack: users.length <= 1 && locked
                          ? null
                          : () => setState(() {
                                _selected = null;
                                _errorText = null;
                              }),
                      onCompleted: _submit,
                      onForgotPin: _selected!.isOwner
                          ? () => ForgotPinScreen.show(context, owner: _selected!)
                          : null,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Langkah 1 — "Siapa yang bertugas?".
class _UserPicker extends StatelessWidget {
  const _UserPicker({required this.users, required this.onSelected});

  final List<AppUser> users;
  final ValueChanged<AppUser> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (users.isEmpty) {
      return const EmptyState(
        icon: Icons.person_off_outlined,
        title: 'Belum ada akun pengguna',
        message: 'Matikan multi-pengguna lewat pemulihan, atau restore '
            'backup yang memuat akunmu.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.space2xl,
        AppSizes.screenPadding,
        AppSizes.spaceXl,
      ),
      children: [
        const AppIconBadge(
          icon: Icons.storefront_outlined,
          tone: AppTone.primary,
          size: AppIconBadgeSize.lg,
        ),
        const SizedBox(height: AppSizes.spaceMl),
        Text(
          'Siapa yang bertugas?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSizes.spaceXs),
        Text(
          'Pilih namamu dulu, lalu masukkan PIN.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.palette.inkSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceXl),
        for (final user in users)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spaceMs),
            child: _UserCard(user: user, onTap: () => onSelected(user)),
          ),
      ],
    );
  }
}

/// Kartu nama besar (≥64dp, §8.6) — target sentuh yang tidak mungkin
/// meleset walau tangan kasir sedang basah atau terburu-buru.
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSizes.spaceMd),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            UserAvatar(user: user),
            const SizedBox(width: AppSizes.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSizes.spaceXs),
                  UserRolePill(role: user.role),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.palette.inkTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Langkah 2 — keypad PIN untuk pengguna terpilih.
class _PinStep extends StatelessWidget {
  const _PinStep({
    required this.user,
    required this.locked,
    required this.checking,
    required this.errorText,
    required this.onBack,
    required this.onCompleted,
    required this.onForgotPin,
  });

  final AppUser user;
  final bool locked;
  final bool checking;
  final String? errorText;
  final VoidCallback? onBack;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onForgotPin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        AppSizes.spaceMd,
        AppSizes.screenPadding,
        AppSizes.spaceXl,
      ),
      child: Column(
        children: [
          SizedBox(
            height: AppSizes.minTouchTarget,
            child: Align(
              alignment: Alignment.centerLeft,
              child: onBack == null
                  ? null
                  : TextButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: AppSizes.iconSm),
                      label: const Text('Ganti nama'),
                    ),
            ),
          ),
          UserAvatar(user: user, size: 72),
          const SizedBox(height: AppSizes.spaceMs),
          Text(
            locked ? 'Selamat datang kembali, ${user.name}' : 'Halo, ${user.name}',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSizes.spaceXs),
          Text(
            locked
                ? 'Aplikasi terkunci otomatis. Keranjangmu masih utuh.'
                : 'Masukkan 6 digit PIN kamu.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.palette.inkSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceLg),
          PinKeypad(
            onCompleted: onCompleted,
            errorText: errorText,
            enabled: !checking,
          ),
          const SizedBox(height: AppSizes.spaceMs),
          if (onForgotPin != null)
            TextButton(onPressed: onForgotPin, child: const Text('Lupa PIN?')),
        ],
      ),
    );
  }
}
