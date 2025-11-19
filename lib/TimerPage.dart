import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// 履歴リストのキー（Leaderboard.dartと共有）
const String _historyKey = 'stopwatch_history_list'; 
// 教科リストを保存/読み込みするためのキー
const String _subjectListKey = 'timer_subject_list';

// 親に実行状態を通知するためのコールバック型
typedef TimerStateSetter = void Function(bool isRunning);

// =============================================================
// 1. ストップウォッチページ (TimerPage) - カウントアップ方式
// =============================================================

class TimerPage extends StatefulWidget {
  final TimerStateSetter? onStateChange;

  const TimerPage({super.key, this.onStateChange});
  
  // 💡 修正: Stateクラスを公開
  @override
  State<TimerPage> createState() => TimerPageState();
}

class TimerPageState extends State<TimerPage> // 💡 修正: クラス名を公開
    with AutomaticKeepAliveClientMixin<TimerPage> {
  
  late Timer _timer;
  int _milliseconds = 0;
  bool _isRunning = false;

  List<String> _subjects = [];
  String _selectedSubject = '未選択';
  
  // 💡 タイマーページにデフォルトで存在する教科リスト（編集不可）
  final List<String> _defaultSubjects = ['未選択', '英語', '数学', '現代文', '古典', '物理基礎', '化学基礎', '地学基礎', '生物基礎', '物理', '化学', '地学', '生物', '歴史総合', '政治経済', '日本史', '世界史', '地理', '公民', '情報', 'その他'];


  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 0), () {});
    _timer.cancel(); 
    _loadSubjects(); // ロード処理を実行
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  
    // 💡 NEW: 外部から呼び出される教科の再ロード関数
    void refreshSubjects() {
      _loadSubjects();
      // 設定画面から戻った際にリストが即座に更新される
    }
  
    // Subjects loading function
    Future<void> _loadSubjects() async {
      final prefs = await SharedPreferences.getInstance();
      
      // Load custom list or use default
      List<String> loadedSubjects = prefs.getStringList(_subjectListKey) ?? _defaultSubjects;
      
      // Safety check for the previously selected subject
      String currentSelection = loadedSubjects.contains(_selectedSubject) ? _selectedSubject : loadedSubjects.first;
      
      if (mounted) {
        setState(() {
          _subjects = loadedSubjects;
          _selectedSubject = currentSelection;
        });
      }
    }
  
    // 教科関連は削除


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
      print('保存エラーが発生しました: $e');
      rethrow; 
    }
  }

  void _startStop() {

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
    
    widget.onStateChange?.call(_isRunning); 
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
      _selectedSubject = _subjects.isNotEmpty ? _subjects[0] : '未選択'; // リセット後、選択肢をリセット
    });
    
    widget.onStateChange?.call(_isRunning); 
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Mixinの要件を満たすために必ず呼ぶ
    // (教科関連の選択ロジックを削除)

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          if (!(_milliseconds > 0 || _isRunning)) 
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubject,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                // タイマー実行中 (または開始後) は null を設定し、選択を無効化
                onChanged: (!_isRunning && _milliseconds == 0) ? (String? newValue) {
                  setState(() {
                    _selectedSubject = newValue!;
                  });
                } : null,
                // _subjects リストが空でないことを確認
                items: _subjects.isNotEmpty
                    ? _subjects.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: value == _subjects.first && _subjects.first == '未選択' ? Colors.grey : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList()
                    : [], // リストが空の場合は空のリストを返す
              ),
            )
          else 
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
                onPressed: _reset, // 時間が進んでいて停止中のみ
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