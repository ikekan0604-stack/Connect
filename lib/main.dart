import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'color_profiles.dart';
import 'screens/home_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/sort_screen.dart';
import 'screens/mypage_screen.dart';

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
    // Rebuild the whole app (theme + every screen) when the colour profile
    // changes, so a profile switch re-skins everything at once.
    return ValueListenableBuilder<int>(
      valueListenable: activeProfileIndex,
      builder: (context, _, __) => MaterialApp(
        title: 'Connect',
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        home: _MainShell(),
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Built fresh each rebuild (non-const) so screens re-read AppTheme colours
    // when the active colour profile changes. State is preserved by position.
    // ignore: prefer_const_constructors
    final screens = <Widget>[
      HomeScreen(),
      FriendsScreen(),
      CameraScreen(),
      SortScreen(),
      MyPageScreen(),
    ];
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.ink.withValues(alpha: 0.15), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.scatter_plot_outlined,
                activeIcon: Icons.scatter_plot,
                index: 0,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                index: 1,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _CameraNavItem(
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.tune_outlined,
                activeIcon: Icons.tune,
                index: 3,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                index: 4,
                currentIndex: currentIndex,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? AppTheme.textPrimary : AppTheme.textTertiary;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Icon(
            active ? activeIcon : icon,
            color: color,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CameraNavItem extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _CameraNavItem({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppTheme.accent : AppTheme.surfaceElevated,
              border: Border.all(
                color: active
                    ? AppTheme.accent
                    : AppTheme.ink.withValues(alpha: 0.35),
                width: 1.4,
              ),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 18,
              color: active ? Colors.white : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
