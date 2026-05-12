import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class SubAgentsScreen extends StatefulWidget {
  const SubAgentsScreen({super.key});

  @override
  State<SubAgentsScreen> createState() => _SubAgentsScreenState();
}

class _SubAgentsScreenState extends State<SubAgentsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  String _searchQuery = '';
  String _selectedFilter = 'الكل';

  // إنذار مبكر عالمي (قيمة افتراضية 1000 ريال)
  double _globalWarningThreshold = 1000.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _globalWarningThreshold =
          prefs.getDouble('globalWarningThreshold') ?? 1000.0;
    });
  }

  Future<void> _saveGlobalWarningThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('globalWarningThreshold', value);
    setState(() => _globalWarningThreshold = value);
  }

  void _play(String type) =>
      Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ---------- نافذة إعدادات الحد الأدنى للإنذار ----------
  void _showGlobalThresholdDialog() {
    _play('click');
    final controller =
        TextEditingController(text: _globalWarningThreshold.toString());
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات الإنذار المبكر'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'الحد الأدنى للرصيد (ريال)',
                border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  _saveGlobalWarningThreshold(val);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('تم حفظ الحد الأدنى للإنذار'),
                        backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- نافذة استلام دفعة (يدوي) محسنة ----------
  void _showRepaymentModal(SystemProvider sys, String posPhone, String posName,
      double currentDebt) {
    _play('click');
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    bool isSubmitting = false;
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('استلام دفعة من $posName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الدين الحالي: ${NumberFormat('#,##0').format(currentDebt)} ريال',
                  style: TextStyle(
                      color: colors.error, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'المبلغ المستلم (ريال)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                      labelText: 'ملاحظة (اختياري)',
                      border: OutlineInputBorder()),
                ),
                // عرض المبلغ المتبقي بعد السداد عند إدخال المبلغ
                if (amountController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'المبلغ المتبقي بعد السداد: ${NumberFormat('#,##0').format(currentDebt - (double.tryParse(amountController.text) ?? 0))} ريال',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          await sys.receivePosPayment(
                              posPhone, amount, noteController.text);
                          _play('success');
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'تم استلام $amount ريال بنجاح ✅',
                                      textDirection: TextDirection.rtl),
                                  backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          _play('error');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e.toString(),
                                      textDirection: TextDirection.rtl),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('تأكيد الاستلام',
                        style: TextStyle(color: colors.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- تغذية المحفظة (مع تسوية الديون التلقائية) ----------
  void _showFeedWalletModal(
      SystemProvider sys, String posPhone, String posName) {
    _play('click');
    final amountController = TextEditingController();
    bool isSubmitting = false;
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تغذية محفظة $posName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'رصيدك الحالي: ${NumberFormat('#,##0').format(sys.currentUserBalance)} ريال',
                  style: TextStyle(
                      color: colors.primary, fontWeight: FontWeight.bold),
                ),
                // عرض رصيد البقالة الحالي (إن أمكن)
                FutureBuilder<DocumentSnapshot>(
                  future: _db.collection('users').doc(posPhone).get(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox();
                    final wallets =
                        (snap.data!.data() as Map<String, dynamic>)['wallets']
                            as Map<String, dynamic>?;
                    final bal =
                        (wallets?[sys.currentUserPhone] ?? 0.0).toDouble();
                    return Text(
                      'رصيد البقالة الحالي: ${NumberFormat('#,##0').format(bal)} ريال',
                      style: TextStyle(
                          color: bal < 0 ? colors.error : colors.onSurfaceVariant,
                          fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'المبلغ المراد تحويله (ريال)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        if (amount <= 0) return;
                        if (amount > sys.currentUserBalance) {
                          _play('error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('رصيدك لا يكفي!',
                                    textDirection: TextDirection.rtl),
                                backgroundColor: Colors.red),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          // جلب الرصيد الحالي للبقالة لتسجيل تسوية الدين
                          final posDoc =
                              await _db.collection('users').doc(posPhone).get();
                          final wallets =
                              (posDoc.data() as Map<String, dynamic>)['wallets']
                                  as Map<String, dynamic>?;
                          final oldBalance =
                              (wallets?[sys.currentUserPhone] ?? 0.0)
                                  .toDouble();
                          final debt = oldBalance < 0 ? -oldBalance : 0.0;

                          // تغذية المحفظة (تقلل الدين تلقائياً)
                          await sys.fundSubAgent(posPhone, amount);

                          // تسجيل معاملة تسوية الديون إن وجدت
                          if (debt > 0 && amount >= debt) {
                            _db.collection('transactions').add({
                              'fromPhone': sys.currentUserPhone,
                              'toPhone': posPhone,
                              'agentPhone': sys.currentUserPhone,
                              'agentName': sys.currentUserName,
                              'targetName': posName,
                              'amount': debt,
                              'type': 'debt_settlement',
                              'title': 'تسوية دين قديم تلقائياً',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          } else if (debt > 0 && amount < debt) {
                            _db.collection('transactions').add({
                              'fromPhone': sys.currentUserPhone,
                              'toPhone': posPhone,
                              'agentPhone': sys.currentUserPhone,
                              'agentName': sys.currentUserName,
                              'targetName': posName,
                              'amount': amount,
                              'type': 'debt_settlement_partial',
                              'title': 'تسوية جزء من الدين تلقائياً',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          }

                          _play('success');
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'تم التحويل وتسوية الديون إن وجدت ✅',
                                      textDirection: TextDirection.rtl),
                                  backgroundColor: Colors.green),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          _play('error');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e.toString(),
                                      textDirection: TextDirection.rtl),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('تحويل',
                        style: TextStyle(color: colors.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- إضافة / تعديل البقالة (مع خريطة) ----------
  void _showAddOrEditPosModal(SystemProvider sys,
      {Map<String, dynamic>? existingPos, String? initialPhone}) async {
    _play('click');
    final isEdit = existingPos != null;
    String phone = initialPhone ?? existingPos?['phone'] ?? '';
    String name = existingPos?['storeName'] ?? '';
    String location = existingPos?['location'] ?? '';
    double? lat = existingPos?['latitude']?.toDouble();
    double? lng = existingPos?['longitude']?.toDouble();

    Map<String, dynamic> relations = existingPos?['agent_relations'] ?? {};
    Map<String, dynamic> myRel = relations[sys.currentUserPhone] ?? {};
    String commission =
        myRel['commission']?.toString().replaceAll('%', '') ?? '0';
    double limit = (myRel['creditLimit'] ?? 0.0).toDouble();
    final double oldLimit = limit;
    List<String> allowedCats =
        List<String>.from(myRel['allowedCategories'] ?? []);
    bool isSubmitting = false;
    final colors = Theme.of(context).colorScheme;

    // جلب الفئات المتاحة
    var netSnap = await _db
        .collection('networks')
        .where('agentPhone', isEqualTo: sys.currentUserPhone)
        .get();
    List<Map<String, dynamic>> allAvailableCats = [];
    for (var doc in netSnap.docs) {
      List cats = doc['categories'] ?? [];
      for (var c in cats) {
        allAvailableCats
            .add({'id': c['id'], 'name': '${doc['name']} - ${c['name']}'});
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 20,
              left: 16,
              right: 16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEdit ? 'تعديل بيانات البقالة ⚙️' : 'ترقية زبون إلى بقالة 🏪',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface),
                  ),
                  const SizedBox(height: 15),
                  if (!isEdit)
                    TextField(
                      enabled: initialPhone == null,
                      controller: TextEditingController(text: phone),
                      onChanged: (v) => phone = v,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم هاتف الزبون',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: name),
                    onChanged: (v) => name = v,
                    decoration: const InputDecoration(
                      labelText: 'اسم البقالة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: location),
                    onChanged: (v) => location = v,
                    decoration: const InputDecoration(
                      labelText: 'الموقع (نص)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked =
                              await _pickLocationOnMap(lat: lat, lng: lng);
                          if (picked != null) {
                            setModalState(() {
                              lat = picked['lat'];
                              lng = picked['lng'];
                              location = picked['address'] ?? location;
                            });
                          }
                        },
                        icon: const Icon(Icons.map),
                        label: Text((lat != null && lng != null)
                            ? 'تم تحديد الموقع ✅'
                            : 'اختيار من الخريطة'),
                      ),
                    ],
                  ),
                  if (lat != null && lng != null)
                    Text(
                      'الإحداثيات: ${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)}',
                      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              TextEditingController(text: limit.toString()),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            setModalState(
                                () => limit = double.tryParse(v) ?? 0);
                          },
                          decoration: InputDecoration(
                            labelText: 'الحد الائتماني',
                            border: const OutlineInputBorder(),
                            errorText: (limit > sys.currentUserBalance &&
                                    !isEdit)
                                ? 'أكبر من رصيدك!'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller:
                              TextEditingController(text: commission),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => commission = v,
                          decoration: const InputDecoration(
                            labelText: 'العمولة %',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isEdit && limit > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: colors.errorContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        'سيتم خصم $limit ريال من رصيدك عند الترقية.',
                        style: TextStyle(
                            color: colors.error,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'تحديد الفئات المسموح بيعها:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.primary),
                    ),
                  ),
                  if (allAvailableCats.isEmpty)
                    Text(
                      'لم تقم بإضافة فئات في قسم المايكروتيك بعد!',
                      style: TextStyle(color: colors.error, fontSize: 12),
                    ),
                  ...allAvailableCats.map((cat) => CheckboxListTile(
                        title: Text(cat['name'],
                            style: TextStyle(fontSize: 13, color: colors.onSurface)),
                        value: allowedCats.contains(cat['id']),
                        activeColor: colors.primary,
                        onChanged: (val) {
                          setModalState(() {
                            val!
                                ? allowedCats.add(cat['id'])
                                : allowedCats.remove(cat['id']);
                          });
                        },
                      )),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary),
                      onPressed: (isSubmitting ||
                              (!isEdit && limit > sys.currentUserBalance))
                          ? null
                          : () async {
                              if (phone.isEmpty ||
                                  name.isEmpty ||
                                  location.isEmpty) {
                                _play('error');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'الرقم والاسم والموقع حقول إجبارية!',
                                          textDirection:
                                              TextDirection.rtl),
                                      backgroundColor: Colors.red),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              try {
                                if (isEdit) {
                                  await sys.updatePosDetails(
                                    posPhone: phone,
                                    storeName: name,
                                    location: location,
                                    creditLimit: limit,
                                    commission: '$commission%',
                                    allowedCategories: allowedCats,
                                    oldCreditLimit: oldLimit,
                                  );
                                } else {
                                  await sys.upgradeUserToPos(
                                    posPhone: phone,
                                    storeName: name,
                                    location: location,
                                    creditLimit: limit,
                                    commission: '$commission%',
                                    allowedCategories: allowedCats,
                                    creditDeduction: limit,
                                  );
                                }
                                // تحديث الإحداثيات في وثيقة المستخدم
                                if (lat != null && lng != null) {
                                  await _db
                                      .collection('users')
                                      .doc(phone)
                                      .update({
                                    'latitude': lat,
                                    'longitude': lng,
                                  });
                                }
                                _play('success');
                                Navigator.pop(ctx);
                              } catch (e) {
                                setModalState(() => isSubmitting = false);
                                _play('error');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(e.toString(),
                                            textDirection:
                                                TextDirection.rtl),
                                        backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                      child: isSubmitting
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : Text(
                              isEdit ? 'حفظ التعديلات' : 'اعتماد وترقية',
                              style: TextStyle(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- خريطة اختيار الموقع ----------
  Future<Map<String, dynamic>?> _pickLocationOnMap(
      {double? lat, double? lng}) async {
    double selectedLat = lat ?? 15.3694;
    double selectedLng = lng ?? 44.1910;
    String selectedAddress = '';
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    Future<List<Map<String, dynamic>>> _search(String q) async {
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(q)}&limit=5');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(res.body);
          return data
              .map((e) => {
                    'name': e['display_name'],
                    'lat': double.parse(e['lat']),
                    'lon': double.parse(e['lon']),
                  })
              .toList();
        }
      } catch (_) {}
      return [];
    }

    Future<String> _reverse(double lat, double lon) async {
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon');
        final res = await http.get(url);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          return data['display_name'] ?? '';
        }
      } catch (_) {}
      return '';
    }

    return await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMapState) => AlertDialog(
          title: const Text('اختر الموقع على الخريطة'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن مكان...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) async {
                          if (v.trim().length < 3) {
                            setMapState(() => searchResults = []);
                            return;
                          }
                          setMapState(() => isSearching = true);
                          final results = await _search(v.trim());
                          setMapState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        },
                      ),
                    ),
                    if (isSearching)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                if (searchResults.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final item = searchResults[index];
                        return ListTile(
                          title: Text(item['name'],
                              style: const TextStyle(fontSize: 12)),
                          onTap: () {
                            setMapState(() {
                              selectedLat = item['lat'];
                              selectedLng = item['lon'];
                              selectedAddress = item['name'];
                              searchResults = [];
                              searchController.text = item['name'];
                            });
                          },
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(selectedLat, selectedLng),
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                        setMapState(() {
                          selectedLat = point.latitude;
                          selectedLng = point.longitude;
                        });
                        _reverse(point.latitude, point.longitude)
                            .then((addr) {
                          if (addr.isNotEmpty) {
                            setMapState(
                                () => selectedAddress = addr);
                          }
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(selectedLat, selectedLng),
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin,
                                color: Colors.red, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (selectedAddress.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('الموقع: $selectedAddress',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx, {
                  'lat': selectedLat,
                  'lng': selectedLng,
                  'address': selectedAddress,
                });
              },
              child: const Text('تأكيد الموقع'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- إرسال تذكير مع خيار تخصيص الحد لكل بقالة ----------
  void _showNotificationAndThresholdDialog(
      SystemProvider sys, String posPhone, String posName) {
    _play('click');
    final colors = Theme.of(context).colorScheme;
    // قراءة القيمة المخصصة الحالية لهذه البقالة
    _db.collection('users').doc(posPhone).get().then((doc) {
      final relations =
          (doc.data() as Map<String, dynamic>)['agent_relations']
              as Map<String, dynamic>?;
      final myRel = relations?[sys.currentUserPhone] as Map<String, dynamic>?;
      final customThreshold =
          myRel?['warningThreshold'] as double? ?? _globalWarningThreshold;

      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('إعدادات $posName'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('حد الإنذار الخاص (ريال):'),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: customThreshold.toString()),
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null) {
                        // تحديث Firestore
                        _db.collection('users').doc(posPhone).update({
                          'agent_relations.${sys.currentUserPhone}.warningThreshold':
                              val,
                        });
                      }
                    },
                    decoration: const InputDecoration(
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: () {
                      _db.collection('notifications').add({
                        'targetPhones': [posPhone],
                        'title': 'تذكير بالسداد ⏰',
                        'body':
                            'الرجاء سداد المبلغ المستحق عليك إلى الوكيل ${sys.currentUserName}.',
                        'timestamp': FieldValue.serverTimestamp(),
                        'isRead': false,
                        'readBy': [],
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('تم إرسال تذكير للبقالة.',
                                textDirection: TextDirection.rtl)),
                      );
                      Navigator.pop(ctx);
                    },
                    icon: Icon(Icons.notifications_active,
                        color: colors.primary),
                    label: const Text('إرسال تذكير الآن'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إغلاق')),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ========== بناء الواجهة الرئيسية ==========
  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const CustomHeader(title: 'إدارة نقاط البيع الذكية'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل',
        currentBalance: sys.currentUserBalance,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Container(
              color: colors.primaryContainer,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(
                                () => _searchQuery = v.trim().toLowerCase()),
                            decoration: InputDecoration(
                              hintText: 'بحث برقم أو اسم البقالة...',
                              filled: true,
                              fillColor: colors.onPrimary,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.filter_list,
                                color: colors.onPrimaryContainer),
                            onSelected: (v) =>
                                setState(() => _selectedFilter = v),
                            itemBuilder: (c) => [
                              const PopupMenuItem(
                                  value: 'الكل', child: Text('الكل')),
                              const PopupMenuItem(
                                  value: 'نشط', child: Text('النشطة 🟢')),
                              const PopupMenuItem(
                                  value: 'مجمّد',
                                  child: Text('المجمدة 🔴')),
                              const PopupMenuItem(
                                  value: 'منخفض',
                                  child: Text('رصيد منخفض ⚠️')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    labelColor: colors.onPrimaryContainer,
                    unselectedLabelColor:
                        colors.onSurfaceVariant,
                    indicatorColor: colors.primary,
                    indicatorWeight: 4,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.store_mall_directory),
                          text: 'البقالات'),
                      Tab(
                          icon: Icon(Icons.warning_amber_rounded),
                          text: 'الديون والإنذارات'),
                      Tab(
                          icon: Icon(Icons.dashboard_outlined),
                          text: 'نظرة عامة'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActivePosTab(sys, colors),
                  _buildDebtTab(sys, colors),
                  _buildOverviewTab(sys, colors),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditPosModal(sys),
        backgroundColor: colors.primary,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: Text('إضافة بقالة',
            style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ---------- التبويب الأول: البقالات النشطة ----------
  Widget _buildActivePosTab(SystemProvider sys, ColorScheme colors) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('role', isEqualTo: 'pos')
          .where('pos_agents', arrayContains: sys.currentUserPhone)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorWidget('تعذر تحميل البقالات', colors);
        }
        var docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final sName = (data['storeName'] ?? '').toLowerCase();
          final oName = (data['name'] ?? '').toLowerCase();
          final phone = data['phone'] ?? '';
          final wallets = data['wallets'] as Map<String, dynamic>? ?? {};
          final posWalletBal =
              (wallets[sys.currentUserPhone] ?? 0.0).toDouble();
          final status = data['status'] ?? 'نشط';

          final matchesSearch = _searchQuery.isEmpty ||
              sName.contains(_searchQuery) ||
              oName.contains(_searchQuery) ||
              phone.contains(_searchQuery);

          bool matchesFilter = true;
          switch (_selectedFilter) {
            case 'منخفض':
              matchesFilter = posWalletBal < _globalWarningThreshold;
              break;
            case 'نشط':
              matchesFilter = status == 'نشط';
              break;
            case 'مجمّد':
              matchesFilter = status == 'مجمّد';
              break;
            default:
              matchesFilter = true;
          }
          return matchesSearch && matchesFilter;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد بقالات مطابقة.',
                style: TextStyle(color: colors.onSurfaceVariant)),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final pos = docs[i].data() as Map<String, dynamic>;
              final isFrozen = pos['status'] == 'مجمّد';
              final wallets =
                  pos['wallets'] as Map<String, dynamic>? ?? {};
              final posWalletBal =
                  (wallets[sys.currentUserPhone] ?? 0.0).toDouble();
              final relations =
                  pos['agent_relations'] as Map<String, dynamic>? ?? {};
              final myRel = relations[sys.currentUserPhone]
                  as Map<String, dynamic>? ?? {};
              final creditLimit =
                  (myRel['creditLimit'] ?? 0.0).toDouble();
              final commission = myRel['commission'] ?? '0%';
              final overLimit = posWalletBal < -creditLimit;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                        color: overLimit
                            ? colors.error
                            : (isFrozen
                                ? colors.errorContainer
                                : colors.outlineVariant),
                        width: overLimit ? 2 : 1)),
                color: overLimit ? colors.errorContainer.withOpacity(0.3) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: isFrozen
                                ? colors.errorContainer
                                : colors.primaryContainer,
                            radius: 25,
                            child: Icon(Icons.store,
                                color: isFrozen
                                    ? colors.onErrorContainer
                                    : colors.onPrimaryContainer),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(pos['storeName'] ?? '',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: isFrozen
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: colors.onSurface)),
                                Text(
                                    '📍 ${pos['location'] ?? 'بدون عنوان'}',
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'المالك: ${pos['name']} | رقم: ${pos['phone']}',
                                    style: TextStyle(
                                        color: colors.onSurfaceVariant,
                                        fontSize: 11)),
                                if (overLimit)
                                  Text(
                                      '⚠️ تجاوزت الحد الائتماني!',
                                      style: TextStyle(
                                          color: colors.error,
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.edit,
                                color: colors.primary),
                            onPressed: () => _showAddOrEditPosModal(sys,
                                existingPos: pos),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('رصيد المحفظة:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant)),
                                Text(
                                    '${NumberFormat('#,##0').format(posWalletBal)} ريال',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: (posWalletBal <
                                                _globalWarningThreshold)
                                            ? colors.error
                                            : colors.onSurface)),
                              ]),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                Text('الحد الائتماني:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant)),
                                Text(
                                    '${NumberFormat('#,##0').format(creditLimit)} ريال',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: colors.primary)),
                              ]),
                          Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text('العمولة:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant)),
                                Text(commission,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: colors.tertiary)),
                              ]),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isFrozen
                                  ? null
                                  : () => _showFeedWalletModal(
                                      sys,
                                      pos['phone'],
                                      pos['storeName'] ?? ''),
                              icon: const Icon(Icons.add_card,
                                  size: 16, color: Colors.white),
                              label: const Text('تغذية محفظتها',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showRepaymentModal(
                                  sys,
                                  pos['phone'],
                                  pos['storeName'] ?? '',
                                  -posWalletBal > 0
                                      ? -posWalletBal
                                      : 0),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.primary),
                              child: const Text('استلام دفعة',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _play('click');
                                _db
                                    .collection('users')
                                    .doc(pos['phone'])
                                    .update({
                                  'status':
                                      isFrozen ? 'نشط' : 'مجمّد'
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isFrozen
                                    ? colors.primary
                                    : colors.error,
                                side: BorderSide(
                                    color: isFrozen
                                        ? colors.primary
                                        : colors.error),
                              ),
                              child: Text(
                                  isFrozen ? 'تنشيط' : 'تجميد',
                                  style:
                                      const TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------- التبويب الثاني: الديون والإنذارات ----------
  Widget _buildDebtTab(SystemProvider sys, ColorScheme colors) {
    return Column(
      children: [
        // شريط إعدادات الإنذار
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: colors.primaryContainer,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حد الإنذار المبكر (عالمي):',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: colors.onPrimaryContainer)),
              TextButton.icon(
                onPressed: _showGlobalThresholdDialog,
                icon: Icon(Icons.settings, size: 16, color: colors.onPrimaryContainer),
                label: Text(
                    'المستوى: ${NumberFormat('#,##0').format(_globalWarningThreshold)} ريال',
                    style: TextStyle(color: colors.onPrimaryContainer)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('users')
                .where('role', isEqualTo: 'pos')
                .where('pos_agents', arrayContains: sys.currentUserPhone)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildErrorWidget('تعذر تحميل الديون', colors);
              }
              var docs = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final wallets =
                    data['wallets'] as Map<String, dynamic>? ?? {};
                final bal =
                    (wallets[sys.currentUserPhone] ?? 0.0).toDouble();
                return bal < 0; // مدينة فقط
              }).toList();

              // دالة صغيرة لقراءة رصيد المستند داخل هذا السياق
              double docBalance(doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final wallets = data['wallets'] as Map<String, dynamic>?;
                return wallets != null
                    ? (wallets[sys.currentUserPhone] ?? 0.0).toDouble()
                    : 0.0;
              }

              // فرز الديون حسب الأكبر (الأعلى ديناً أولاً)
              docs.sort((a, b) {
                final balA = docBalance(a);
                final balB = docBalance(b);
                return balB.compareTo(balA); // من الأعلى ديناً للأقل
              });

              // ========== الإشعارات التلقائية ==========
              // نتحقق من البقالات التي تجاوزت الحد ولم يتم إرسال تذكير حديث لها
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final wallets = data['wallets'] as Map<String, dynamic>?;
                final balance = wallets != null
                    ? (wallets[sys.currentUserPhone] ?? 0.0).toDouble()
                    : 0.0;
                final debtAmount = -balance;
                final relations =
                    data['agent_relations'] as Map<String, dynamic>? ?? {};
                final myRel =
                    relations[sys.currentUserPhone] as Map<String, dynamic>? ?? {};
                final customThreshold =
                    myRel['warningThreshold'] as double? ?? _globalWarningThreshold;
                final lastWarning =
                    myRel['lastWarningSent'] as Timestamp?;

                // إذا تجاوز الدين ولم يتم إرسال تذكير خلال آخر 24 ساعة
                if (debtAmount > customThreshold &&
                    (lastWarning == null ||
                        DateTime.now()
                            .difference(lastWarning.toDate())
                            .inHours >= 24)) {
                  // إرسال إشعار
                  _db.collection('notifications').add({
                    'targetPhones': [data['phone']],
                    'title': 'تذكير تلقائي بالسداد ⏰',
                    'body':
                        'لقد تجاوز دينك ($debtAmount ريال) حد الإنذار. يُرجى السداد.',
                    'timestamp': FieldValue.serverTimestamp(),
                    'isRead': false,
                    'readBy': [],
                  });
                  // تحديث حقل lastWarningSent
                  _db.collection('users').doc(data['phone']).update({
                    'agent_relations.${sys.currentUserPhone}.lastWarningSent':
                        FieldValue.serverTimestamp(),
                  });
                }
              }

              if (docs.isEmpty) {
                return Center(
                  child: Text('لا توجد ديون حالياً. 👏',
                      style: TextStyle(
                          color: colors.onSurfaceVariant)),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final pos =
                        docs[i].data() as Map<String, dynamic>;
                    final wallets =
                        pos['wallets'] as Map<String, dynamic>? ?? {};
                    final debtAmount =
                        -(wallets[sys.currentUserPhone] ?? 0.0)
                            .toDouble();
                    final relations =
                        pos['agent_relations']
                            as Map<String, dynamic>? ?? {};
                    final myRel = relations[sys.currentUserPhone]
                        as Map<String, dynamic>? ?? {};
                    final customThreshold =
                        myRel['warningThreshold'] as double? ??
                            _globalWarningThreshold;
                    // الإنذار إذا كان الدين > قيمة مخصصة (نقارن بالمبلغ الإيجابي)
                    final isWarning = debtAmount > customThreshold;

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isWarning
                              ? colors.error
                              : colors.tertiary,
                          width: 2,
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                      pos['storeName'] ?? '',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 15,
                                          color: colors
                                              .onSurface)),
                                ),
                                if (isWarning)
                                  Icon(Icons.warning_amber,
                                      color: colors.error),
                                Text(
                                  '${NumberFormat('#,##0').format(debtAmount)} ريال',
                                  style: TextStyle(
                                      color: colors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                                'الموقع: ${pos['location'] ?? ''}',
                                style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12)),
                            if (isWarning)
                              Text(
                                  '⚠️ تجاوز حد الإنذار المبكر',
                                  style: TextStyle(
                                      color: colors.error,
                                      fontSize: 11)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _showRepaymentModal(
                                            sys,
                                            pos['phone'],
                                            pos['storeName'] ??
                                                '',
                                            debtAmount),
                                    icon: const Icon(Icons.money,
                                        size: 16,
                                        color: Colors.white),
                                    label: Text('استلام دفعة',
                                        style: TextStyle(
                                            color: colors.onPrimary,
                                            fontSize: 12)),
                                    style:
                                        ElevatedButton.styleFrom(
                                            backgroundColor:
                                                colors.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                      Icons.notifications_active,
                                      color: colors.primary),
                                  tooltip:
                                      'إرسال تذكير وتحديد الإنذار',
                                  onPressed: () =>
                                      _showNotificationAndThresholdDialog(
                                          sys,
                                          pos['phone'],
                                          pos['storeName'] ?? ''),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------- التبويب الثالث: نظرة عامة ----------
  Widget _buildOverviewTab(SystemProvider sys, ColorScheme colors) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .where('role', isEqualTo: 'pos')
          .where('pos_agents', arrayContains: sys.currentUserPhone)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _buildErrorWidget('تعذر تحميل البيانات', colors);
        }
        final docs = snapshot.data!.docs;
        final List<Map<String, dynamic>> posList =
            docs.map((d) => d.data() as Map<String, dynamic>).toList();

        // حساب الإحصاءات
        int totalPos = posList.length;
        double totalBalance = 0;
        double totalDebt = 0;
        for (var pos in posList) {
          final wallets =
              pos['wallets'] as Map<String, dynamic>? ?? {};
          final bal =
              (wallets[sys.currentUserPhone] ?? 0.0).toDouble();
          totalBalance += bal > 0 ? bal : 0;
          totalDebt += bal < 0 ? -bal : 0;
        }
        double avgBalance = totalPos > 0 ? totalBalance / totalPos : 0;

        // دالة مساعدة لحساب الرصيد
        double balanceOf(Map<String, dynamic> pos) {
          final wallets = pos['wallets'] as Map<String, dynamic>?;
          return wallets != null
              ? (wallets[sys.currentUserPhone] ?? 0.0).toDouble()
              : 0.0;
        }

        // أفضل البقالات (أعلى رصيد) وأكثرها ديناً
        final sortedByBalance = List<Map<String, dynamic>>.from(posList)
          ..sort((a, b) {
            return balanceOf(b).compareTo(balanceOf(a));
          });
        final sortedByDebt = List<Map<String, dynamic>>.from(posList)
          ..sort((a, b) {
            return balanceOf(a).compareTo(balanceOf(b));
          });

        final topBalance = sortedByBalance.take(3).toList();
        final topDebt = sortedByDebt
            .where((p) => balanceOf(p) < 0)
            .take(3)
            .toList();

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقات الإحصاءات
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(colors,
                          title: 'عدد البقالات',
                          value: totalPos.toString(),
                          icon: Icons.store,
                          color: colors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(colors,
                          title: 'إجمالي الأرصدة',
                          value:
                              '${NumberFormat('#,##0').format(totalBalance)} ريال',
                          icon: Icons.account_balance_wallet,
                          color: Colors.green),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(colors,
                          title: 'إجمالي الديون',
                          value:
                              '${NumberFormat('#,##0').format(totalDebt)} ريال',
                          icon: Icons.warning_amber,
                          color: colors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(colors,
                          title: 'متوسط الرصيد',
                          value:
                              '${NumberFormat('#,##0').format(avgBalance)} ريال',
                          icon: Icons.analytics,
                          color: colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (topBalance.isNotEmpty) ...[
                  Text('أفضل 3 بقالات رصيداً',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface)),
                  const SizedBox(height: 8),
                  ...topBalance.map((pos) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(Icons.store,
                              color: colors.primary),
                          title: Text(pos['storeName'] ?? '',
                              style: TextStyle(
                                  color: colors.onSurface)),
                          trailing: Text(
                              '${NumberFormat('#,##0').format(balanceOf(pos))} ريال',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ),
                      )),
                ],
                if (topDebt.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('أكثر البقالات ديوناً',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface)),
                  const SizedBox(height: 8),
                  ...topDebt.map((pos) {
                    final debt = -balanceOf(pos);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.store, color: colors.error),
                        title: Text(pos['storeName'] ?? '',
                            style: TextStyle(
                                color: colors.onSurface)),
                        trailing: Text(
                            '${NumberFormat('#,##0').format(debt)} ريال',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colors.error)),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(ColorScheme colors,
      {required String title,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message, ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: colors.error),
          const SizedBox(height: 10),
          Text(message,
              style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
