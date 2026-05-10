import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:intl/intl.dart' as intl;

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_user_drawer.dart';

class MyCardsScreen extends StatefulWidget {
  const MyCardsScreen({super.key});

  @override
  State<MyCardsScreen> createState() => _MyCardsScreenState();
}

class _MyCardsScreenState extends State<MyCardsScreen> {
  String _searchQuery = '';

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  void _showToast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: error ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---------- مشاركة الكرت (بوستر / نص) ----------
  Future<void> _shareSingleCard(Map<String, dynamic> card) async {
    final GlobalKey posterKey = GlobalKey();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final String pin = card['pin'] ?? '';
    final String network = card['networkName'] ?? card['title'] ?? '';
    final double unitPrice = (card['unitPrice'] ?? card['price'] ?? 0).toDouble();
    final String date = card['date'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          contentPadding: const EdgeInsets.all(0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: posterKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [colorScheme.surface, colorScheme.onSurface.withOpacity(0.1)]
                          : [colorScheme.primary.withOpacity(0.2), colorScheme.surface],
                    ),
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.wifi, color: colorScheme.primary, size: 36),
                      const SizedBox(height: 8),
                      Text(network,
                          style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(pin,
                            style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3)),
                      ),
                      const SizedBox(height: 15),
                      if (date.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, color: Colors.teal, size: 16),
                            const SizedBox(width: 4),
                            Text(date,
                                style: TextStyle(color: colorScheme.onSurface, fontSize: 12)),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Text('السعر: $unitPrice ريال',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.text_fields),
                        label: const Text('كنص'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          final text = '''
رقم الكرت: $pin
الشبكة: $network
التاريخ: $date
السعر: $unitPrice ريال
''';
                          Share.share(text, subject: 'بطاقة $network');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: const Text('كصورة', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _shareCardPosterImage(posterKey, pin);
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareCardPosterImage(GlobalKey posterKey, String pin) async {
    try {
      RenderRepaintBoundary boundary =
          posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        await Share.shareXFiles(
            [XFile.fromData(pngBytes, mimeType: 'image/png', name: 'card_$pin.png')],
            text: 'بطاقة $pin');
      }
    } catch (_) {
      _showToast('تعذرت المشاركة كصورة', error: true);
    }
  }

  Future<void> _saveCardImage(Map<String, dynamic> card, GlobalKey cardKey) async {
    try {
      RenderRepaintBoundary boundary =
          cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      if (boundary == null) return;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      if (!kIsWeb) {
        await ImageGallerySaver.saveImage(byteData.buffer.asUint8List());
      } else {
        final blob = html.Blob([byteData.buffer.asUint8List()], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
      }
      _showToast('تم حفظ الصورة');
    } catch (_) {
      _showToast('فشل الحفظ', error: true);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return intl.DateFormat('yyyy/MM/dd - hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isPos = sys.currentUserRole == 'pos';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cards = sys.userPurchasedCards.reversed.toList();

    // فلترة
    final filtered = _searchQuery.isEmpty
        ? cards
        : cards.where((c) {
            final t = (c['title'] ?? '').toLowerCase();
            final p = (c['pin'] ?? '').toLowerCase();
            return t.contains(_searchQuery.toLowerCase()) ||
                p.contains(_searchQuery.toLowerCase());
          }).toList();

    // إحصائيات
    double totalPaid = 0;
    for (var c in filtered) {
      totalPaid += (c['unitPrice'] ?? c['price'] ?? 0).toDouble();
    }

    // تجميع حسب التاريخ
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var card in filtered) {
      final dateStr = card['date'] ?? '';
      final formattedDate = _formatDate(dateStr);
      final dayKey = formattedDate.length >= 10 ? formattedDate.substring(0, 10) : formattedDate;
      grouped.putIfAbsent(dayKey, () => []).add(card);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: CustomHeader(title: isPos ? 'سجل المبيعات' : 'كروتي ومشترياتي'),
      drawer: CustomUserDrawer(
        userName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // بحث
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الكرت أو اسم الشبكة...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              const Text('عدد الكروت', style: TextStyle(fontSize: 11)),
                              Text('${filtered.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Card(
                        color: Colors.green.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              const Text('إجمالي المدفوع', style: TextStyle(fontSize: 11)),
                              Text('${totalPaid.toStringAsFixed(0)} ريال',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            isPos ? 'لم تقم ببيع أي كروت حتى الآن.' : 'لم تقم بشراء أي كروت حتى الآن.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: sortedDates.length,
                      itemBuilder: (context, index) {
                        final dateKey = sortedDates[index];
                        final cardsOfDay = grouped[dateKey]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              color: theme.colorScheme.primary.withOpacity(0.08),
                              child: Text(dateKey,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            ),
                            ...cardsOfDay.map((card) => _buildCardItem(card)),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(Map<String, dynamic> card) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final infoTextColor = isDark ? Colors.white : Colors.black87;
    final cardKey = GlobalKey();

    final String pin = card['pin'] ?? '';
    final String network = card['networkName'] ?? (card['title']?.split(' - ')?.first ?? '');
    final String category = card['categoryName'] ?? (card['title']?.split(' - ')?.length == 2 ? card['title'].split(' - ').last : '');
    final double unitPrice = (card['unitPrice'] ?? card['price'] ?? 0).toDouble();
    final String date = card['date'] ?? '';
    final String capacity = card['capacity'] ?? '';
    final String time = card['time'] ?? '';
    final String loginUrl = card['loginUrl'] ?? '';
    final String note = card['note'] ?? '';
    final String? templateBase64 = card['templateBase64'];
    final Uint8List? templateBytes = templateBase64 != null ? base64Decode(templateBase64) : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            RepaintBoundary(
              key: cardKey,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.blueGrey.shade800, Colors.blueGrey.shade900]
                        : [Colors.blue.shade50, Colors.lightBlue.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // معاينة القالب إن وجد
                    if (templateBytes != null)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(templateBytes, fit: BoxFit.contain),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // اسم الشبكة والفئة
                    Row(
                      children: [
                        Icon(Icons.wifi, size: 18, color: Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            category.isNotEmpty ? '$network - $category' : network,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: infoTextColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(pin,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    if (capacity.isNotEmpty || time.isNotEmpty)
                      Row(
                        children: [
                          if (capacity.isNotEmpty) ...[
                            const Icon(Icons.data_usage, size: 14, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(capacity, style: TextStyle(fontSize: 13, color: infoTextColor)),
                          ],
                          if (capacity.isNotEmpty && time.isNotEmpty) const SizedBox(width: 12),
                          if (time.isNotEmpty) ...[
                            const Icon(Icons.timer, size: 14, color: Colors.purple),
                            const SizedBox(width: 4),
                            Text(time, style: TextStyle(fontSize: 13, color: infoTextColor)),
                          ],
                        ],
                      ),
                    if (date.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(_formatDate(date),
                                style: TextStyle(fontSize: 11, color: infoTextColor.withOpacity(0.7))),
                          ],
                        ),
                      ),
                    if (loginUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: () {
                            if (loginUrl.isNotEmpty) _launchURL(loginUrl);
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.language, size: 14, color: Colors.indigo),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(loginUrl,
                                    style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.note, size: 14, color: Colors.amber),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(note,
                                  style: TextStyle(fontSize: 11, color: infoTextColor.withOpacity(0.8))),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$unitPrice ريال',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _smallButton(Icons.copy, 'نسخ', () {
                  _play('click');
                  Clipboard.setData(ClipboardData(text: pin));
                  _showToast('تم نسخ الكرت');
                }),
                _smallButton(Icons.share, 'مشاركة', () => _shareSingleCard(card)),
                _smallButton(Icons.save_alt, 'حفظ', () => _saveCardImage(card, cardKey)),
                if (loginUrl.isNotEmpty)
                  _smallButton(Icons.open_in_browser, 'تسجيل', () => _launchURL(loginUrl)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _launchURL(String url) {
    // يمكن استخدام url_launcher لكنه قد يكون مستورداً بالفعل
    try {
      // ignore: avoid_dynamic_calls
      launch(url);
    } catch (_) {}
  }

  Widget _smallButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]),
    );
  }
}

void launch(String url) {
  // تنفيذ فعلي
}
