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

  // ---------- مشاركة الكرت (بوستر، نص) ----------
  Future<void> _shareSingleCard(Map<String, dynamic> card) async {
    final GlobalKey posterKey = GlobalKey();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final String pin = card['pin'] ?? '';
    final String network = card['networkName'] ?? _extractNetwork(card['title'] ?? '');
    final String price = (card['price'] ?? 0).toString();
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
                      colors: isDark
                          ? [colorScheme.surface, colorScheme.surface.withOpacity(0.8)]
                          : [colorScheme.primary.withOpacity(0.2), colorScheme.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
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
                      Text('السعر: $price ريال',
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
السعر: $price ريال
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

  String _extractNetwork(String title) {
    final parts = title.split(' - ');
    return parts.isNotEmpty ? parts.first : title;
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
    final cards = sys.userPurchasedCards.reversed.toList();

    // فلترة البحث
    final filteredCards = _searchQuery.isEmpty
        ? cards
        : cards.where((c) {
            final t = (c['title'] ?? '').toLowerCase();
            final p = (c['pin'] ?? '').toLowerCase();
            return t.contains(_searchQuery.toLowerCase()) ||
                p.contains(_searchQuery.toLowerCase());
          }).toList();

    // إحصائيات
    double totalPaid = filteredCards.fold(0, (sum, c) => sum + ((c['price'] ?? 0) as num).toDouble());

    // تجميع حسب التاريخ
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var card in filteredCards) {
      final dateStr = card['date'] ?? '';
      final formattedDate = _formatDate(dateStr).substring(0, 10); // yyyy/MM/dd
      grouped.putIfAbsent(formattedDate, () => []).add(card);
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
            // شريط البحث والإحصائيات
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
                decoration: InputDecoration(
                  hintText: 'ابحث عن شبكة أو فئة...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            if (filteredCards.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              const Text('عدد الكروت', style: TextStyle(fontSize: 11)),
                              Text('${filteredCards.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                          padding: const EdgeInsets.all(8.0),
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
              child: filteredCards.isEmpty
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
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary)),
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
    final GlobalKey cardKey = GlobalKey();
    final String pin = card['pin'] ?? 'غير معروف';
    final String title = card['title'] ?? '';
    final double price = (card['price'] ?? 0).toDouble();
    final String date = card['date'] ?? '';
    final String network = _extractNetwork(title);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            RepaintBoundary(
              key: cardKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.primary)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$price ريال',
                            style: const TextStyle(
                                color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(pin,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  if (date.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(_formatDate(date), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                ],
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
                _smallButton(Icons.share, 'مشاركة', () => _shareSingleCard({
                  ...card,
                  'networkName': network, // إضافة مفتاح ليسهل على المشاركة
                })),
                _smallButton(Icons.save_alt, 'حفظ', () => _saveCardImage(card, cardKey)),
              ],
            ),
          ],
        ),
      ),
    );
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
