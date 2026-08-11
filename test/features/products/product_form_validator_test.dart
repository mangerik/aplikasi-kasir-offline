import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_warung/features/products/utils/product_form_validator.dart';

void main() {
  group('ProductFormValidator.name', () {
    test('null/kosong -> error', () {
      expect(ProductFormValidator.name(null), isNotNull);
      expect(ProductFormValidator.name(''), isNotNull);
      expect(ProductFormValidator.name('   '), isNotNull);
    });

    test('terisi -> valid', () {
      expect(ProductFormValidator.name('Beras 5kg'), isNull);
    });
  });

  group('ProductFormValidator.sellPrice', () {
    test('wajib diisi', () {
      expect(ProductFormValidator.sellPrice(null), isNotNull);
      expect(ProductFormValidator.sellPrice(''), isNotNull);
    });

    test('harus angka', () {
      expect(ProductFormValidator.sellPrice('abc'), isNotNull);
    });

    test('harus > 0', () {
      expect(ProductFormValidator.sellPrice('0'), isNotNull);
      expect(ProductFormValidator.sellPrice('-100'), isNotNull);
    });

    test('angka positif -> valid', () {
      expect(ProductFormValidator.sellPrice('65000'), isNull);
    });
  });

  group('ProductFormValidator.costPrice', () {
    test('opsional: kosong -> valid', () {
      expect(ProductFormValidator.costPrice(null), isNull);
      expect(ProductFormValidator.costPrice(''), isNull);
    });

    test('bila diisi harus angka >= 0', () {
      expect(ProductFormValidator.costPrice('abc'), isNotNull);
      expect(ProductFormValidator.costPrice('-1'), isNotNull);
      expect(ProductFormValidator.costPrice('0'), isNull);
      expect(ProductFormValidator.costPrice('50000'), isNull);
    });
  });

  group('ProductFormValidator.stock', () {
    test('opsional: kosong -> valid (default 0)', () {
      expect(ProductFormValidator.stock(null), isNull);
      expect(ProductFormValidator.stock(''), isNull);
    });

    test('mendukung desimal (kg/liter) dengan koma atau titik', () {
      expect(ProductFormValidator.stock('2.5'), isNull);
      expect(ProductFormValidator.stock('2,5'), isNull);
    });

    test('tidak boleh negatif atau bukan angka', () {
      expect(ProductFormValidator.stock('-1'), isNotNull);
      expect(ProductFormValidator.stock('abc'), isNotNull);
    });
  });

  group('ProductFormValidator.unit', () {
    test('wajib diisi', () {
      expect(ProductFormValidator.unit(null), isNotNull);
      expect(ProductFormValidator.unit(''), isNotNull);
    });

    test('terisi -> valid', () {
      expect(ProductFormValidator.unit('pcs'), isNull);
    });
  });

  group('ProductFormValidator.lowStockThreshold', () {
    test('opsional: kosong -> valid', () {
      expect(ProductFormValidator.lowStockThreshold(null), isNull);
      expect(ProductFormValidator.lowStockThreshold(''), isNull);
    });

    test('tidak boleh negatif atau bukan angka', () {
      expect(ProductFormValidator.lowStockThreshold('-5'), isNotNull);
      expect(ProductFormValidator.lowStockThreshold('xyz'), isNotNull);
    });

    test('angka valid -> valid', () {
      expect(ProductFormValidator.lowStockThreshold('3'), isNull);
    });
  });

  group('ProductFormValidator.categoryName', () {
    test('wajib diisi', () {
      expect(ProductFormValidator.categoryName(null), isNotNull);
      expect(ProductFormValidator.categoryName(''), isNotNull);
    });

    test('terisi -> valid', () {
      expect(ProductFormValidator.categoryName('Sembako'), isNull);
    });
  });
}
