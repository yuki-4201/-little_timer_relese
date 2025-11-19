import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:intl/intl.dart'; 
import 'dart:convert'; 
import 'dart:io'; 
import 'package:flutter_file_dialog/flutter_file_dialog.dart'; 
import 'package:share_plus/share_plus.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'dart:typed_data'; 
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:flutter/services.dart'; // Added SystemNavigator import

// ------------------------------------------------------------
// 共通鍵と定数の定義
// ------------------------------------------------------------
const String _historyKey = 'stopwatch_history_list'; 
// 💡 NEW: 教科リストを保存するためのキー
const String _subjectListKey = 'timer_subject_list'; 

const String _encryptionKeyString = 'this_is_a_very_secret_key_123456';
const String _encryptionIVString = 'secure_iv_123456'; 

final key = encrypt_lib.Key.fromUtf8(_encryptionKeyString.padRight(32));
final iv = encrypt_lib.IV.fromUtf8(_encryptionIVString.padRight(16));
final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc)); 
// ------------------------------------------------------------

typedef DataChangeCallback = void Function();

// =============================================================
// 設定ページ (SettingsPage)
// =============================================================

class SettingsPage extends StatelessWidget {
  final DataChangeCallback? onDataChange;
  
  const SettingsPage({super.key, this.onDataChange});

  // Helper: データのエクスポート処理 (変更なし)
  Future<void> _exportData(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final rawHistory = prefs.getStringList(_historyKey) ?? [];
    
    if (rawHistory.isEmpty) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エクスポートするデータがありません。')));
      return;
    }

    try {
      final rawJsonString = json.encode(rawHistory);
      
      final encrypted = encrypter.encrypt(rawJsonString, iv: iv);
      final encryptedJsonString = encrypted.base64; 

      final fileName = 'littletimer_export_encrypted_${DateFormat('yyyyMMdd').format(DateTime.now())}.json';
      final fileContents = Uint8List.fromList(utf8.encode(encryptedJsonString));

      final params = SaveFileDialogParams(
        data: fileContents, 
        fileName: fileName,
        mimeTypesFilter: ["application/octet-stream"],
      );
      
      final filePath = await FlutterFileDialog.saveFile(params: params);

      // ignore: use_build_context_synchronously
      if (!context.mounted) return;

      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('データを $fileName として保存しました。')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ファイルの保存がキャンセルされました。')));
      }

    } catch (e) {
      // ignore: use_build_context_synchronously
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エクスポート中にエラーが発生しました: $e')));
    }
  }

  // Helper: データのインポート処理 (変更なし)
  Future<void> _importData(BuildContext context) async {
    try {
      final params = OpenFileDialogParams(
        mimeTypesFilter: ["application/json"],
      );
      
      final filePath = await FlutterFileDialog.pickFile(params: params);
      
      if (!context.mounted) return; 

      if (filePath != null) { 
        final file = File(filePath);
        final contents = await file.readAsString(); 
        
        // 1. 復号化
        final encrypted = encrypt_lib.Encrypted.fromBase64(contents);
        final decryptedJsonString = encrypter.decrypt(encrypted, iv: iv);
        
        // 2. JSONパース
        final List<dynamic> jsonList = json.decode(decryptedJsonString);
        
        final List<String> importedHistory = jsonList.map((e) => e.toString()).toList();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_historyKey, importedHistory);
        
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('データを正常にインポートしました。アプリを終了します。')));
          }

          // Notify parent about data change if callback provided
          if (onDataChange != null) {
            onDataChange!();
          }

          // short delay so the SnackBar can appear, then exit the app
          await Future.delayed(const Duration(milliseconds: 700));

          // For mobile platforms prefer SystemNavigator.pop(); for desktop use exit(0)
          try {
            if (Platform.isAndroid || Platform.isIOS) {
              SystemNavigator.pop();
            } else {
              exit(0);
            }
          } catch (_) {
            // fallback
            exit(0);
          }
        
        if (onDataChange != null) {
          onDataChange!();
        }
        if (context.mounted) {
           Navigator.of(context).pop(); 
        }
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ファイルの選択がキャンセルされました。')));
      }
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラー: ファイルの内容が不正な形式です。')));
    } catch (e) {
      if (!context.mounted) return;
      
      String errorMessage = e.toString();
      if (errorMessage.contains('Mac mismatch') || errorMessage.contains('Format')) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラー: ファイルの暗号化キーが一致しないか、データが破損しています。')));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('インポート中にエラーが発生しました: $e')));
      }
    }
  }
  
  // 確認ダイアログを表示する関数 (変更なし)
    Future<void> _confirmAndImportData(BuildContext context) async {
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('データのインポート確認'),
            content: const Text('インポートを実行すると、既存のすべての記録データは上書きされ、削除されます。よろしいですか？'),
            actions: <Widget>[
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                child: const Text('インポートして上書き', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.of(dialogContext).pop(); // ダイアログを閉じる
                  await _importData(context); // インポート処理を実行
                },
              ),
            ],
          );
        },
      );
    }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('データ管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('データのエクスポート'),
            subtitle: const Text('すべての記録を保存します。'),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('データのインポート'),
            subtitle: const Text('既存の記録を上書きし、引き継ぎデータを読み込みます。'),
            onTap: () async {
              await _confirmAndImportData(context);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),

          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('アプリ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('アプリを紹介する'),
            subtitle: const Text('友だちにアプリを共有します。'),
            onTap: () => _shareApp(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('アプリについて'),
            subtitle: const Text('アプリの情報を表示します。'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}

  // Helper: アプリを紹介して共有する
  Future<void> _shareApp(BuildContext context) async {
    final String shareMessage = '''Little Timer — シンプルな勉強タイマー

勉強時間を手軽に記録・管理できるタイマーアプリです。
教科ごとの集計、グラフ共有などができます。

ぜひ使ってみてください！


link: https://github.com/yuki-4201/-little_timer_relese
''';

    try {
      await Share.share(shareMessage);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('共有に失敗しました: $e')));
    }
  }

  // Helper: アプリの簡易 About ダイアログを表示
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Little Timer',
      applicationVersion: '1.2.0',
      applicationLegalese: '© 2025 1107.yuna',
      children: const [
        Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('Little Timer はシンプルな学習タイマーです。データは本体に保存され、外部に共有されません。'),
        ),
      ],
    );
  }

// =============================================================
// NEW: 教科管理ページ
// =============================================================

class SubjectManagerPage extends StatefulWidget {
  const SubjectManagerPage({super.key});

  @override
  State<SubjectManagerPage> createState() => _SubjectManagerPageState();
}

class _SubjectManagerPageState extends State<SubjectManagerPage> {
  // 教科の追加UIは削除されたため、TextEditingController は不要
  List<String> _subjects = [];
  bool _isLoading = true;
  bool _changed = false; // track whether list was modified

  // 💡 タイマーページにデフォルトで存在する教科リスト（編集不可）
  final List<String> _defaultSubjects = ['未選択', '英語', '数学', '現代文', '古典', '物理基礎', '化学基礎', '地学基礎', '生物基礎', '物理', '化学', '地学', '生物', '歴史総合', '政治経済', '日本史', '世界史', '地理', '公民', '情報', 'その他'];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences に保存されていればそれを読み込み、なければデフォルトを読み込む
    List<String> savedSubjects = prefs.getStringList(_subjectListKey) ?? _defaultSubjects;
    
    setState(() {
      _subjects = savedSubjects;
      _isLoading = false;
    });
  }

  Future<void> _saveSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_subjectListKey, _subjects);
    _changed = true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('教科リストを保存しました。')),
    );
  }

  void _removeSubject(int index) {
    // デフォルト教科と「未選択」は削除不可にする
    if (_defaultSubjects.contains(_subjects[index]) || _subjects[index] == '未選択') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_subjects[index]} は削除できません。')),
      );
      return;
    }
    
    setState(() {
      _subjects.removeAt(index);
    });
    _saveSubjects();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Intercept back navigation and return whether changes were made
  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_changed);
    return false; // we've already popped
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('教科の管理'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
              children: [
                // 教科の追加操作は削除されました。既存の教科一覧から削除のみ可能です。
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('教科の追加は無効化されています。既存の教科は一覧から削除できます。', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _subjects.length,
                    itemBuilder: (context, index) {
                      final subject = _subjects[index];
                      // 削除可能かどうか
                      final bool canRemove = !_defaultSubjects.contains(subject) && subject != '未選択';
                      
                      return ListTile(
                        title: Text(subject, style: TextStyle(
                          fontWeight: canRemove ? FontWeight.normal : FontWeight.w600,
                          color: canRemove ? Colors.black : Colors.grey[700],
                        )),
                        trailing: canRemove 
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeSubject(index),
                              )
                            : const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                      );
                    },
                  ),
                ),
              ],
            ),
    ),
    );
  }
}