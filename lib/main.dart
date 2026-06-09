import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'color_profiles.dart';
import 'screens/map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ConnectApp());
}

class ConnectApp extends StatelessWidget {
  const ConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: activeProfileIndex,
      builder: (context, _, __) => MaterialApp(
        title: 'Connect',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: const MapScreen(),
      ),
    );
  }
}
