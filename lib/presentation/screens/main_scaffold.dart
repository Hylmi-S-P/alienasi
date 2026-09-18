import 'package:flutter/material.dart';
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

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateTab: _navigateToTab),
      DuesCheckScreen(onBackToDashboard: () => _navigateToTab(0)),
      TransactionFormScreen(initialType: 'expense', onBackToDashboard: () => _navigateToTab(0)),
      SupervisionReportScreen(onBackToDashboard: () => _navigateToTab(0)),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_rounded),
              label: 'Kas Siswa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note_rounded),
              label: 'Catat Transaksi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Laporan',
            ),
          ],
        ),
      ),
    );
  }
}
