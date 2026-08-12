import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/core/utils/pin_hasher.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/settings_repository_impl.dart';
import 'package:kasir_warung/data/repositories/user_repository_impl.dart';
import 'package:kasir_warung/domain/entities/app_user.dart';
import 'package:kasir_warung/domain/entities/multi_user_settings.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';
import 'package:kasir_warung/domain/usecases/multi_user_usecase.dart';
import 'package:kasir_warung/domain/usecases/set_pin_usecase.dart';

/// Alur menyalakan/mematikan multi-user & kode pemulihan
/// (PRD v1.1 §8.3.A, §8.3.E — AC-8.2, AC-8.3, AC-8.13).
void main() {
  late AppDatabase db;
  late SettingsRepositoryImpl settings;
  late UserRepositoryImpl users;
  late MultiUserUsecase usecase;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepositoryImpl(db);
    users = UserRepositoryImpl(db);
    usecase = MultiUserUsecase(settings, users);
  });

  tearDown(() => db.close());

  test('default: multi-user MATI & tanpa kode pemulihan (K-8.5, AC-8.1)',
      () async {
    final result = await usecase.readSettings();
    expect(result.enabled, isFalse);
    expect(result.autoLockMinutes, 0);
    expect(result.hasRecoveryCode, isFalse);
    expect(result.autoLockDuration, isNull);
  });

  test(
    'AC-8.2: PIN global lama otomatis menjadi PIN akun Pemilik — tanpa '
    'membuat PIN baru',
    () async {
      await SetPinUsecase(settings)('246810');
      final legacyHash = await settings.getValue('pin_hash');

      final activation = await usecase.enable(ownerName: 'Pak Budi');

      expect(activation.owner.name, 'Pak Budi');
      expect(activation.owner.role, UserRole.owner);
      final stored = await users.storedPin(activation.owner.id);
      expect(stored!.hash, legacyHash);
      // Dan PIN lama itu memang bisa dipakai masuk.
      expect(
        (await users.authenticate(userId: activation.owner.id, pin: '246810'))
            ?.id,
        activation.owner.id,
      );
    },
  );

  test('tanpa PIN global, aktivasi WAJIB menyertakan PIN baru', () async {
    await expectLater(
      usecase.enable(ownerName: 'Pemilik'),
      throwsA(isA<PinBelumDiaturException>()),
    );

    final activation = await usecase.enable(
      ownerName: 'Pemilik',
      newPin: '135790',
    );
    expect(
      await users.authenticate(userId: activation.owner.id, pin: '135790'),
      isNotNull,
    );
    expect((await usecase.readSettings()).enabled, isTrue);
  });

  test(
    'AC-8.3: kode pemulihan disimpan sebagai HASH (bukan teks polos) dan '
    'berhasil dipakai mereset PIN Pemilik',
    () async {
      final activation = await usecase.enable(
        ownerName: 'Pemilik',
        newPin: '111111',
      );
      final code = activation.recoveryCode;

      final storedHash =
          await settings.getValue(MultiUserSettings.keyRecoveryHash);
      expect(storedHash, isNotNull);
      expect(storedHash, isNot(contains(code.replaceAll('-', ''))));
      expect((await usecase.readSettings()).hasRecoveryCode, isTrue);

      expect(await usecase.verifyRecoveryCode(code), isTrue);
      expect(await usecase.verifyRecoveryCode('0000-0000'), isFalse);

      final replacement = await usecase.resetOwnerPinWithRecoveryCode(
        code: code.toLowerCase(),
        newPin: '999999',
      );

      expect(
        await users.authenticate(userId: activation.owner.id, pin: '999999'),
        isNotNull,
      );
      expect(
        await users.authenticate(userId: activation.owner.id, pin: '111111'),
        isNull,
      );
      // Kode lama HANGUS, kode baru berlaku (§8.3.E).
      expect(await usecase.verifyRecoveryCode(code), isFalse);
      expect(await usecase.verifyRecoveryCode(replacement), isTrue);
    },
  );

  test('kode pemulihan salah TIDAK mengubah PIN sedikit pun', () async {
    final activation = await usecase.enable(
      ownerName: 'Pemilik',
      newPin: '111111',
    );

    await expectLater(
      usecase.resetOwnerPinWithRecoveryCode(code: 'ZZZZ-ZZZZ', newPin: '222222'),
      throwsA(isA<KodePemulihanSalahException>()),
    );
    expect(
      await users.authenticate(userId: activation.owner.id, pin: '111111'),
      isNotNull,
    );
  });

  test(
    'AC-8.13: mematikan multi-user menonaktifkan kasir & mengembalikan PIN '
    'Pemilik menjadi PIN global — akun Pemilik tetap ada',
    () async {
      final activation = await usecase.enable(
        ownerName: 'Pemilik',
        newPin: '111111',
      );
      final ani = await users.createUser(
        name: 'Ani',
        role: UserRole.cashier,
        pin: '222222',
      );

      await usecase.disable();

      expect((await usecase.readSettings()).enabled, isFalse);
      expect((await users.findById(ani.id))!.isActive, isFalse);
      expect((await users.findById(activation.owner.id))!.isActive, isTrue);

      // PIN Pemilik kembali menjadi PIN global v1.0 — gerbang PIN lama
      // langsung berfungsi lagi dengan PIN yang sama.
      final hash = await settings.getValue('pin_hash');
      final salt = await settings.getValue('pin_salt');
      expect(hash, PinHasher.hash('111111', salt!));
    },
  );

  test('menyalakan ulang memakai akun Pemilik yang sudah ada', () async {
    final first = await usecase.enable(ownerName: 'Pemilik', newPin: '111111');
    await usecase.disable();
    final second = await usecase.enable(ownerName: 'Pemilik');

    expect(second.owner.id, first.owner.id);
    expect(await users.countActive(), 1);
    // Kode pemulihan baru diterbitkan setiap kali dinyalakan.
    expect(second.recoveryCode, isNot(first.recoveryCode));
  });

  test('kunci otomatis hanya menerima pilihan yang ditawarkan UI', () async {
    await usecase.setAutoLockMinutes(5);
    expect((await usecase.readSettings()).autoLockMinutes, 5);
    expect(
      (await usecase.readSettings()).autoLockDuration,
      const Duration(minutes: 5),
    );

    // Nilai asing (mis. hasil edit manual) jatuh ke "mati", bukan ke nilai
    // aneh yang mengunci aplikasi tiap detik.
    await settings.setValue(MultiUserSettings.keyAutoLockMinutes, '3');
    expect((await usecase.readSettings()).autoLockMinutes, 0);
  });
}
