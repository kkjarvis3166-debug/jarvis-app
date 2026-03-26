import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:async';

void main() {
  runApp(const FishingApp());
}

class FishingApp extends StatelessWidget {
  const FishingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jarvis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const ResearchPage(),
    );
  }
}

class ResearchPage extends StatefulWidget {
  const ResearchPage({super.key});

  @override
  State<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends State<ResearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _incTaxController = TextEditingController();
  final TextEditingController _exTaxController = TextEditingController();
  final TextEditingController _berryPriceController = TextEditingController();
  final TextEditingController _yahooPriceController = TextEditingController();
  final TextEditingController _sellPriceController = TextEditingController();
  final TextEditingController _reductionPriceController = TextEditingController();

  // キャンペーン用状態
  bool _isCampaignOn = false;
  double _campaignBonusRate = 20.0;
  // 初期値を今日の23:59に設定
  DateTime _campaignEndTime = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
  );

  int _selectedRate = 50;
  int _ansInc = 0;
  int _ansEx = 0;
  int _sProf = 0;
  double _sRate = 0;
  int _aProf = 0;
  double _aRate = 0;
  int _aFee = 0;

  @override
  void initState() {
    super.initState();
    _loadCampaignSettings();
    // 1分ごとにキャンペーン終了をチェックして自動更新
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  // 設定の読み込み
  Future<void> _loadCampaignSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isCampaignOn = prefs.getBool('cp_on') ?? false;
      _campaignBonusRate = prefs.getDouble('cp_rate') ?? 20.0;
      final endStr = prefs.getString('cp_end');
      if (endStr != null) {
        _campaignEndTime = DateTime.parse(endStr);
      } else {
        // 保存データがない場合も23:59をデフォルトに
        final now = DateTime.now();
        _campaignEndTime = DateTime(now.year, now.month, now.day, 23, 59);
      }
    });
    _calc(); // 読み込み後に再計算
  }

  // 設定の保存
  Future<void> _saveCampaignSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cp_on', _isCampaignOn);
    await prefs.setDouble('cp_rate', _campaignBonusRate);
    await prefs.setString('cp_end', _campaignEndTime.toIso8601String());
    _calc();
  }

  // キャンペーンが現在有効か判定
  bool get _isCampaignActive {
    return _isCampaignOn && DateTime.now().isBefore(_campaignEndTime);
  }

  String _fmt(int p) => p == 0
      ? "0"
      : p.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  void _taxCalc(String v, bool isInc) {
    final int p = int.tryParse(v.replaceAll(',', '')) ?? 0;
    if (p == 0) {
      if (isInc) {
        _exTaxController.clear();
      } else {
        _incTaxController.clear();
      }
      return;
    }
    setState(() {
      if (isInc) {
        _exTaxController.text = (p / 1.1).floor().toString();
      } else {
        _incTaxController.text = (p * 1.1).floor().toString();
      }
    });
  }

  void _calc() {
    final int s =
        int.tryParse(_sellPriceController.text.replaceAll(',', '')) ?? 0;
    final int r =
        int.tryParse(_reductionPriceController.text.replaceAll(',', '')) ?? 0;

    setState(() {
      if (s > 0) {
        // 通常の買取額（税抜計算の基礎）
        double baseCalculated = s * _selectedRate / 100;

        // キャンペーン適用（有効な場合のみ倍率をかける）
        if (_isCampaignActive) {
          baseCalculated *= (1 + _campaignBonusRate / 100);
        }

        _ansInc = max(0, baseCalculated.floor() - r);
        _ansEx = (_ansInc / 1.1).floor();
        _sProf = s - _ansInc;
        _sRate = (_sProf / s) * 100;
        _aFee = (s * 0.1).floor();
        _aProf = s - _aFee - 800 - _ansInc;
        _aRate = (_aProf / s) * 100;
      } else {
        _ansInc = 0;
        _ansEx = 0;
        _sProf = 0;
        _sRate = 0;
        _aProf = 0;
        _aRate = 0;
        _aFee = 0;
      }
    });
  }

  Future<void> _search(String type) async {
    final String query = _searchController.text.trim();
    if (query.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: query));
    final encodedQuery = Uri.encodeComponent(query);
    String urlString;

    if (type == 'maker') {
      urlString = 'https://www.google.com/search?q=$encodedQuery+定価';
    } else if (type == 'berry') {
      urlString = 'https://www.google.com/search?q=タックルベリー+在庫+$encodedQuery';
    } else {
      urlString =
          'https://auctions.yahoo.co.jp/closedsearch/closedsearch?p="$encodedQuery"&va="$encodedQuery"&istatus=2';
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  // 管理者認証ダイアログ
  void _showAdminAuth() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('管理者認証'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'PINコードを入力'),
          obscureText: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              if (controller.text == '1234') { // PINコード
                Navigator.pop(context);
                _showCampaignSettings();
              }
            },
            child: const Text('認証'),
          ),
        ],
      ),
    );
  }

  // キャンペーン設定画面
  void _showCampaignSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20, left: 20, right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('キャンペーン設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('状態：'),
                  Radio<bool>(
                    value: true,
                    groupValue: _isCampaignOn,
                    onChanged: (v) => setModalState(() => _isCampaignOn = v!),
                  ),
                  const Text('ON'),
                  Radio<bool>(
                    value: false,
                    groupValue: _isCampaignOn,
                    onChanged: (v) => setModalState(() => _isCampaignOn = v!),
                  ),
                  const Text('OFF'),
                ],
              ),
              TextField(
                decoration: const InputDecoration(labelText: '買取アップ率 (%)', suffixText: '%'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _campaignBonusRate = double.tryParse(v) ?? 20.0,
                controller: TextEditingController(text: _campaignBonusRate.toInt().toString()),
              ),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('終了日を選択（時刻は23:59にセットされます）'),
                subtitle: Text('${_campaignEndTime.year}/${_campaignEndTime.month}/${_campaignEndTime.day} ${_campaignEndTime.hour}:${_campaignEndTime.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _campaignEndTime,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null && context.mounted) {
                    setModalState(() {
                      // 日付を選んだら、時刻を強制的に23:59にする
                      _campaignEndTime = DateTime(date.year, date.month, date.day, 23, 59);
                    });
                  }
                },
              ),
              // 時刻だけ微調整したい時のためのオプション
              TextButton(
                onPressed: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_campaignEndTime),
                  );
                  if (time != null && context.mounted) {
                    setModalState(() {
                      _campaignEndTime = DateTime(
                        _campaignEndTime.year, _campaignEndTime.month, _campaignEndTime.day,
                        time.hour, time.minute,
                      );
                    });
                  }
                },
                child: const Text('時刻を細かく指定する', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  _saveCampaignSettings();
                  Navigator.pop(context);
                },
                child: const Text('設定を保存して戻る'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Jarvis'),
        centerTitle: true,
        toolbarHeight: 34,
        backgroundColor: Colors.blueGrey[50],
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 18, color: Colors.grey),
            onPressed: _showAdminAuth,
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Text(
                'V61.9.11',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // キャンペーン中のみネオンバナーを表示
          if (_isCampaignActive)
            NeonBanner(rate: _campaignBonusRate, endTime: _campaignEndTime),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: '商品名を入力',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _btn('定価検索', Colors.blueGrey, () => _search('maker')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              children: [
                                _field(_incTaxController, '定価(税込)', (v) => _taxCalc(v, true)),
                                const SizedBox(height: 4),
                                _field(_exTaxController, '定価(税抜)', (v) => _taxCalc(v, false)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _btn('TB相場', const Color(0xFF2E7D32), () => _search('berry')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _field(_berryPriceController, 'タックルベリー価格', (v) {
                              final int b = int.tryParse(v.replaceAll(',', '')) ?? 0;
                              if (b > 0) {
                                _sellPriceController.text = ((b / 100).floor() * 100).toString();
                                _calc();
                              }
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _btn('ヤフオク', const Color(0xFFC62828), () => _search('yahoo')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _field(_yahooPriceController, '落札相場', (v) {
                              final int y = int.tryParse(v.replaceAll(',', '')) ?? 0;
                              if (y > 0) {
                                _sellPriceController.text = ((y / 100).floor() * 100).toString();
                                _calc();
                              }
                            }),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _sellPriceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (_) => _calc(),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                labelText: '店舗販売予定価格',
                                prefixText: '¥ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 85,
                            child: DropdownButtonFormField<int>(
                              value: _selectedRate,
                              items: [30, 35, 40, 45, 50, 55, 60, 65, 70]
                                  .map((v) => DropdownMenuItem(value: v, child: Text('$v%')))
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _selectedRate = v!);
                                _calc();
                              },
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: '買取率',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reductionPriceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => _calc(),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24),
                        decoration: const InputDecoration(
                          labelText: '状態・欠品による減額',
                          prefixText: '¥ ',
                          prefixStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          labelStyle: TextStyle(color: Colors.red),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _resCard(),
                      const SizedBox(height: 15),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(child: _profCard('店舗販売利益', _sProf, _sRate, null, const Color(0xFF0D47A1))),
                            const SizedBox(width: 8),
                            Expanded(child: _profCard('ヤフオク利益', _aProf, _aRate, _aFee, const Color(0xFFBF360C))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String h, Function(String) o) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: o,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          isDense: true,
          labelText: h,
          prefixText: '¥ ',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(10),
        ),
      );

  Widget _btn(String l, Color c, VoidCallback p) => SizedBox(
        width: 90,
        height: 45,
        child: ElevatedButton(
          onPressed: p,
          style: ElevatedButton.styleFrom(
            backgroundColor: c,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _resCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE65100), width: 4),
        ),
        child: Column(
          children: [
            const Text('お客様提示額 (税込)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('¥ ${_fmt(_ansInc)}',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFBF360C), height: 1.0)),
            Text('(税抜: ¥ ${_fmt(_ansEx)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );

  Widget _profCard(String t, int p, double r, int? f, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: c, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
            if (f != null)
              Text('手数料: ¥${_fmt(f)}', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
            if (f == null) const SizedBox(height: 13.0),
            Text('¥${_fmt(p)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: c)),
            Text('粗利率: ${r.toStringAsFixed(1)}%', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
}

// --- ネオンバナーコンポーネント (【完全修正】時計回り・レイアウト修正版) ---
class NeonBanner extends StatefulWidget {
  final double rate;
  final DateTime endTime;
  const NeonBanner({super.key, required this.rate, required this.endTime});

  @override
  State<NeonBanner> createState() => _NeonBannerState();
}

class _NeonBannerState extends State<NeonBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 回転スピード（3秒で1周）
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // バナー全体の高さを、中のテキストの高さ＋Padding（枠の幅）分にする
    final textColumn = Column(
      mainAxisSize: MainAxisSize.min, // 最小限の高さに
      children: [
        // メインテキスト
        Text(
          '買取価格 ${widget.rate.toInt()}%UP 適用中！',
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w900,
            fontSize: 20, // 少し大きく
          ),
        ),
        const SizedBox(height: 2),
        // 期限テキスト（サイズアップ）
        Text(
          '〜 ${widget.endTime.month}/${widget.endTime.day} ${widget.endTime.hour}:${widget.endTime.minute.toString().padLeft(2, '0')} まで',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16, // パッと見で分かるサイズに
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      color: Colors.yellow, // 最外層（黄色背景）
      child: Stack(
        alignment: Alignment.center, // テキスト部分を中央に
        children: [
          // 時計回り電飾（最外層Containerの全領域に広がる）
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(painter: NeonPainter(progress: _controller.value)),
            ),
          ),
          // テキスト部分（LED枠の内側にPaddingを持って配置）
          Padding(
            padding: const EdgeInsets.all(12.0), // LED枠の幅（上下左右12px）
            child: textColumn,
          )
        ]
      )
    );
  }
}

// --- 時計回り電飾の描画ロジック ---
class NeonPainter extends CustomPainter {
  final double progress;
  NeonPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    const double dotSize = 5.0; // LEDの大きさ
    const double spacing = 15.0; // LEDの間隔

    // バナーの四辺を巡るパスを作成
    final path = Path()
      ..moveTo(0, 0) // 左上
      ..lineTo(size.width, 0) // 上辺：左→右
      ..lineTo(size.width, size.height) // 右辺：上→下
      ..lineTo(0, size.height) // 下辺：右→左
      ..close(); // 左辺：下→上（閉じる）

    // パスの計測情報を取得
    final metrics = path.computeMetrics();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final totalLength = metric.length;

    // パスに沿って一定間隔でドットを描画
    for (double distance = 0; distance < totalLength; distance += spacing) {
      // 現在の距離に対応する座標を取得
      final tangent = metric.getTangentForOffset(distance);
      if (tangent == null) continue;
      final offset = tangent.position;

      // このドットの全周における位置割合 (0.0 ～ 1.0)
      final positionRatio = distance / totalLength;

      // 流れるような点滅ロジック
      // progress(0->1)が増える時、positionRatio(パス上の位置)が追いかけるように不透明度を計算
      final opacity = ((progress - positionRatio) % 1.0);
      
      // 不透明度が一定以上のドットだけを明るく光らせる（チェイス演出）
      paint.color = Colors.red.withOpacity(opacity > 0.85 ? 1.0 : 0.15);

      canvas.drawCircle(offset, dotSize / 2, paint);
    }
  }

  @override
  bool shouldRepaint(NeonPainter oldDelegate) => true;
}