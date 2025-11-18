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

// ------------------------------------------------------------
// 共通鍵と定数の定義
// ------------------------------------------------------------
const String _historyKey = 'stopwatch_history_list'; 
// 修正: 鍵は32文字 (256ビット)
const String _encryptionKeyString = 'this_is_a_very_secret_key_123456'; // 32文字に調整
// 修正: IVは16文字 (ブロックサイズ)
const String _encryptionIVString = 'secure_iv_123456'; // 16文字に調整

// 厳密に16バイトと32バイトであることを確認
final key = encrypt_lib.Key.fromUtf8(_encryptionKeyString); // 32バイト
final iv = encrypt_lib.IV.fromUtf8(_encryptionIVString); // 16バイト
final encrypter = encrypt_lib.Encrypter(encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc)); 
// ------------------------------------------------------------

typedef DataChangeCallback = void Function();

// =============================================================
// 設定ページ (SettingsPage)
// =============================================================

class SettingsPage extends StatelessWidget {
  final DataChangeCallback? onDataChange;
  
  const SettingsPage({super.key, this.onDataChange});

  // Helper: データのエクスポート処理 (暗号化を追加)
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

  // Helper: データのインポート処理 (復号化を追加)
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
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('データを正常にインポートしました。')));
        
        if (onDataChange != null) {
          onDataChange!();
        }
        
        // 💡 修正: アプリを終了させる (OSが再起動を試みる)
        exit(0); 
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ファイルの選択がキャンセルされました。')));
      }
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラー: ファイルの内容が不正な形式です。')));
    } catch (e) {
      if (!context.mounted) return;
      
      // 暗号化/復号化のエラー判定を簡略化
      String errorMessage = e.toString();
      if (errorMessage.contains('Mac mismatch') || errorMessage.contains('Format') || errorMessage.contains('Key size')) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('エラー: ファイルの暗号化キーが一致しないか、データが破損しています。')));
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('インポート中にエラーが発生しました: $e')));
      }
    }
  }
  
  // 確認ダイアログを表示する関数 (変更なし)
  Future<void> _confirmAndImportData(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('データのインポート確認'),
          content: const Text('インポートを実行すると、既存のすべての記録データは上書きされ、削除されます.\nよろしいですか？'),
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
            subtitle: const Text('すべての記録を暗号化ファイルに保存します。'),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('データのインポート'),
            subtitle: const Text('既存の記録を上書きし、暗号化ファイルを読み込みます。インポート完了後、アプリを終了します。'),
            onTap: () async {
              await _confirmAndImportData(context);
            },
          ),
        ],
      ),
    );
  }
}