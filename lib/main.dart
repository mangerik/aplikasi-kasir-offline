import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/utils/date_formatter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib dipanggil sebelum widget apa pun memakai DateFormatter (format
  // tanggal Indonesia, lihat core/utils/date_formatter.dart).
  await DateFormatter.init();

  runApp(const ProviderScope(child: KasirApp()));
}
