import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _filterNetwork = 'الكل';

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

  // بناء صف معلومات (مألوف)
  Widget _infoRow(IconData icon, String label, String value, Color color,
      [Color? textColor]) {
    final theme = Theme.of(context);
    final effectiveTextColor =
        textColor ?? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: effectiveTextColor)),
        Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: effectiveTextColor),
                textAlign: TextAlign.end)),
      ]),
    );
  }

  // مشاركة الكرت – نعيد استخدام نفس آلية البوستر من network_store_screen (مبسطة قليلاً)
  Future<void> _shareSingleCard(Map<String, dynamic> card) async {
    final GlobalKey posterKey = GlobalKey();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    final String pin = card['pin'] ?? 'لا يوجد';
    final String network = card['networkName'] ?? card['title'] ?? '';
    final String capacity = card['capacity'] ?? '';
    final String time = card['time'] ?? '';
    final String loginUrl = card['loginUrl'] ?? '';
    final String note = card['note'] ?? '';
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
                      if (capacity.isNotEmpty || time.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (capacity.isNotEmpty) ...[
                              Icon(Icons.data_usage, color: colorScheme.secondary, size: 16),
                              const SizedBox(width: 4),
                              Text(capacity, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                            ],
                            if (capacity.isNotEmpty && time.isNotEmpty) const SizedBox(width: 16),
                            if (time.isNotEmpty) ...[
                              Icon(Icons.timer, color: colorScheme.secondary, size: 16),
                              const SizedBox(width: 4),
                              Text(time, style: TextStyle(color: colorScheme.onSurface, fontSize: 14)),
                            ],
                          ],
                        ),
                      const SizedBox(height: 8),
                      if (date.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, color: Colors.teal, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(date,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 12))),
                          ],
                        ),
                      if (loginUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.language, color: Colors.indigo, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(loginUrl,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 12))),
                          ],
                        ),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(note,
                                    style: TextStyle(color: colorScheme.onSurface, fontSize: 12))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text('سعر الكرت: $unitPrice ريال',
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
السعة: $capacity
المدة: $time
تاريخ: $date
رابط: $loginUrl
سعر الكرت: $unitPrice ريال
$note
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

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isPos = sys.currentUserRole == 'pos';
    final theme = Theme.of(context);
    final currentPhone = sys.currentUserPhone;

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
            // حقل البحث وشريط التصفية
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن شبكة أو فئة...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: _filterNetwork,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'الكل', child: Text('الكل')),
                        // يمكن إضافة شبكات ديناميكية لاحقاً
                      ],
                      onChanged: (v) => setState(() => _filterNetwork = v!),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('cards')
                    .where('buyerPhone', isEqualTo: currentPhone)
                    .where('status', isEqualTo: 'مباع')
                    .orderBy('soldAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
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
                    );
                  }

                  final docs = snapshot.data!.docs;
                  // إحصائيات سريعة
                  double totalPaid = 0;
                  int totalCards = docs.length;
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    totalPaid += (data['soldPrice'] ?? data['price'] ?? 0).toDouble();
                  }

                  // تطبيق البحث والفلترة
                  var filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final network = (data['networkName'] ?? '').toLowerCase();
                    final category = (data['categoryName'] ?? data['title'] ?? '').toLowerCase();
                    final pin = (data['pin'] ?? '').toLowerCase();
                    final q = _searchQuery;
                    if (q.isNotEmpty &&
                        !network.contains(q) &&
                        !category.contains(q) &&
                        !pin.contains(q)) {
                      return false;
                    }
                    if (_filterNetwork != 'الكل') {
                      if (network != _filterNetwork.toLowerCase()) return false;
                    }
                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج مطابقة'));
                  }

                  // تجميع حسب التاريخ
                  Map<String, List<Map<String, dynamic>>> grouped = {};
                  for (var doc in filteredDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['soldAt'] as Timestamp?;
                    String dateKey = 'غير معروف';
                    if (timestamp != null) {
                      final d = timestamp.toDate();
                      dateKey = intl.DateFormat('yyyy/MM/dd').format(d);
                    }
                    grouped.putIfAbsent(dateKey, () => []).add({'docId': doc.id, ...data});
                  }

                  final sortedDates = grouped.keys.toList()
                    ..sort((a, b) => b.compareTo(a)); // الأحدث أولاً

                  return Column(
                    children: [
                      // بطاقات إحصائية صغيرة
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                      Text('$totalCards', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        child: ListView.builder(
                          itemCount: sortedDates.length,
                          itemBuilder: (context, index) {
                            final dateKey = sortedDates[index];
                            final cards = grouped[dateKey]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // رأسية التاريخ
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  color: theme.colorScheme.primary.withOpacity(0.08),
                                  child: Text(dateKey,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary)),
                                ),
                                ...cards.map((card) => _buildCardItem(card)),
                              ],
                            );
                          },
                        ),
                      ),
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
    final String network = card['networkName'] ?? card['title'] ?? '';
    final String category = card['categoryName'] ?? '';
    final String capacity = card['capacity'] ?? '';
    final String time = card['time'] ?? '';
    final String loginUrl = card['loginUrl'] ?? '';
    final String note = card['note'] ?? '';
    final double unitPrice = (card['unitPrice'] ?? card['price'] ?? 0).toDouble();
    final String date = card['soldAt'] != null
        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format((card['soldAt'] as Timestamp).toDate())
        : (card['date'] ?? '');

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
                        child: Text(category.isNotEmpty ? '$network - $category' : network,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.primary)),
                      ),
                      Text('$unitPrice ريال',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(pin,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  if (capacity.isNotEmpty || time.isNotEmpty)
                    Row(
                      children: [
                        if (capacity.isNotEmpty) ...[
                          const Icon(Icons.data_usage, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(capacity, style: const TextStyle(fontSize: 12)),
                          if (time.isNotEmpty) const SizedBox(width: 12),
                        ],
                        if (time.isNotEmpty) ...[
                          const Icon(Icons.timer, size: 14, color: Colors.purple),
                          const SizedBox(width: 4),
                          Text(time, style: const TextStyle(fontSize: 12)),
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
                          Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  if (loginUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () => launchUrl(Uri.parse(loginUrl)),
                        child: Row(
                          children: [
                            const Icon(Icons.language, size: 14, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(loginUrl,
                                    style: const TextStyle(fontSize: 11, color: Colors.blueAccent))),
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
                          Flexible(child: Text(note, style: const TextStyle(fontSize: 11))),
                        ],
                      ),
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
                _smallButton(Icons.share, 'مشاركة', () => _shareSingleCard(card)),
                _smallButton(Icons.save_alt, 'حفظ', () => _saveCardImage(card, cardKey)),
                if (loginUrl.isNotEmpty)
                  _smallButton(Icons.language, 'تسجيل الدخول', () {
                    launchUrl(Uri.parse(loginUrl), mode: LaunchMode.externalApplication);
                  }),
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
