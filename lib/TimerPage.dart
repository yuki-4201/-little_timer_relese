import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// 履歴リストのキー（Leaderboard.dartと共有）
const String _historyKey = 'stopwatch_history_list'; 

// =============================================================
// 1. ストップウォッチページ (TimerPage) - カウントアップ方式
// =============================================================

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  late Timer _timer;
  int _milliseconds = 0;
  bool _isRunning = false;

  // 教科選択用プロパティ
  final List<String> _subjects = ['未選択', '英語', '数学', '現代文', '古典', '理科基礎', '物理', '化学', '地学', '生物', '歴史総合', '政治経済', '日本史', '世界史', '地理', '公民', '情報', 'その他'];
  String _selectedSubject = '未選択';

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 0), () {});
    _timer.cancel(); 
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // 経過時間を HH:MM:SS.ms の形式に整形する
  String _formatTime(int milliseconds) {
    int hundreds = (milliseconds / 10).truncate();
    int seconds = (hundreds / 100).truncate();
    int minutes = (seconds / 60).truncate();
    int hours = (minutes / 60).truncate();

    String formattedHours = (hours % 60).toString().padLeft(2, '0');
    String formattedMinutes = (minutes % 60).toString().padLeft(2, '0');
    String formattedSeconds = (seconds % 60).toString().padLeft(2, '0');
    String formattedHundreds = (hundreds % 100).toString().padLeft(2, '0');

    return '$formattedHours:$formattedMinutes:$formattedSeconds.$formattedHundreds';
  }

  // 履歴をリストとして保存する関数
  Future<void> _saveHistory(int ms, String formattedTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      
      List<String> historyList = prefs.getStringList(_historyKey) ?? [];
      
      // 保存データに選択教科を追加: "ミリ秒,整形済み時間,タイムスタンプ,教科"
      String dataToSave = '$ms,$formattedTime,$timestamp,$_selectedSubject'; 
      
      historyList.add(dataToSave);
      
      await prefs.setStringList(_historyKey, historyList);
      
      print('履歴に保存されました: $dataToSave');
    } catch (e) {
      print('保存エラー: $e');
    }
  }

  void _startStop() {
    // 時間が0で「未選択」の場合は開始を禁止

    if (_isRunning) {
      _timer.cancel();
    } else {
      _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
        setState(() {
          _milliseconds += 10;
        });
      });
    }
    setState(() {
      _isRunning = !_isRunning;
    });
  }

  // リセットする (doneボタンの役割)
  void _reset() async {
    _timer.cancel();
    
    if (_milliseconds > 0) {
      String formattedTime = _formatTime(_milliseconds); 
      await _saveHistory(_milliseconds, formattedTime);
    }
    
    setState(() {
      _milliseconds = 0;
      _isRunning = false;
      _selectedSubject = _subjects[0]; 
    });
  }

  @override
  Widget build(BuildContext context) {
    // タイマーが0で停止中の場合のみ選択可能
    final bool isSelectionEnabled = !_isRunning && _milliseconds == 0; 
    
    // タイマーが開始済みか否か
    final bool isTimerStarted = _milliseconds > 0 || _isRunning;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          // 修正: タイマー開始前と開始後の表示を切り替える
          if (!isTimerStarted) 
            // 1. タイマー開始前: 目立たないプルダウンを表示
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubject,
                // 目立たないデザインのためにパディングを追加
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                // タイマー実行中 (または開始後) は null を設定し、選択を無効化
                onChanged: isSelectionEnabled ? (String? newValue) {
                  setState(() {
                    _selectedSubject = newValue!;
                  });
                } : null,
                items: _subjects.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      // '未選択'の場合は目立たない色にする
                      style: TextStyle(
                        color: value == _subjects[0] ? Colors.grey : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else 
            // 2. タイマー開始後: 選択された科目をテキストで表示
            Text(
              _selectedSubject,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          
          
          const SizedBox(height: 30),
          const Icon(Icons.timer, size: 80, color: Colors.blueAccent),
          const SizedBox(height: 10),
          
          Text(
            _formatTime(_milliseconds),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w100, letterSpacing: 3),
          ),
          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // DONEボタン
              IconButton(
                // 停止中かつ時間が進んでいるときのみ有効 (DONEの役割)
                icon: Icon(
                  _isRunning ? Icons.done : null,
                  size: 60,
                ),
                onPressed: _reset, 
                color: Colors.green,
              ),
              const SizedBox(width: 40),
              
              // 開始 / 一時停止ボタン
              IconButton(
                onPressed: _startStop,
                icon: Icon(
                  _isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 60,
                ),
                color: Colors.blueAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}