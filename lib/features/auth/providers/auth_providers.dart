import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/pin_throttle.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../domain/entities/app_user.dart';
import '../../../domain/entities/multi_user_settings.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/multi_user_usecase.dart';
import '../../settings/providers/settings_providers.dart';
import 'session_store.dart';

final Provider<UserRepository> userRepoProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(databaseProvider));
});

final Provider<MultiUserUsecase> multiUserUsecaseProvider =
    Provider<MultiUserUsecase>((ref) {
  return MultiUserUsecase(
    ref.watch(settingsRepoProvider),
    ref.watch(userRepoProvider),
  );
});

/// Setelan multi-user dari tabel `settings` (default: mati).
///
/// `FutureProvider` biasa — sama seperti `pointsSettingsProvider`: nilainya
/// hanya berubah lewat aksi eksplisit di Pengaturan, yang lalu memanggil
/// `ref.invalidate`.
final FutureProvider<MultiUserSettings> multiUserSettingsProvider =
    FutureProvider<MultiUserSettings>((ref) {
  return ref.watch(multiUserUsecaseProvider).readSettings();
});

/// Daftar pengguna AKTIF — dipakai layar Masuk.
final FutureProvider<List<AppUser>> activeUsersProvider =
    FutureProvider<List<AppUser>>((ref) {
  return ref.watch(userRepoProvider).listUsers();
});

/// Seluruh pengguna termasuk yang nonaktif — dipakai layar manajemen.
final FutureProvider<List<AppUser>> allUsersProvider =
    FutureProvider<List<AppUser>>((ref) {
  return ref.watch(userRepoProvider).listUsers(includeInactive: true);
});

/// Keadaan sesi: siapa yang sedang bertugas, dan apakah layar Masuk harus
/// muncul (PRD v1.1 §8.3.B).
@immutable
class SessionState {
  const SessionState({
    required this.multiUserEnabled,
    required this.bootstrapped,
    this.user,
    this.pendingUserId,
    this.locked = false,
  });

  /// Multi-user menyala? Saat MATI, seluruh perilaku v1.0 berlaku persis:
  /// tidak ada layar masuk, dan gerbang PIN global lama tetap yang menjaga
  /// Laporan/Pengaturan/void (AC-8.1).
  final bool multiUserEnabled;

  /// Sudah selesai membaca kebenaran dari database? Sebelum itu, keadaan
  /// ini berasal dari cermin `shared_preferences`.
  final bool bootstrapped;

  final AppUser? user;

  /// `active_user_id` yang tersimpan tapi akunnya belum sempat dimuat dari
  /// database. Ditahan supaya frame pertama tidak berkedip ke layar Masuk
  /// untuk sesi yang sebenarnya masih sah.
  final int? pendingUserId;

  /// Terkunci oleh kunci otomatis — pengguna aktifnya TETAP diingat dan
  /// keranjangnya tidak dibuang, hanya ditutupi layar PIN (AC-8.12).
  final bool locked;

  bool get needsLogin =>
      multiUserEnabled && (locked || (user == null && pendingUserId == null));

  /// Peran yang berlaku untuk penjagaan izin.
  ///
  /// - Multi-user MATI → [UserRole.owner]: aplikasi berperilaku persis
  ///   seperti v1.0, tidak ada satu pun fitur yang tiba-tiba hilang.
  /// - Multi-user hidup tapi akunnya belum dimuat → [UserRole.cashier],
  ///   peran paling TERBATAS. Ketidaktahuan tidak boleh pernah menjadi
  ///   izin.
  UserRole get role {
    if (!multiUserEnabled) return UserRole.owner;
    return user?.role ?? UserRole.cashier;
  }

  SessionState copyWith({
    bool? multiUserEnabled,
    bool? bootstrapped,
    AppUser? user,
    int? pendingUserId,
    bool? locked,
    bool clearUser = false,
    bool clearPending = false,
  }) =>
      SessionState(
        multiUserEnabled: multiUserEnabled ?? this.multiUserEnabled,
        bootstrapped: bootstrapped ?? this.bootstrapped,
        user: clearUser ? null : (user ?? this.user),
        pendingUserId: clearPending ? null : (pendingUserId ?? this.pendingUserId),
        locked: locked ?? this.locked,
      );
}

final NotifierProvider<SessionController, SessionState> sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    final store = ref.watch(sessionStoreProvider);
    // Nilai awal dibaca SINKRON dari cermin preferensi supaya frame pertama
    // langsung benar; kebenaran dari database menyusul di [_bootstrap].
    final initial = SessionState(
      multiUserEnabled: store.readMultiUserEnabled(),
      bootstrapped: false,
      pendingUserId: store.readActiveUserId(),
    );
    Future.microtask(_bootstrap);
    return initial;
  }

  Future<void> _bootstrap() async {
    final store = ref.read(sessionStoreProvider);
    MultiUserSettings settings;
    try {
      settings = await ref.read(multiUserUsecaseProvider).readSettings();
    } catch (e) {
      // Database belum siap / sedang direstore. Jangan pernah membuka
      // gerbang karenanya — pertahankan keadaan cermin apa adanya.
      debugPrint('Sesi: gagal membaca setelan multi-user ($e)');
      return;
    }
    await store.writeMultiUserEnabled(settings.enabled);

    AppUser? user;
    final storedId = store.readActiveUserId();
    if (settings.enabled && storedId != null) {
      user = await ref.read(userRepoProvider).findById(storedId);
      if (user != null && !user.isActive) user = null;
      if (user == null) await store.writeActiveUserId(null);
    }
    if (!settings.enabled) {
      // Multi-user dimatikan → sesi tidak relevan lagi.
      await store.writeActiveUserId(null);
    }

    state = SessionState(
      multiUserEnabled: settings.enabled,
      bootstrapped: true,
      user: user,
      locked: state.locked && user != null,
    );
  }

  /// Dipanggil setelah setelan multi-user berubah (dinyalakan/dimatikan)
  /// atau setelah restore backup.
  Future<void> refresh() => _bootstrap();

  /// Menandai [user] sebagai yang sedang bertugas.
  Future<void> signIn(AppUser user) async {
    await ref.read(sessionStoreProvider).writeActiveUserId(user.id);
    await clearThrottle();
    state = state.copyWith(
      user: user,
      locked: false,
      bootstrapped: true,
      clearPending: true,
    );
  }

  /// "Ganti Kasir" — sesi dilepas, keranjang **tidak disentuh sama sekali**
  /// (AC-8.11): yang berganti adalah siapa yang bertanggung jawab, bukan
  /// apa yang sedang dikerjakan.
  Future<void> signOut() async {
    await ref.read(sessionStoreProvider).writeActiveUserId(null);
    state = state.copyWith(clearUser: true, clearPending: true, locked: false);
  }

  /// Kunci otomatis: pengguna aktif TETAP diingat supaya membuka kunci
  /// cukup PIN-nya sendiri, dan keranjang tetap utuh (AC-8.12).
  void lock() {
    if (!state.multiUserEnabled || state.user == null) return;
    state = state.copyWith(locked: true);
  }

  PinThrottleState get throttle => ref.read(sessionStoreProvider).readThrottle();

  Future<PinThrottleState> registerFailure() async {
    final store = ref.read(sessionStoreProvider);
    final next = PinThrottle.registerFailure(store.readThrottle(), DateTime.now());
    await store.writeThrottle(next);
    return next;
  }

  Future<void> clearThrottle() =>
      ref.read(sessionStoreProvider).writeThrottle(PinThrottle.cleared);
}

/// Peran yang berlaku sekarang — satu-satunya pintu yang boleh dipakai UI
/// untuk memutuskan "boleh atau tidak" (AC-8.4, AC-8.5).
final Provider<UserRole> currentRoleProvider = Provider<UserRole>((ref) {
  return ref.watch(sessionProvider).role;
});

/// Pengguna yang sedang bertugas — `null` saat multi-user mati.
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>((ref) {
  final session = ref.watch(sessionProvider);
  return session.multiUserEnabled ? session.user : null;
});
