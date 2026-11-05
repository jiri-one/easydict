import 'dart:io';

final executableDir = File(Platform.resolvedExecutable).parent.path;

String get desktopAssetsDir => Platform.isMacOS
    ? '$executableDir/../Frameworks/App.framework/Resources/flutter_assets'
    : '$executableDir/data/flutter_assets';
