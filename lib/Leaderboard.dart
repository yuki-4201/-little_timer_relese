import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:intl/intl.dart'; 
import 'dart:async'; 
import 'dart:math' as math; 
import 'package:flutter/cupertino.dart'; 
import 'dart:ui' as ui; 

// 粒度定数
const String GRAN_YEAR = '年';
const String GRAN_MONTH = '月';
const String GRAN_WEEK = '週';
const String GRAN_DAY = '日';
const List<String> GRANULARITIES = [GRAN_YEAR, GRAN_MONTH, GRAN_WEEK, GRAN_DAY];

// TimerPageと共有されるキー
const String _historyKey = 'stopwatch_history_list'; 

// 履歴データを保持するためのモデルクラス (変更なし)
class TimeEntry {
  final int milliseconds;
  final String formattedTime;
  final int timestamp; 
  final String subject;
  
  TimeEntry(this.milliseconds, this.formattedTime, this.timestamp, this.subject);
}

// 教科別集計データを保持するためのモデルクラス (変更なし)
class SubjectTime {
  final String subject;
  final int totalMilliseconds;
  final String formattedTime;
  SubjectTime(this.subject, this.totalMilliseconds, this.formattedTime);
}

// 日別集計データを保持するためのモデルクラス (変更なし)
class DailyTime {
  final DateTime date;
  final int totalMilliseconds;
  final String formattedTime;
  DailyTime(this.date, this.totalMilliseconds, this.formattedTime);
}

// =============================================================
// リーダーボードページ (LeaderboardPage) - 全データ表示
// =============================================================

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool _isLoading = true;
  List<TimeEntry> _historyList = []; 
  
  List<SubjectTime> _aggregatedData = [];
  int _grandTotalMs = 0;
  
  List<DailyTime> _dailyTrendData = []; 
  int _dailyTrendMaxMs = 0;           

  String _selectedGranularity = GRAN_YEAR;
  String _selectedPeriodKey = '';
  List<String> _availablePeriods = [];

  final List<Color> _chartColors = [
    Colors.blue, 
    Colors.green, 
    Colors.orange, 
    Colors.purple, 
    Colors.red, 
    Colors.teal, 
    Colors.brown, 
    Colors.pink
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedHistory();
  }

  // Helper: 経過時間を常に HH:MM:SS の形式に整形する
  String _formatAggregateTime(int ms) {
    int totalSeconds = (ms / 1000).truncate();
    
    int displayHours = totalSeconds ~/ 3600;
    int displayMinutes = (totalSeconds % 3600) ~/ 60;
    int displaySeconds = totalSeconds % 60;
    
    String formattedHours = displayHours.toString().padLeft(2, '0');
    String formattedMinutes = displayMinutes.toString().padLeft(2, '0');
    String formattedSeconds = displaySeconds.toString().padLeft(2, '0');

    return '$formattedHours:$formattedMinutes:$formattedSeconds';
  }

  // Helper: 指定された日付を含む週の開始日（月曜日）を計算
  DateTime _findStartOfWeek(DateTime date) {
    final int daysToSubtract = date.weekday - 1; 
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: daysToSubtract));
  }
  
  // 履歴から選択可能な期間を生成する
  void _generateAvailablePeriods(List<TimeEntry> entries) {
    if (entries.isEmpty) {
        setState(() {
            _availablePeriods = [];
            _selectedPeriodKey = '';
        });
        return;
    }

    final String formatKey = _selectedGranularity;
    Set<String> periodKeys = {};

    for (var entry in entries) {
        final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
        String key;

        if (formatKey == GRAN_YEAR) {
            key = DateFormat('yyyy年').format(date);
        } else if (formatKey == GRAN_MONTH) {
            key = DateFormat('yyyy年MM月').format(date);
        } else if (formatKey == GRAN_WEEK) {
            final startOfWeek = _findStartOfWeek(date);
            key = DateFormat('yyyy/MM/dd (週)').format(startOfWeek);
        } else if (formatKey == GRAN_DAY) {
            key = DateFormat('yyyy/MM/dd').format(date);
        } else {
            continue;
        }
        periodKeys.add(key);
    }
    
    List<String> sortedKeys = periodKeys.toList();
    // 日付キーを降順にソート (最新の期間が上に来るように)
    sortedKeys.sort((a, b) => b.compareTo(a));

    setState(() {
        _availablePeriods = sortedKeys;
        if (!_availablePeriods.contains(_selectedPeriodKey) || _selectedPeriodKey.isEmpty) {
            _selectedPeriodKey = sortedKeys.isNotEmpty ? sortedKeys.first : '';
        }
    });
  }


  // 履歴データから教科別合計時間を集計する関数 (フィルター処理あり)
  void _aggregateSubjectTimes(List<TimeEntry> allEntries) {
    if (allEntries.isEmpty) {
      setState(() {
        _aggregatedData = [];
        _grandTotalMs = 0;
      });
      return;
    }

    List<TimeEntry> filteredEntries = allEntries;
    
if (_selectedPeriodKey.isNotEmpty) {
      filteredEntries = allEntries.where((entry) {
        final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
        String entryKey = '';

        if (_selectedGranularity == GRAN_YEAR) {
            entryKey = DateFormat('yyyy年').format(date);
        // 修正: getGranularity() を _selectedGranularity に変更
        } else if (_selectedGranularity == GRAN_MONTH) { 
            entryKey = DateFormat('yyyy年MM月').format(date);
        // 修正: getGranularity() を _selectedGranularity に変更
        } else if (_selectedGranularity == GRAN_WEEK) { 
            final startOfWeek = _findStartOfWeek(date);
            entryKey = DateFormat('yyyy/MM/dd (週)').format(startOfWeek);
        // 修正: getGranularity() を _selectedGranularity に変更
        } else if (_selectedGranularity == GRAN_DAY) { 
            entryKey = DateFormat('yyyy/MM/dd').format(date);
        } else {
            return true;
        }
        return entryKey == _selectedPeriodKey;
      }).toList();
    }
    
    Map<String, int> subjectMap = {};
    int grandTotal = 0;

    for (var entry in filteredEntries) {
      subjectMap[entry.subject] = (subjectMap[entry.subject] ?? 0) + entry.milliseconds;
      grandTotal += entry.milliseconds;
    }
    
    List<SubjectTime> aggregatedList = subjectMap.entries.map((entry) {
      return SubjectTime(entry.key, entry.value, _formatAggregateTime(entry.value));
    }).toList();
    
    aggregatedList.sort((a, b) => b.totalMilliseconds.compareTo(a.totalMilliseconds));

    setState(() {
      _aggregatedData = aggregatedList;
      _grandTotalMs = grandTotal;
    });
  }

  // 直近14日間の記録を日別に集計する関数 (変更なし)
  void _aggregateDailyTrend(List<TimeEntry> allEntries) {
    if (allEntries.isEmpty) {
        setState(() {
            _dailyTrendData = [];
            _dailyTrendMaxMs = 0;
        });
        return;
    }

    Map<String, int> dailyMap = {};
    
    for (var entry in allEntries) {
        final date = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
        final dateKey = DateFormat('yyyy-MM-dd').format(date);
        
        dailyMap[dateKey] = (dailyMap[dateKey] ?? 0) + entry.milliseconds;
    }

    List<DailyTime> dailyList = dailyMap.entries.map((entry) {
        final date = DateFormat('yyyy-MM-dd').parse(entry.key);
        return DailyTime(date, entry.value, _formatAggregateTime(entry.value));
    }).toList();
    
    dailyList.sort((a, b) => a.date.compareTo(b.date));
    
    const int maxDays = 14; 
    final int startIndex = dailyList.length > maxDays ? dailyList.length - maxDays : 0;
    final lastDays = dailyList.sublist(startIndex);

    int maxMs = lastDays.isEmpty ? 0 : lastDays.map((d) => d.totalMilliseconds).reduce(math.max);

    setState(() {
        _dailyTrendData = lastDays;
        _dailyTrendMaxMs = maxMs;
    });
  }

  // 履歴データを読み込み、ソートする関数
  Future<void> _loadSavedHistory() async {
    try {
      if (!_isLoading) {
         setState(() { _isLoading = true; });
      }
      
      final prefs = await SharedPreferences.getInstance();
      List<String> rawHistory = prefs.getStringList(_historyKey) ?? [];
      
      List<TimeEntry> entries = [];
      for (String item in rawHistory) {
        List<String> parts = item.split(',');
        if (parts.length >= 3) { 
          int ms = int.tryParse(parts[0]) ?? 0;
          String formatted = parts[1];
          int timestamp = int.tryParse(parts[2]) ?? 0;
          String subject = parts.length >= 4 ? parts[3] : '未分類';
          if (ms > 0) { entries.add(TimeEntry(ms, formatted, timestamp, subject)); }
        }
      }
      
      entries.sort((a, b) => a.timestamp.compareTo(b.timestamp)); 

      if (mounted) {
        setState(() {
          _historyList = entries;
          _isLoading = false;
        });
        _generateAvailablePeriods(entries);
        _aggregateSubjectTimes(entries); 
        _aggregateDailyTrend(entries); 
      }
    } catch (e) {
      print('データの読み込みエラー: $e');
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // 日時を整形するヘルパー関数
  String _formatDate(int timestamp) {
    if (timestamp == 0) return '日時不明';
    final DateTime recordTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    
    try { return DateFormat('yyyy/MM/dd HH:mm:ss').format(recordTime); } 
    catch (e) { return '${recordTime.month.toString().padLeft(2, '0')}-${recordTime.day.toString().padLeft(2, '0')} ${recordTime.hour.toString().padLeft(2, '0')}:${recordTime.minute.toString().padLeft(2, '0')}'; }
  }


  @override
  Widget build(BuildContext context) {
    final bool hasData = _historyList.isNotEmpty;

    // 修正: Column全体をSingleChildScrollViewでラップ
    return SingleChildScrollView(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('History', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          
          // --- 7/14日間推移グラフ セクション (上部) ---
          if (!_isLoading && _dailyTrendData.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最近の記録', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _LineChart(data: _dailyTrendData, maxMs: _dailyTrendMaxMs),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0), 
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _dailyTrendData.map((data) {
                        final weekdayLabel = DateFormat('EEE').format(data.date); 
                        final dateLabel = DateFormat('MM/dd').format(data.date); 
                        return Column(
                          children: [
                            Text(weekdayLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(dateLabel, style: TextStyle(fontSize: 8, color: Colors.grey)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 30),
                ],
              ),
            ),
          // --- End 7/14日間推移グラフ セクション ---


          
          // --- 粒度選択プルダウン (1/2: 粒度) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: DropdownButton<String>(
              value: _selectedGranularity,
              isExpanded: true,
              underline: Container(height: 1, color: Colors.grey),
              items: GRANULARITIES.map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedGranularity = newValue;
                  });
                  _generateAvailablePeriods(_historyList); 
                  _aggregateSubjectTimes(_historyList);
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          
          // --- 期間選択プルダウン (2/2: 特定期間) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: DropdownButton<String>(
              value: _selectedPeriodKey,
              isExpanded: true,
              underline: Container(height: 1, color: Colors.grey),
              items: _availablePeriods.map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedPeriodKey = newValue;
                    _aggregateSubjectTimes(_historyList);
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 10),


          // --- 教科別グラフ/集計セクション ---
          if (hasData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 修正: 合計時間表示を追加
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('合計学習時間', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_formatAggregateTime(_grandTotalMs), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 円グラフ
                  Center(child: Padding(padding: const EdgeInsets.only(bottom: 20.0), child: _PieChart(data: _aggregatedData, totalMs: _grandTotalMs, colors: _chartColors))),

                  const SizedBox(height: 10),
                  ..._aggregatedData.asMap().entries.map((entry) {
                    final data = entry.value;
                    final index = entry.key;
                    double percentage = _grandTotalMs > 0 ? data.totalMilliseconds / _grandTotalMs : 0;
                    final Color barColor = _chartColors[index % _chartColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: barColor, shape: BoxShape.circle)),
                          const SizedBox(width: 8),

                          SizedBox(width: 60, child: Text(data.subject, style: TextStyle(fontSize: 14, color: Colors.blueGrey))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${data.formattedTime} (${(percentage * 100).toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                Container(height: 10, width: MediaQuery.of(context).size.width * 0.65 * percentage, decoration: BoxDecoration(color: barColor.withOpacity(0.7), borderRadius: BorderRadius.circular(5))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 20),
                ],
              ),
            ),
          // --- End 教科別グラフセクション ---
          
          // --- 直近100件のデータを見るボタン ---
          if (hasData)
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => HistoryDetailPage(
                        historyList: _historyList.reversed.toList(),
                      ),
                    ),
                  );
                },
                child: const Text(
                  '直近100件のデータを見る',
                  style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          // --- End 履歴詳細ボタン ---


          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// =============================================================
// グラフ描画ウィジェット (LineChart)
// =============================================================

class _LineChart extends StatelessWidget {
  final List<DailyTime> data;
  final int maxMs;

  const _LineChart({required this.data, required this.maxMs});

  @override
  Widget build(BuildContext context) {
    if (data.length <= 1) return const Center(child: Text("2日以上の記録が必要です。"));

    return Container(
      height: 120, 
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: CustomPaint(
        painter: _LineChartPainter(data, maxMs),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<DailyTime> data;
  final int maxMs;

  _LineChartPainter(this.data, this.maxMs);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length <= 1 || maxMs == 0) return;

    final double paddingHorizontal = 30.0; 
    final double paddingVertical = 10.0; 
    final double usableWidth = size.width - 2 * paddingHorizontal;
    final double usableHeight = size.height - 2 * paddingVertical;
    final double stepX = usableWidth / (data.length - 1);
    
    final path = Path();
    final paintLine = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final paintPoint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
      
    List<Offset> points = [];

    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      
      final double normalizedY = entry.totalMilliseconds / maxMs;
      final double y = usableHeight - (normalizedY * usableHeight) + paddingVertical;
      
      final double x = (i * stepX) + paddingHorizontal;
      
      final point = Offset(x, y);
      points.add(point);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paintLine);

    for (final point in points) {
      canvas.drawCircle(point, 4.0, paintPoint);
      
      final currentEntry = data[points.indexOf(point)];
      
      if (currentEntry.totalMilliseconds == maxMs) {
          final textStyle = TextStyle(color: Colors.blueAccent, fontSize: 10);
          final textSpan = TextSpan(text: currentEntry.formattedTime, style: textStyle);
          final textPainter = TextPainter(text: textSpan, textDirection: ui.TextDirection.ltr);
          textPainter.layout();
          textPainter.paint(canvas, Offset(point.dx - textPainter.width / 2, point.dy - 15)); 
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.data.length != data.length || oldDelegate.maxMs != maxMs;
  }
}

// =============================================================
// グラフ描画ウィジェット (PieChart)
// =============================================================

class _PieChart extends StatelessWidget {
  final List<SubjectTime> data;
  final int totalMs;
  final List<Color> colors;

  const _PieChart({required this.data, required this.totalMs, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (totalMs == 0) return const SizedBox.shrink();

    return CustomPaint(
      size: const Size(120, 120), 
      painter: _PieChartPainter(data, totalMs, colors),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<SubjectTime> data;
  final int totalMs;
  final List<Color> colors;

  _PieChartPainter(this.data, this.totalMs, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    double currentAngle = -math.pi / 2; // 12時の位置から開始
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);

    for (int i = 0; i < data.length; i++) {
      final entry = data[i];
      if (entry.totalMilliseconds == 0) continue;

      final sweepAngle = (entry.totalMilliseconds / totalMs) * 2 * math.pi;
      final color = colors[i % colors.length];
      
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        rect, 
        currentAngle, 
        sweepAngle, 
        true, // UseCenter: true
        paint
      );
      
      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return (oldDelegate as _PieChartPainter).totalMs != totalMs;
  }
}

// =============================================================
// 履歴詳細表示ページ (HistoryDetailPage)
// =============================================================

class HistoryDetailPage extends StatelessWidget {
  final List<TimeEntry> historyList;
  const HistoryDetailPage({super.key, required this.historyList});

  @override
  Widget build(BuildContext context) {
    // historyListは新しい順に渡されていると仮定し、最新100件を取得
    final latest100 = historyList.take(100).toList();
    final itemCount = latest100.length;
    
    // 日時を整形するヘルパー関数
    String formatDate(int timestamp) {
      if (timestamp == 0) return '日時不明';
      final DateTime recordTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      try { return DateFormat('yyyy/MM/dd HH:mm:ss').format(recordTime); } 
      catch (e) { return '日時: ${recordTime.month.toString().padLeft(2, '0')}-${recordTime.day.toString().padLeft(2, '0')} ${recordTime.hour.toString().padLeft(2, '0')}:${recordTime.minute.toString().padLeft(2, '0')}'; }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('直近の履歴データ (最新${itemCount}件)'),
      ),
      body: itemCount == 0
          ? const Center(child: Text('履歴データはありません'))
          : ListView.separated(
              itemCount: itemCount,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = latest100[index];
                // リストの総数から逆算して、1位から100位のように表示
                return ListTile(
                  leading: Text(
                    '#${itemCount - index}', 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  title: Text(
                    entry.formattedTime,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '教科: ${entry.subject} | 記録日時: ${formatDate(entry.timestamp)}',
                  ),
                );
              },
            ),
    );
  }
}