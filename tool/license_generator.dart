// Tool CLI penjual — TIDAK ikut ke dalam APK.
//
// Jalankan dari akar repo:
//   dart run tool/license_generator.dart --bantuan
//
// Seluruh logika kripto & format diambil dari `lib/core/license/`, yaitu
// jalur kode yang SAMA PERSIS dengan yang dipakai aplikasi untuk
// memverifikasi (K-6.12). Tidak ada implementasi kedua yang bisa menafsirkan
// format secara berbeda — dan "lisensi sah ditolak aplikasi" adalah
// kerusakan terparah dari fitur ini (PRD v1.1 §6.7.3).
import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:kasir_warung/core/license/device_code.dart';
import 'package:kasir_warung/core/license/license_issuer.dart';
import 'package:kasir_warung/core/license/license_keys.dart';
import 'package:kasir_warung/core/license/license_payload.dart';
import 'package:kasir_warung/core/license/license_token.dart';
import 'package:kasir_warung/core/license/license_verifier.dart';
import 'package:qr/qr.dart';

/// Direktori kerja penjual — **DI LUAR REPO** (PRD v1.1 §6.7.2).
///
/// Kunci privat penerbit adalah aset paling berharga proyek ini di luar kode
/// sumbernya. Ia tidak pernah boleh ter-commit, jadi ia tidak pernah boleh
/// LAHIR di dalam repo.
String get _defaultHomeDir {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return '$home/.kasir-warung';
}

const String _keyFileName = 'license_ed25519.key';
const String _csvFileName = 'lisensi-terbit.csv';

Future<int> main(List<String> args) async {
  final options = _Options.parse(args);

  if (options.help || args.isEmpty) {
    _printHelp();
    return 0;
  }

  final dir = Directory(options.dir ?? _defaultHomeDir);

  try {
    if (options.buatKunci) return await _cmdBuatKunci(dir);
    if (options.daftar) return _cmdDaftar(dir, options);
    if (options.verifikasi != null) return await _cmdVerifikasi(options);
    if (options.device != null) return await _cmdTerbitkan(dir, options);
  } on _ToolException catch (e) {
    stderr.writeln('✗ ${e.message}');
    return 1;
  }

  stderr.writeln('✗ Perintah tidak dikenali. Jalankan dengan --bantuan.');
  return 1;
}

// ---------------------------------------------------------------------------
// Perintah
// ---------------------------------------------------------------------------

/// `--buat-kunci` — sekali seumur produk.
Future<int> _cmdBuatKunci(Directory dir) async {
  final keyFile = File('${dir.path}/$_keyFileName');
  if (keyFile.existsSync()) {
    throw _ToolException(
      'Kunci sudah ada di ${keyFile.path}.\n'
      '  Tool ini MENOLAK menimpanya. Menimpa kunci penerbit berarti seluruh '
      'kode yang sudah beredar tidak bisa diterbitkan ulang dari kunci yang '
      'sama, dan pelanggan lama kehilangan jalur dukungan.\n'
      '  Kalau memang ingin merotasi kunci: pindahkan berkas lama ke tempat '
      'aman lebih dulu, lalu tambahkan kunci publik BARU ke daftar tepercaya '
      'di lib/core/license/license_keys.dart tanpa membuang yang lama '
      '(AC-6.20).',
    );
  }
  dir.createSync(recursive: true);

  final pair = await LicenseIssuer.generateKeyPair();
  keyFile.writeAsStringSync('${base64Encode(pair.privateSeed)}\n');
  // Hanya pemilik yang boleh membaca (best effort; diabaikan di Windows).
  try {
    if (!Platform.isWindows) {
      Process.runSync('chmod', ['600', keyFile.path]);
    }
  } catch (_) {
    // Tidak fatal — isi berkasnya yang penting, bukan bit izinnya.
  }

  final publicBase64 = base64Encode(pair.publicKey);
  stdout
    ..writeln('✓ Pasangan kunci Ed25519 dibuat.')
    ..writeln('')
    ..writeln('  Kunci privat : ${keyFile.path}')
    ..writeln('  Kunci publik : $publicBase64')
    ..writeln('')
    ..writeln('LANGKAH WAJIB BERIKUTNYA')
    ..writeln('  1. Tempel kunci publik di atas ke daftar tepercaya:')
    ..writeln('     lib/core/license/license_keys.dart → kProductionPublicKeys')
    ..writeln('  2. Cadangkan kunci privat ke MINIMAL DUA tempat luring')
    ..writeln('     (mis. USB terenkripsi + pengelola kata sandi). BUKAN ke')
    ..writeln('     Drive akun yang sama dengan laptop ini, BUKAN ke repo.')
    ..writeln('  3. Jangan pernah mengirim berkas .key lewat chat/email.')
    ..writeln('')
    ..writeln('  Kunci HILANG  → kode yang sudah beredar tetap sah selamanya,')
    ..writeln('                  tapi kamu tidak bisa menerbitkan kode baru.')
    ..writeln(
      '  Kunci BOCOR   → siapa pun bisa membuat keygen. Terbitkan kunci',
    )
    ..writeln('                  baru, KELUARKAN yang lama dari daftar')
    ..writeln('                  tepercaya, lalu rilis pembaruan aplikasi.');
  return 0;
}

/// Penerbitan kode untuk satu kode perangkat.
Future<int> _cmdTerbitkan(Directory dir, _Options options) async {
  final deviceInput = options.device!;
  final deviceRaw = DeviceCode.tryParse(deviceInput);
  if (deviceRaw == null) {
    // (a) karakter cek diperiksa SEBELUM kode diterbitkan — salah ketik
    // ketahuan di sini, bukan setelah bolak-balik WhatsApp (§6.3.B).
    throw _ToolException(
      'Kode perangkat "$deviceInput" tidak lolos pemeriksaan karakter cek.\n'
      '  Bentuk yang benar: KW-XXXXX-XXXXX (10 karakter, alfabet Crockford '
      'Base32 tanpa I/L/O/U).\n'
      '  Minta pembeli mengirim ulang kode perangkatnya — jangan diterbitkan '
      'dengan tebakan.',
    );
  }

  final type = LicenseType.fromName(options.jenis ?? '');
  if (type == null) {
    throw _ToolException(
      'Jenis lisensi wajib diisi: --jenis coba | selamanya | tahunan',
    );
  }

  final csv = _LedgerCsv(File('${dir.path}/$_csvFileName'));

  // (b) peringatan trial berantai — satu-satunya penjaga yang tersedia tanpa
  // server (PRD §6.7.3).
  final previous = csv.rowsFor(deviceRaw);
  if (previous.isNotEmpty) {
    stdout.writeln('⚠ Perangkat ini SUDAH PERNAH menerima kode:');
    for (final row in previous) {
      stdout.writeln('    ${row.date}  ${row.type.padRight(10)}  ${row.name}');
    }
    if (type == LicenseType.coba &&
        previous.any((r) => r.type == LicenseType.coba.name)) {
      stdout.writeln(
        '  → Ini akan menjadi trial KEDUA untuk perangkat yang sama. '
        'Pastikan itu memang keputusanmu.',
      );
    }
    stdout.writeln('');
  }

  final issuer = LicenseIssuer(_readPrivateKey(dir));
  final issuedAt = DateTime.now().toUtc();
  final code = await issuer.issue(
    deviceRaw: deviceRaw,
    type: type,
    issuedAt: issuedAt,
    durationDays: options.hari ?? type.defaultDurationDays,
    graceDays: options.tenggang ?? type.defaultGraceDays,
  );

  // (c+d) verifikasi ulang lewat jalur aplikasi SEBELUM kode dikirim.
  final check = await LicenseVerifier(
    trustedPublicKeysBase64: [await issuer.publicKeyBase64()],
  ).verify(code: code, deviceRaw: deviceRaw);
  if (check is! LicenseAccepted) {
    throw _ToolException(
      'Kode yang baru diterbitkan GAGAL diverifikasi ulang. Jangan dikirim. '
      '(${(check as LicenseRejected).reason.name})',
    );
  }

  final display = DeviceCode.format(deviceRaw);
  final expiry = check.payload.isLifetime
      ? '—'
      : _formatDate(check.payload.expiresAt!);

  final outDir = Directory('${dir.path}/terbit')..createSync(recursive: true);
  final pngPath = '${outDir.path}/lisensi-$display.png';
  File(pngPath).writeAsBytesSync(_qrPng(LicenseToken.format(code)));

  csv.append(
    _LedgerRow(
      date: _formatDate(issuedAt),
      device: deviceRaw,
      type: type.name,
      expiry: expiry,
      name: options.nama ?? '',
      note: options.catatan ?? '',
    ),
  );

  stdout
    ..writeln('✓ Kode aktivasi diterbitkan.')
    ..writeln('')
    ..writeln('  Perangkat    : $display')
    ..writeln('  Jenis        : ${type.label}')
    ..writeln('  Terbit       : ${_formatDate(issuedAt)}')
    ..writeln('  Kedaluwarsa  : $expiry')
    ..writeln('  Masa tenggang: ${check.payload.graceDays} hari')
    ..writeln('  QR           : $pngPath')
    ..writeln('  Catatan      : $_csvFileName diperbarui')
    ..writeln('')
    ..writeln('SALIN & KIRIM KE PEMBELI (teks + gambar QR di atas):')
    ..writeln('')
    ..writeln(LicenseToken.format(code))
    ..writeln('');
  return 0;
}

/// `--verifikasi <kode> --device <id>` — jalur verifikasi yang sama persis
/// dengan aplikasi, untuk dukungan jarak jauh saat pembeli melapor
/// "kode saya ditolak".
Future<int> _cmdVerifikasi(_Options options) async {
  final deviceInput = options.device;
  if (deviceInput == null) {
    throw _ToolException('--verifikasi butuh --device <kode perangkat>.');
  }
  final deviceRaw = DeviceCode.tryParse(deviceInput);
  if (deviceRaw == null) {
    throw _ToolException(
      'Kode perangkat "$deviceInput" gagal pemeriksaan karakter cek.',
    );
  }

  final result = await LicenseVerifier(
    trustedPublicKeysBase64: trustedLicensePublicKeys(),
  ).verify(code: options.verifikasi!, deviceRaw: deviceRaw);

  if (result is LicenseAccepted) {
    final p = result.payload;
    stdout
      ..writeln('✓ Kode SAH untuk ${DeviceCode.format(deviceRaw)}.')
      ..writeln('  Jenis        : ${p.type.label}')
      ..writeln('  Terbit       : ${_formatDate(p.issuedAt)}')
      ..writeln(
        '  Kedaluwarsa  : ${p.isLifetime ? "— (selamanya)" : _formatDate(p.expiresAt!)}',
      )
      ..writeln('  Masa tenggang: ${p.graceDays} hari');
    return 0;
  }

  final rejected = result as LicenseRejected;
  stdout
    ..writeln('✗ Kode DITOLAK (${rejected.reason.name}).')
    ..writeln('  Pesan yang dilihat pembeli:')
    ..writeln('  "${rejected.message}"');
  return 1;
}

/// `--daftar [--jenis coba]` — isi buku penerbitan.
int _cmdDaftar(Directory dir, _Options options) {
  final csv = _LedgerCsv(File('${dir.path}/$_csvFileName'));
  final filter = options.jenis == null
      ? null
      : LicenseType.fromName(options.jenis!);
  final rows = csv.rows().where((r) => filter == null || r.type == filter.name);

  if (rows.isEmpty) {
    stdout.writeln('Belum ada kode yang diterbitkan (${csv.file.path}).');
    return 0;
  }
  stdout.writeln(
    'TANGGAL     PERANGKAT      JENIS      KEDALUWARSA  NAMA / CATATAN',
  );
  for (final r in rows) {
    stdout.writeln(
      '${r.date.padRight(11)} ${DeviceCode.format(r.device).padRight(14)} '
      '${r.type.padRight(10)} ${r.expiry.padRight(12)} ${r.name} ${r.note}',
    );
  }
  stdout.writeln('\n${rows.length} baris.');
  return 0;
}

// ---------------------------------------------------------------------------
// Pendukung
// ---------------------------------------------------------------------------

List<int> _readPrivateKey(Directory dir) {
  final file = File('${dir.path}/$_keyFileName');
  if (!file.existsSync()) {
    throw _ToolException(
      'Kunci privat tidak ditemukan di ${file.path}.\n'
      '  Jalankan dulu: dart run tool/license_generator.dart --buat-kunci',
    );
  }
  final seed = base64Decode(file.readAsStringSync().trim());
  if (seed.length != 32) {
    throw _ToolException('Berkas kunci rusak (bukan 32 byte).');
  }
  return seed;
}

/// QR hitam-putih dengan margin (quiet zone) 4 modul, diperbesar agar
/// terbaca dari layar HP ke kamera HP lain.
List<int> _qrPng(String data, {int scale = 8, int quiet = 4}) {
  final qrImage = QrImage(QrCode(payload: QrPayload.fromString(data)));
  final modules = qrImage.moduleCount;
  final size = (modules + quiet * 2) * scale;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var row = 0; row < modules; row++) {
    for (var col = 0; col < modules; col++) {
      if (!qrImage.isDark(row, col)) continue;
      final x0 = (col + quiet) * scale;
      final y0 = (row + quiet) * scale;
      for (var y = y0; y < y0 + scale; y++) {
        for (var x = x0; x < x0 + scale; x++) {
          image.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }
  }
  return img.encodePng(image);
}

String _formatDate(DateTime date) {
  final d = date.toUtc();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _LedgerRow {
  const _LedgerRow({
    required this.date,
    required this.device,
    required this.type,
    required this.expiry,
    required this.name,
    required this.note,
  });

  final String date;
  final String device;
  final String type;
  final String expiry;
  final String name;
  final String note;
}

/// Buku penerbitan penjual. Sengaja CSV polos: bisa dibuka di HP, di Excel,
/// dan tetap terbaca sepuluh tahun lagi tanpa tool ini.
class _LedgerCsv {
  _LedgerCsv(this.file);

  final File file;

  static const String header =
      'tanggal,kode_perangkat,jenis,kedaluwarsa,nama,catatan';

  List<_LedgerRow> rows() {
    if (!file.existsSync()) return const [];
    final lines = file.readAsLinesSync();
    return [
      for (final line in lines.skip(1))
        if (line.trim().isNotEmpty)
          if (_split(line) case final cells when cells.length >= 6)
            _LedgerRow(
              date: cells[0],
              device: cells[1],
              type: cells[2],
              expiry: cells[3],
              name: cells[4],
              note: cells[5],
            ),
    ];
  }

  List<_LedgerRow> rowsFor(String deviceRaw) =>
      rows().where((r) => r.device == deviceRaw).toList();

  void append(_LedgerRow row) {
    file.parent.createSync(recursive: true);
    if (!file.existsSync()) {
      file.writeAsStringSync('$header\n');
    }
    file.writeAsStringSync(
      '${row.date},${row.device},${row.type},${row.expiry},'
      '${_escape(row.name)},${_escape(row.note)}\n',
      mode: FileMode.append,
    );
  }

  static String _escape(String value) {
    final cleaned = value.replaceAll('"', "'");
    return cleaned.contains(',') ? '"$cleaned"' : cleaned;
  }

  static List<String> _split(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        quoted = !quoted;
      } else if (ch == ',' && !quoted) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }
}

class _ToolException implements Exception {
  const _ToolException(this.message);
  final String message;
}

class _Options {
  _Options();

  bool help = false;
  bool buatKunci = false;
  bool daftar = false;
  String? device;
  String? jenis;
  String? nama;
  String? catatan;
  String? verifikasi;
  String? dir;
  int? hari;
  int? tenggang;

  static _Options parse(List<String> args) {
    final o = _Options();
    for (var i = 0; i < args.length; i++) {
      String next() {
        if (i + 1 >= args.length) {
          throw _ToolException('Opsi ${args[i]} butuh nilai.');
        }
        return args[++i];
      }

      switch (args[i]) {
        case '--bantuan':
        case '-h':
        case '--help':
          o.help = true;
        case '--buat-kunci':
          o.buatKunci = true;
        case '--daftar':
          o.daftar = true;
        case '--device':
          o.device = next();
        case '--jenis':
          o.jenis = next();
        case '--nama':
          o.nama = next();
        case '--catatan':
          o.catatan = next();
        case '--verifikasi':
          o.verifikasi = next();
        case '--dir':
          o.dir = next();
        case '--hari':
          o.hari = int.tryParse(next());
        case '--tenggang':
          o.tenggang = int.tryParse(next());
        default:
          throw _ToolException('Opsi tidak dikenal: ${args[i]}');
      }
    }
    return o;
  }
}

void _printHelp() {
  stdout.writeln('''
Kasir Warung — penerbit kode aktivasi (offline, tanpa server)

  Sekali seumur produk
    dart run tool/license_generator.dart --buat-kunci
      Membuat pasangan kunci Ed25519 di $_defaultHomeDir/$_keyFileName
      (DI LUAR REPO) dan mencetak kunci publik untuk ditempel ke
      lib/core/license/license_keys.dart. Menolak menimpa kunci yang ada.

  Setiap penjualan
    dart run tool/license_generator.dart \\
      --device KW-4T7QP-9M2XK --jenis tahunan \\
      --nama "Warung Bu Ani" --catatan "WA 0812xxxx, transfer 12 Agu"

      --jenis    coba (3 hari) | selamanya | tahunan (365 + 7 tenggang)
      --hari     N     ganti lama berlaku (opsional)
      --tenggang N     ganti masa tenggang (ikut ditandatangani, K-6.13)

      Keluaran: kode teks 120 karakter (terkelompok 5), berkas QR PNG di
      $_defaultHomeDir/terbit/, dan satu baris di $_csvFileName.

  Dukungan & catatan
    dart run tool/license_generator.dart --verifikasi <kode> --device <id>
      Menjalankan jalur verifikasi yang SAMA PERSIS dengan aplikasi.
    dart run tool/license_generator.dart --daftar [--jenis coba]
      Menampilkan isi buku penerbitan.

  Umum
    --dir <path>   ganti direktori kerja (default $_defaultHomeDir)
    --bantuan      tampilkan pesan ini
''');
}
