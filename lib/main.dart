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
    // 修正: primaryColor 参照のために ThemeData を設定
    return MaterialApp(
      title: 'Little Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
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
  
  // タイマー実行状態を保持する (リーダーボード無効化用)
  bool _isTimerRunning = false; 

  // GlobalKey for LeaderboardPage's state
  final GlobalKey<leaderboard.LeaderboardPageState> _leaderboardKey = GlobalKey();
  
  // 💡 NEW: GlobalKey for TimerPage's state
  final GlobalKey<timer_page.TimerPageState> _timerPageKey = GlobalKey();

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    // Keyを渡して各ページを初期化
    _widgetOptions = <Widget>[
      // 💡 修正: TimerPageにKeyを渡す
      timer_page.TimerPage(
        key: _timerPageKey, // Keyを渡す
        onStateChange: (bool isRunning) {
          setState(() {
            _isTimerRunning = isRunning;
          });
        },
      ),
      leaderboard.LeaderboardPage(key: _leaderboardKey), 
    ];
  }

  void _onItemTapped(int index) {
    // 💡 修正: タイマー実行中に Leaderboard タブを選択した場合、移動をキャンセル
    if (_isTimerRunning && index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タイマー動作中はHistoryに移動できません。')),
      );
      return;
    }
    
    setState(() {
      _selectedIndex = index;
    });

    // Leaderboard タブに移動したときにデータを強制リフレッシュ
    if (index == 1) {
      _leaderboardKey.currentState?.refreshData();
    }
    // タイマータブに移動したときは教科リストを更新
    if (index == 0) {
      _timerPageKey.currentState?.refreshSubjects();
    }
  }

  void _openSettingsPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onDataChange: () {
            // データのインポート/設定変更が完了したら各ページをリロード
            _leaderboardKey.currentState?.refreshData();
            // 💡 NEW: TimerPageの教科リストをリロード
            _timerPageKey.currentState?.refreshSubjects();
            
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    // Leaderboard タブが無効化されているかどうかの判定
    final bool isLeaderboardDisabled = _isTimerRunning;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // Make AppBar transparent and remove shadow
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettingsPage(context),
          ),
        ],
      ),
      // IndexedStackを使用して、全ての子ウィジェットの状態を保持
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Timer',
          ),
          BottomNavigationBarItem(
            // 💡 修正: 無効化を示すためにOpacityと色を調整
            icon: Opacity(
              opacity: isLeaderboardDisabled ? 0.5 : 1.0,
              child: Icon(Icons.leaderboard),
            ),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}