import 'package:flutter/material.dart';

/// 실패 안내 끝에 붙이는 문구.
const retryHint = '인터넷 연결을 확인하고 다시 시도해 주세요';

extension ShowMessage on ScaffoldMessengerState {
  /// 화면 아래 짧은 안내. 앞 안내가 떠 있으면 바로 바꾼다 (여러 번 눌러도 쌓이지 않게).
  void showMessage(String text) {
    hideCurrentSnackBar();
    showSnackBar(SnackBar(content: Text(text)));
  }
}
