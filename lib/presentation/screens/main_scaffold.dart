import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'dashboard_screen.dart';
import 'dues_check_screen.dart';
import 'transaction_form_screen.dart';
import 'supervision_report_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _KeepAlivePage(child: DashboardScreen(onNavigateTab: _navigateToTab)),
      _KeepAlivePage(child: DuesCheckScreen(onBackToDashboard: () => _navigateToTab(0))),
      _KeepAlivePage(child: TransactionFormScreen(initialType: 'expense', onBackToDashboard: () => _navigateToTab(0))),
      _KeepAlivePage(child: SupervisionReportScreen(onBackToDashboard: () => _navigateToTab(0))),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _navigateToTab(0);
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
          },
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => _navigateToTab(index),
          height: 68,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.brandPrimaryLight,
          surfaceTintColor: Colors.transparent,
          elevation: 8,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.brandPrimary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.fact_check_rounded, color: AppColors.brandPrimary),
              label: 'Kas Siswa',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.edit_note_rounded, color: AppColors.brandPrimary),
              label: 'Catat Transaksi',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.brandPrimary),
              label: 'Laporan',
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
