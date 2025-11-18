import 'package:flutter/material.dart';
import 'TimerPage.dart' as timer_page;
import 'Leaderboard.dart' as leaderboard;
import 'SettingPage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little Timer',
      home: const BottomNavPage(title: 'Little Timer'),
    );
  }
}

class BottomNavPage extends StatefulWidget {
  const BottomNavPage({super.key, required this.title});
  final String title;
  @override
  State<BottomNavPage> createState() => _BottomNavPageState();
}

class _BottomNavPageState extends State<BottomNavPage> {
  int _selectedIndex = 0;
  
  // 💡 修正: GlobalKeyの型引数を公開されたStateクラス名に修正
  final GlobalKey<leaderboard.LeaderboardPageState> _leaderboardKey = GlobalKey();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Keyを渡してLeaderboardPageを初期化
    _widgetOptions = <Widget>[
      timer_page.TimerPage(),
      leaderboard.LeaderboardPage(key: _leaderboardKey), // Keyを渡す
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // 💡 設定画面を開くためのロジック
  void _openSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          // データのインポートが完了したら LeaderboardPage の refreshData を呼び出し
          onDataChange: () {
            _leaderboardKey.currentState?.refreshData();
            Navigator.of(context).pop(); 
          },
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettingsPage(context),
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}