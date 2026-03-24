import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'dart:math';

void main() => runApp(const FishingApp());

class FishingApp extends StatelessWidget {
  const FishingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, 
      title: 'Jarvis V61.9.2', // 修正版としてマイナーアップデート
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey), useMaterial3: true),
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

  int _selectedRate = 50; 
  int _ansInc = 0; int _ansEx = 0;
  int _sProf = 0; double _sRate = 0;
  int _aProf = 0; double _aRate = 0; int _aFee = 0; 

  String _fmt(int p) => p == 0 ? "0" : p.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  void _taxCalc(String v, bool isInc) {
    final int p = int.tryParse(v.replaceAll(',', '')) ?? 0;
    if (p == 0) {
      if (isInc) _exTaxController.clear(); else _incTaxController.clear();
      return;
    }
    setState(() {
      if (isInc) _exTaxController.text = (p / 1.1).floor().toString();
      else _incTaxController.text = (p * 1.1).floor().toString();
    });
  }

  void _calc() {
    final int s = int.tryParse(_sellPriceController.text.replaceAll(',', '')) ?? 0;
    final int r = int.tryParse(_reductionPriceController.text.replaceAll(',', '')) ?? 0;
    setState(() {
      if (s > 0) {
        _ansInc = max(0, (s * _selectedRate / 100).floor() - r);
        _ansEx = (_ansInc / 1.1).floor();
        _sProf = s - _ansInc; 
        _sRate = (_sProf / s) * 100;
        _aFee = (s * 0.1).floor(); // ヤフオク手数料10%
        _aProf = s - _aFee - 800 - _ansInc; // 手数料と送料800円を引く
        _aRate = (_aProf / s) * 100;
      } else {
        _ansInc = 0; _ansEx = 0; _sProf = 0; _sRate = 0; _aProf = 0; _aRate = 0; _aFee = 0;
      }
    });
  }

  // --- 修正箇所: iOSでの白画面抑制とURLエンコード対応 ---
  void _search(String t) async {
    String q = _searchController.text.trim();
    if (q.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: q));
    
    // 検索語句を安全なURL形式に変換
    final encodedQ = Uri.encodeComponent(q);
    
    String url;
    if (t == 'maker') {
      url = 'https://www.google.com/search?q=$encodedQ+定価';
    } else if (t == 'berry') {
      url = 'https://www.google.com/search?q=タックルベリー+在庫+$encodedQ';
    } else {
      url = 'https://auctions.yahoo.co.jp/closedsearch/closedsearch?p="$encodedQ"&va="$encodedQ"&istatus=2';
    }

    // window.openの代わりにAnchorElementを動的生成してクリック
    // これによりiOS Safari等の「戻る」挙動が安定し、空タブが残りにくくなります
    final anchor = html.AnchorElement(href: url)
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    anchor.click();
  }
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🤖 Jarvis V61.9.2'), centerTitle: true, toolbarHeight: 34, backgroundColor: Colors.blueGrey[50]),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(controller: _searchController, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: '商品名を入力', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _btn('定価検索', Colors.blueGrey, () => _search('maker')),
                  const SizedBox(width: 8),
                  Expanded(child: Column(children: [
                    _field(_incTaxController, '定価(税込)', (v) => _taxCalc(v, true)),
                    const SizedBox(height: 4),
                    _field(_exTaxController, '定価(税抜)', (v) => _taxCalc(v, false)),
                  ])),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _btn('TB相場', const Color(0xFF2E7D32), () => _search('berry')), 
                  const SizedBox(width: 8), 
                  Expanded(child: _field(_berryPriceController, 'タックルベリー価格', (v) { 
                    final int b = int.tryParse(v.replaceAll(',',''))??0; 
                    if(b>0){ _sellPriceController.text = ((b / 100).floor() * 100).toString(); _calc(); } 
                  })),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _btn('ヤフオク', const Color(0xFFC62828), () => _search('yahoo')), 
                  const SizedBox(width: 8), 
                  Expanded(child: _field(_yahooPriceController, '落札相場', (v) { 
                    final int y = int.tryParse(v.replaceAll(',',''))??0; 
                    if(y>0){ _sellPriceController.text = ((y / 100).floor() * 100).toString(); _calc(); } 
                  })),
                ]),
                const Divider(height: 30),
                Row(children: [
                  Expanded(flex: 3, child: TextField(controller: _sellPriceController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_)=>_calc(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: '店舗販売予定価格', prefixText: '¥ ', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  SizedBox(width: 85, child: DropdownButtonFormField<int>(value: _selectedRate, items: [30,35,40,45,50,55,60,70].map((v)=>DropdownMenuItem(value: v, child: Text('$v%'))).toList(), onChanged: (v){setState(()=>_selectedRate=v!);_calc();}, decoration: const InputDecoration(isDense: true, labelText: '買取率', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _reductionPriceController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_)=>_calc(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24), decoration: const InputDecoration(labelText: '状態・欠品による減額', prefixText: '¥ ', prefixStyle: TextStyle(color: Colors.red, fontWeight: FontWeight.bold), labelStyle: TextStyle(color: Colors.red), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)))),
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
    );
  }

  Widget _field(TextEditingController c, String h, Function(String) o) => TextField(controller: c, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: o, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), decoration: InputDecoration(isDense: true, labelText: h, prefixText: '¥ ', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(10)));
  Widget _btn(String l, Color c, VoidCallback p) => SizedBox(width: 90, height: 45, child: ElevatedButton(onPressed: p, style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))));
  Widget _resCard() => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE65100), width: 4)), child: Column(children: [const Text('お客様提示額 (税込)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text('¥ ${_fmt(_ansInc)}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFBF360C), height: 1.0)), Text('(税抜: ¥ ${_fmt(_ansEx)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]));
  Widget _profCard(String t, int p, double r, int? f, Color c) => Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), decoration: BoxDecoration(border: Border.all(color: c, width: 2), borderRadius: BorderRadius.circular(6)), child: Column(mainAxisSize: MainAxisSize.max, children: [
    Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
    if (f != null) Text('手数料: ¥${_fmt(f)}', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
    if (f == null) const SizedBox(height: 13.0),
    Text('¥${_fmt(p)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: c)),
    Text('粗利率: ${r.toStringAsFixed(1)}%', style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13)),
  ]));
}