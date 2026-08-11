import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/data/db/app_database.dart';
import 'package:kasir_warung/data/repositories/category_repository_impl.dart';
import 'package:kasir_warung/data/repositories/product_repository_impl.dart';
import 'package:kasir_warung/domain/repositories/repository_exceptions.dart';

void main() {
  late AppDatabase db;
  late CategoryRepositoryImpl repo;
  late ProductRepositoryImpl productRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CategoryRepositoryImpl(db);
    productRepo = ProductRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CategoryRepositoryImpl — CRUD', () {
    test('create menyimpan kategori baru dan mengembalikan id', () async {
      final id = await repo.create('Sembako');
      final category = await repo.getById(id);
      expect(category, isNotNull);
      expect(category!.name, 'Sembako');
    });

    test('create menolak nama duplikat dengan pesan Bahasa Indonesia', () async {
      await repo.create('Sembako');
      expect(
        () => repo.create('Sembako'),
        throwsA(
          isA<NamaKategoriSudahAdaException>().having(
            (e) => e.toString(),
            'pesan',
            contains('sudah ada'),
          ),
        ),
      );
    });

    test('rename mengubah nama & menolak jika nama baru sudah dipakai kategori lain', () async {
      final idA = await repo.create('Minuman');
      await repo.create('Sembako');

      await repo.rename(idA, 'Minuman Segar');
      final renamed = await repo.getById(idA);
      expect(renamed!.name, 'Minuman Segar');

      expect(() => repo.rename(idA, 'Sembako'), throwsA(isA<NamaKategoriSudahAdaException>()));
    });

    test('watchAll mengembalikan seluruh kategori terurut nama', () async {
      await repo.create('Sembako');
      await repo.create('Camilan');

      final categories = await repo.watchAll().first;
      expect(categories.map((c) => c.name), ['Camilan', 'Sembako']);
    });
  });

  group('CategoryRepositoryImpl — validasi produk terkait', () {
    test('delete berhasil bila kategori tidak dipakai produk', () async {
      final id = await repo.create('Sembako');
      await repo.delete(id);
      expect(await repo.getById(id), isNull);
    });

    test('delete menolak & melempar KategoriMasihDipakaiException bila masih dipakai produk', () async {
      final id = await repo.create('Sembako');
      await productRepo.createProduct(name: 'Beras', sellPrice: 65000, categoryId: id);

      expect(
        () => repo.delete(id),
        throwsA(
          isA<KategoriMasihDipakaiException>().having(
            (e) => e.toString(),
            'pesan',
            contains('masih dipakai'),
          ),
        ),
      );

      final stillExists = await repo.getById(id);
      expect(stillExists, isNotNull, reason: 'kategori tidak boleh terhapus saat validasi gagal');
    });

    test('countProducts menghitung produk yang memakai kategori', () async {
      final id = await repo.create('Sembako');
      await productRepo.createProduct(name: 'Beras', sellPrice: 65000, categoryId: id);
      await productRepo.createProduct(name: 'Gula', sellPrice: 15000, categoryId: id);
      await productRepo.createProduct(name: 'Teh', sellPrice: 5000);

      expect(await repo.countProducts(id), 2);
    });
  });
}
