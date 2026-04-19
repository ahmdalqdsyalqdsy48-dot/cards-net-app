import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للـ TextInputFormatter
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart'; // للمشاركة العامة
import 'package:url_launcher/url_launcher.dart'; // للواتساب
import 'package:pdf/pdf.dart'; // للطباعة
import 'package:pdf/widgets.dart' as pw; // للطباعة
import 'package:printing/printing.dart'; // للطباعة

import '../../../core/providers/system_provider.dart';
import '../../../core/providers/ui_provider.dart';
import '../../../core/widgets/custom_header.dart';
import '../widgets/custom_agent_drawer.dart';

class QuickPosScreen extends StatefulWidget {
  const QuickPosScreen({super.key});

  @override
  State<QuickPosScreen> createState() => _QuickPosScreenState();
}

class _QuickPosScreenState extends State<QuickPosScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  Map<String, dynamic>? _selectedCategory;
  int _quantity = 1;
  bool _isProcessing = false; 
  bool _isBalanceHidden = true; // للتحكم في إخفاء/إظهار الرصيد

  // متحكم لكتابة الكمية يدوياً
  final TextEditingController _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    // مراقبة التغييرات في حقل إدخال الكمية لتحديث الإجمالي
    _quantityController.addListener(() {
      if (_quantityController.text.isNotEmpty) {
        int parsed = int.tryParse(_quantityController.text) ?? 1;
        if (parsed > 0) {
          // لن نسمح له بتجاوز المخزون إذا كان قد اختار فئة
          if (_selectedCategory != null && parsed > (_selectedCategory!['stock'] ?? 0)) {
            setState(() {
              _quantity = _selectedCategory!['stock'] ?? 0;
              _quantityController.text = _quantity.toString();
            });
            // وضع المؤشر في نهاية النص
            _quantityController.selection = TextSelection.fromPosition(TextPosition(offset: _quantityController.text.length));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لقد وصلت للحد الأقصى من المخزون.', textDirection: TextDirection.rtl)));
          } else {
             setState(() { _quantity = parsed; });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _play(String type) => Provider.of<UiProvider>(context, listen: false).playSound(type);

  // ==========================================
  // محرك التحقق من الساعات السعيدة (Happy Hour) ⏳
  // ==========================================
  bool _isWithinHappyHour(String startStr, String endStr) {
    try {
      var now = TimeOfDay.now();
      double nowDouble = now.hour + now.minute / 60.0;

      var startParts = startStr.split(':');
      double startDouble = int.parse(startParts[0]) + int.parse(startParts[1]) / 60.0;

      var endParts = endStr.split(':');
      double endDouble = int.parse(endParts[0]) + int.parse(endParts[1]) / 60.0;

      if (startDouble < endDouble) {
        return nowDouble >= startDouble && nowDouble <= endDouble;
      } else {
        return nowDouble >= startDouble || nowDouble <= endDouble; // يعبر منتصف الليل
      }
    } catch(e) { return false; }
  }

  // ==========================================
  // 1. نافذة تأكيد البيع (المطورة بدمج الكوبونات 🎟️)
  // ==========================================
  void _showConfirmSaleDialog(double currentBalance, SystemProvider sys) {
    if (_selectedCategory == null) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار فئة أولاً!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
      return;
    }

    int stockAvailable = _selectedCategory!['stock'] ?? 0;
    if (_quantity > stockAvailable || _quantity < 1) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('الكمية المطلوبة غير صحيحة أو أكبر من المخزون ($stockAvailable)!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
      return;
    }

    double originalTotalPrice = (_selectedCategory!['price'] * _quantity).toDouble();

    if (currentBalance < originalTotalPrice) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عفواً، رصيد المحفظة لا يكفي لإتمام العملية!', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
      return;
    }

    _play('warning');
    
    // متغيرات نظام الكوبونات
    double finalPrice = originalTotalPrice;
    double discountAmount = 0.0;
    String? appliedCouponDocId;
    String couponMessage = '';
    Color couponMessageColor = Colors.black;
    bool isApplyingCoupon = false;
    TextEditingController couponController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            // 🎟️ دالة تطبيق الكوبون الداخلية
            Future<void> _applyCoupon() async {
              String code = couponController.text.trim().toUpperCase();
              if (code.isEmpty) return;

              _play('click');
              setStateDialog(() { isApplyingCoupon = true; couponMessage = ''; });

              try {
                var query = await _db.collection('coupons')
                    .where('agentPhone', isEqualTo: sys.currentUserPhone)
                    .where('code', isEqualTo: code)
                    .get();

                if (query.docs.isEmpty) {
                  setStateDialog(() { couponMessage = 'كود الخصم غير صحيح أو لا يتبع لك'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                var doc = query.docs.first;
                var data = doc.data();

                // التحققات الصارمة
                if (data['isActive'] != true) {
                  setStateDialog(() { couponMessage = 'هذا الكود متوقف حالياً'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
                if (expiry.isBefore(DateTime.now())) {
                  setStateDialog(() { couponMessage = 'لقد انتهت صلاحية هذا العرض'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                int currentUsage = data['currentUsage'] ?? 0;
                int maxUsage = data['maxUsage'] ?? 1;
                if (currentUsage >= maxUsage) {
                  setStateDialog(() { couponMessage = 'تم استنفاد الحد الأقصى لاستخدام الكوبون'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                String targetNetwork = data['targetNetwork'] ?? '';
                if (targetNetwork.isNotEmpty && targetNetwork != 'الكل' && targetNetwork != _selectedCategory!['networkName']) {
                  setStateDialog(() { couponMessage = 'هذا الكود مخصص لشبكة ($targetNetwork) فقط'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                  _play('error'); return;
                }

                if (data['isHappyHour'] == true) {
                  String sTime = data['startTime'] ?? '00:00';
                  String eTime = data['endTime'] ?? '23:59';
                  if (!_isWithinHappyHour(sTime, eTime)) {
                    setStateDialog(() { couponMessage = 'هذا الكود يعمل فقط من $sTime إلى $eTime'; couponMessageColor = Colors.orange; isApplyingCoupon = false; });
                    _play('error'); return;
                  }
                }

                // حساب قيمة الخصم
                double dValue = (data['discountValue'] ?? 0).toDouble();
                String dType = data['discountType'] ?? 'fixed';

                double calculatedDiscount = 0.0;
                if (dType == 'percent') {
                  calculatedDiscount = originalTotalPrice * (dValue / 100);
                } else if (dType == 'fixed') {
                  calculatedDiscount = dValue; // الخصم الثابت يطبق على إجمالي الفاتورة
                } else if (dType == 'combo' || dType == 'referral') {
                  setStateDialog(() { couponMessage = 'عروض الباقات والدعوات لا تخصم من القيمة النقدية للفاتورة'; couponMessageColor = Colors.orange; isApplyingCoupon = false; });
                  return;
                }

                if (calculatedDiscount >= originalTotalPrice) calculatedDiscount = originalTotalPrice;

                _play('success');
                setStateDialog(() {
                  discountAmount = calculatedDiscount;
                  finalPrice = originalTotalPrice - discountAmount;
                  appliedCouponDocId = doc.id;
                  couponMessage = 'تم تطبيق الخصم بنجاح! 🎉';
                  couponMessageColor = Colors.green;
                  isApplyingCoupon = false;
                });

              } catch (e) {
                setStateDialog(() { couponMessage = 'حدث خطأ في الاتصال'; couponMessageColor = Colors.red; isApplyingCoupon = false; });
                _play('error');
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                title: const Text('تأكيد البيع 🛒', style: TextStyle(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بيع عدد ($_quantity) كرت من (${_selectedCategory!['name']}) التابعة لـ (${_selectedCategory!['networkName']}).', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 20),
                      
                      // 🎟️ حقل الكوبون
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: appliedCouponDocId != null ? Colors.green : Colors.grey.shade300)
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: couponController,
                                enabled: appliedCouponDocId == null && !isApplyingCoupon,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'إضافة كود خصم للزبون...',
                                  hintStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
                                  border: InputBorder.none,
                                  icon: Icon(Icons.local_offer, color: appliedCouponDocId != null ? Colors.green : Colors.grey, size: 20),
                                ),
                              ),
                            ),
                            if (appliedCouponDocId == null)
                              isApplyingCoupon
                                  ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : TextButton(
                                      onPressed: _applyCoupon,
                                      child: const Text('تطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                                    )
                            else
                              const Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                      ),
                      if (couponMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0, bottom: 10.0),
                          child: Text(couponMessage, style: TextStyle(color: couponMessageColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        
                      const Divider(height: 25),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي قبل الخصم:', style: TextStyle(fontSize: 12)),
                          Text('$originalTotalPrice ريال', style: TextStyle(fontSize: 13, color: discountAmount > 0 ? Colors.grey : Colors.black, decoration: discountAmount > 0 ? TextDecoration.lineThrough : null)),
                        ],
                      ),
                      if (discountAmount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('قيمة الخصم الممنوح:', style: TextStyle(fontSize: 12, color: Colors.green)),
                              Text('- $discountAmount ريال', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الصافي للخصم من المحفظة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('$finalPrice ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () { _play('click'); Navigator.pop(context); }, child: const Text('إلغاء', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.pop(context); 
                      _processSale(finalPrice, appliedCouponDocId); // 👈 إرسال السعر النهائي ومعرف الكوبون للتنفيذ
                    },
                    child: const Text('تأكيد وبيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // ==========================================
  // 2. معالجة البيع الحقيقي (المطورة)
  // ==========================================
  Future<void> _processSale(double finalPrice, String? appliedCouponDocId) async {
    setState(() => _isProcessing = true);
    _play('click');
    
    final sys = Provider.of<SystemProvider>(context, listen: false);
    String netId = _selectedCategory!['networkId'];
    String catId = _selectedCategory!['id'];

    try {
      QuerySnapshot availableCards = await _db.collection('cards')
          .where('categoryId', isEqualTo: catId)
          .where('networkId', isEqualTo: netId)
          .where('status', isEqualTo: 'متاح')
          .limit(_quantity)
          .get();

      if (availableCards.docs.length < _quantity) {
        throw 'حدث خطأ! عدد الكروت المتاحة فعلياً أقل من المطلوب. يرجى المراجعة.';
      }

      WriteBatch batch = _db.batch();
      List<String> generatedPins = [];

      for (var doc in availableCards.docs) {
        generatedPins.add(doc['pin']);
        batch.update(doc.reference, {
          'status': 'مباع',
          'soldAt': FieldValue.serverTimestamp(),
          'soldByPhone': sys.currentUserPhone, 
        });
      }

      DocumentReference netRef = _db.collection('networks').doc(netId);
      DocumentSnapshot netDoc = await netRef.get();
      List cats = List.from((netDoc.data() as Map)['categories']);
      int catIndex = cats.indexWhere((c) => c['id'] == catId);
      cats[catIndex]['stock'] -= _quantity; 
      batch.update(netRef, {'categories': cats});

      QuerySnapshot userSnap = await _db.collection('users').where('phone', isEqualTo: sys.currentUserPhone).limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        batch.update(userSnap.docs.first.reference, {
          'balance': FieldValue.increment(-finalPrice) // خصم السعر المخفض
        });
      }

      DocumentReference transRef = _db.collection('transactions').doc();
      batch.set(transRef, {
        'agentPhone': sys.currentUserPhone,
        'amount': finalPrice, // تسجيل السعر الفعلي المدفوع
        'type': 'sale', 
        'quantity': _quantity,
        'categoryName': _selectedCategory!['name'],
        'networkName': _selectedCategory!['networkName'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🎟️ تحديث عداد الكوبون إن وُجد
      if (appliedCouponDocId != null) {
        batch.update(_db.collection('coupons').doc(appliedCouponDocId), {
          'currentUsage': FieldValue.increment(1)
        });
      }

      await batch.commit();

      _play('success');
      _showSuccessReceipt(generatedPins); 

    } catch (e) {
      _play('error');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), textDirection: TextDirection.rtl), backgroundColor: Colors.red));
    }

    setState(() => _isProcessing = false);
  }

  // ==========================================
  // وظائف المشاركة والطباعة
  // ==========================================

  // مشاركة عبر واتساب
  Future<void> _shareViaWhatsApp(List<String> pins) async {
    String text = "🛒 *${_selectedCategory!['networkName']}*\n";
    text += "🎟️ الفئة: ${_selectedCategory!['name']} (${_selectedCategory!['time']})\n";
    text += "-------------------\n";
    for(int i=0; i<pins.length; i++) {
      text += "🔑 رقم الكرت: *${pins[i]}*\n";
    }
    
    // محاولة فتح واتساب، وإذا فشل نفتح المشاركة العامة
    final whatsappUrl = Uri.parse("whatsapp://send?text=${Uri.encodeComponent(text)}");
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl);
    } else {
      _shareGeneral(pins); // بديل لو واتساب غير مثبت
    }
  }

  // مشاركة عامة (تليجرام، رسائل، إلخ)
  void _shareGeneral(List<String> pins) {
    String text = "🛒 *${_selectedCategory!['networkName']}*\n";
    text += "🎟️ الفئة: ${_selectedCategory!['name']} (${_selectedCategory!['time']})\n";
    text += "-------------------\n";
    for(int i=0; i<pins.length; i++) {
      text += "🔑 الكرت: ${pins[i]}\n";
    }
    Share.share(text);
  }

  // طباعة (بلوتوث + PDF)
  Future<void> _printCards(List<String> pins) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // مقاس طابعة حرارية 80mm
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(_selectedCategory!['networkName'], style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text(_selectedCategory!['name']),
              pw.Text("Time: ${_selectedCategory!['time']}"),
              pw.Divider(),
              ...pins.map((pin) => pw.Column(
                children: [
                  pw.Text("PIN", style: const pw.TextStyle(fontSize: 12)),
                  pw.Text(pin, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                ]
              )),
              pw.SizedBox(height: 10),
              pw.Text("Thank You!"),
            ],
          );
        },
      ),
    );

    // تفتح واجهة الطباعة (تعمل مع طابعات البلوتوث المربوطة بالجهاز وطابعات الشبكة)
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ==========================================
  // 3. عرض فاتورة الكروت (الإيصال الذكي) بعد البيع
  // ==========================================
  void _showSuccessReceipt(List<String> generatedPins) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 50),
                  const SizedBox(height: 10),
                  const Text('تمت عملية البيع بنجاح!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                  Text('تم إصدار ($_quantity) كرت', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 15),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: generatedPins.length,
                        itemBuilder: (context, index) {
                          Color catColor = Color(_selectedCategory!['color']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: catColor.withOpacity(0.3), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_selectedCategory!['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: catColor)),
                                    // زر المشاركة الفردي
                                    IconButton(
                                      icon: const Icon(Icons.share, size: 18, color: Colors.blue),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _shareGeneral([generatedPins[index]]),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Text(generatedPins[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2)),
                                const SizedBox(height: 5),
                                Text('الوقت: ${_selectedCategory!['time']}', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(Icons.message, 'واتساب', Colors.green, () { 
                        _play('click');
                        _shareViaWhatsApp(generatedPins);
                      }),
                      _buildActionButton(Icons.share, 'مشاركة', Colors.blue, () { 
                        _play('click');
                        _shareGeneral(generatedPins);
                      }),
                      _buildActionButton(Icons.print, 'طباعة', Colors.orange, () { 
                        _play('click');
                        _printCards(generatedPins);
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      _play('click');
                      Navigator.pop(context);
                      setState(() { 
                        _selectedCategory = null; 
                        _quantity = 1; 
                        _quantityController.text = '1';
                      });
                    },
                    child: const Text('إغلاق وبدء بيع جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sys = Provider.of<SystemProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const CustomHeader(title: 'المتجر السريع (الكاشير)'),
      drawer: CustomAgentDrawer(
        agentName: sys.currentUserName,
        phoneNumber: sys.currentUserPhone,
        role: 'وكيل معتمد (Agent)',
        currentBalance: sys.currentUserBalance, 
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            // الشريط الأخضر (الرصيد مع ميزة الإخفاء)
            InkWell(
              onTap: () {
                _play('click');
                setState(() => _isBalanceHidden = !_isBalanceHidden);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.teal.shade700,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        const Text('رصيد المحفظة المتاح', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _isBalanceHidden ? '****** ريال' : '${sys.currentUserBalance.toStringAsFixed(0)} ريال', 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ),

            if (_isProcessing) const LinearProgressIndicator(color: Colors.teal),
            const SizedBox(height: 15),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اختر الفئة المطلوبة من المخزون:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey)),
                    const SizedBox(height: 15),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('networks')
                            .where('agentPhone', isEqualTo: sys.currentUserPhone)
                            .where('isActive', isEqualTo: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                          
                          List<Map<String, dynamic>> dynamicCategories = [];
                          if (snapshot.hasData) {
                            for (var netDoc in snapshot.data!.docs) {
                              var netData = netDoc.data() as Map<String, dynamic>;
                              List cats = netData['categories'] ?? [];
                              for (var cat in cats) {
                                if ((cat['isActive'] ?? true) == true && (cat['stock'] ?? 0) > 0) {
                                  dynamicCategories.add({
                                    ...cat,
                                    'networkId': netDoc.id,
                                    'networkName': netData['name'],
                                  });
                                }
                              }
                            }
                          }

                          if (dynamicCategories.isEmpty) {
                            return const Center(child: Text('لا يوجد مخزون كروت متاح حالياً. قم بتوليد كروت من قسم إدارة الميكروتك أولاً.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                          }

                          return GridView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
                            ),
                            itemCount: dynamicCategories.length,
                            itemBuilder: (context, index) {
                              final category = dynamicCategories[index];
                              final isSelected = _selectedCategory != null && _selectedCategory!['id'] == category['id'] && _selectedCategory!['networkId'] == category['networkId'];
                              Color catColor = Color(category['color']);
                              
                              return InkWell(
                                onTap: _isProcessing ? null : () { 
                                  _play('click'); 
                                  setState(() { 
                                    _selectedCategory = category; 
                                    _quantity = 1; 
                                    _quantityController.text = '1'; 
                                  }); 
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected ? catColor : (isDark ? Colors.grey.shade800 : Colors.white),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: isSelected ? catColor : Colors.grey.shade300, width: isSelected ? 3 : 1),
                                    boxShadow: [if (isSelected) BoxShadow(color: catColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.wifi, size: 28, color: isSelected ? Colors.white : catColor),
                                      const SizedBox(height: 5),
                                      Text(category['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                                      const SizedBox(height: 2),
                                      Text('${category['price']} ريال', style: TextStyle(fontSize: 13, color: isSelected ? Colors.white70 : Colors.grey)),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: isSelected ? Colors.white24 : Colors.orange.shade100, borderRadius: BorderRadius.circular(5)),
                                        child: Text('المتوفر: ${category['stock']}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.orange.shade800)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_selectedCategory != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الكمية المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          width: 140, 
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.red, size: 20), 
                                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                onPressed: _isProcessing ? null : () { 
                                  if (_quantity > 1) { 
                                    _play('click'); 
                                    setState(() { _quantity--; _quantityController.text = _quantity.toString(); }); 
                                  } 
                                }
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: Colors.green, size: 20), 
                                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                                onPressed: _isProcessing ? null : () { 
                                  if (_quantity < _selectedCategory!['stock']) {
                                    _play('click'); 
                                    setState(() { _quantity++; _quantityController.text = _quantity.toString(); }); 
                                  } else {
                                    _play('error');
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لقد وصلت للحد الأقصى من المخزون.', textDirection: TextDirection.rtl)));
                                  }
                                }
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الإجمالي المطلوب:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                              Text('${_selectedCategory!['price'] * _quantity} ريال', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing ? null : () => _showConfirmSaleDialog(sys.currentUserBalance, sys),
                              icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 24),
                              label: const Text('دفع وإصدار الكروت', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
