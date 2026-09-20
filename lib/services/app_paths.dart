import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Owner-scoped application support directory, namespaced like the native app.
class AppPaths {
  static const _namespace = 'dev.october.cloak';

  static Future<Directory> supportDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}$_namespace');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> supportFile(String name) async {
    final dir = await supportDir();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }
}
