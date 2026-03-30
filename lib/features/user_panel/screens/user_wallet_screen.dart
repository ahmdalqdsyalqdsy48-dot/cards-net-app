import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 👈 1. استدعاء مكتبة العقل المدبر

import '../../../core/providers/system_provider.dart'; // 👈 2. استدعاء الخادم المحلي الشامل
import '../../../core/widgets/custom_header.dart'; 
import '../widgets/custom_user_drawer.dart'; 

class UserWalletScreen extends StatefulWidget {
  const UserWalletScreen({super.key});

  @override
  State<UserWalletScreen> createState() => _UserWalletScreenState();
}

class _UserWalletScreenState extends State<UserWalletScreen> {
  // متغيرات تبويب "شحن الرصيد"
  String _selectedBank = 'بنك الكريمي';
  final TextEditingController _rechargeAmountController = TextEditingController();
  final TextEditingController _rechargeRefController = TextEditingController();

  // متغيرات تبويب "التحويل لصديق"
  final TextEditingController _transferPhoneController = TextEditingController();
  final TextEditingController _transferAmountController = TextEditingController();
  String _validatedFriendName = ''; // لحفظ اسم الصديق بعد التحقق من رقمه

  // ==========================================
  // دالة للتحقق من رقم هاتف الصديق قبل التحويل
  // ==========================================
  void _validatePhoneNumber(String phone) {
    if (phone.length >= 9) {
      setState(() {
        // محاكاة للبحث في قاعدة البيانات وإرجاع اسم المستلم
        _validatedFriendName = 'محم*** أحم*** (مستخدم موثوق ✅)';
      });
    } else {
      setState(() {
        _validatedFriendName = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 👇 3. الاتصال بالعقل المدبر لقراءة الرصيد الحقيقي للزبون
    final systemProvider = Provider.of<SystemProvider>(context);
    final double realBalance = systemProvider.currentUserBalance;

    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const CustomHeader(title: 'المحفظة الذكية'),
        
        // 👇 4. تم تنظيف القائمة الجانبية لتجنب الأخطاء
        drawer: const CustomUserDrawer(
          userName: 'محمد أحمد',
          phoneNumber: '777123456',
        ),
        
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              // ==========================================
              // 1. شريط التبويبات العلوي (TabBar)
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.teal.shade700,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  indicatorColor: Colors.orange,
                  indicatorWeight: 4,
                  tabs: [
                    Tab(icon: Icon(Icons.account_balance_wallet), text: 'شحن الرصيد'),
                    Tab(icon: Icon(Icons.send_to_mobile), text: 'تحويل لصديق'),
                    Tab(icon: Icon(Icons.qr_code_2), text: 'QR كود'),
                  ],
                ),
              ),

              // ==========================================
              // 2. محتوى التبويبات (TabBarView)
              // ==========================================
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRechargeTab(),
                    _buildTransferTab(realBalance), // تمرير الرصيد الحقيقي لتبويب التحويل
                    _buildQRTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // تبويب 1: طلب شحن الرصيد (رفع حوالة)
  // ==========================================
  Widget _buildRechargeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💳 اطلب شحن محفظتك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('قم بإيداع المبلغ في حساباتنا أولاً، ثم املأ هذا النموذج لرفع الطلب للإدارة.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _selectedBank,
            decoration: InputDecoration(labelText: 'البنك / المحفظة المُحوَّل إليها', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.account_balance, color: Colors.teal)),
            items: ['بنك الكريمي', 'محفظة جوالي', 'موبايل موني'].map((bank) => DropdownMenuItem(value: bank, child: Text(bank))).toList(),
            onChanged: (val) => setState(() => _selectedBank = val!),
          ),
          const SizedBox(height: 15),
          
          TextField(
            controller: _rechargeAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'المبلغ المحول (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.attach_money, color: Colors.teal)),
          ),
          const SizedBox(height: 15),
          
          TextField(
            controller: _rechargeRefController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'رقم السند / رقم الحوالة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.receipt, color: Colors.teal)),
          ),
          const SizedBox(height: 15),

          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم فتح معرض الصور قريباً 📸', textDirection: TextDirection.rtl)));
            },
            icon: const Icon(Icons.image, color: Colors.teal),
            label: const Text('إرفاق صورة السند (اختياري)', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(color: Colors.teal.shade300, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                if (_rechargeAmountController.text.isNotEmpty && _rechargeRefController.text.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفع طلب الشحن للإدارة بنجاح! سيتم إيداع الرصيد قريباً ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                  _rechargeAmountController.clear();
                  _rechargeRefController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة المبلغ ورقم الحوالة! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
              },
              child: const Text('تأكيد وإرسال الطلب', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // تبويب 2: التحويل لصديق (مع التحقق من الرصيد الحي)
  // ==========================================
  Widget _buildTransferTab(double currentBalance) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عرض الرصيد الحقيقي للمستخدم
          Text('رصيدك المتاح: ${currentBalance.toStringAsFixed(0)} ريال', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
          const SizedBox(height: 20),
          const Text('💸 تحويل رصيد لمستخدم آخر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          TextField(
            controller: _transferPhoneController,
            keyboardType: TextInputType.phone,
            onChanged: _validatePhoneNumber, 
            decoration: InputDecoration(
              labelText: 'رقم هاتف المستلم', 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), 
              prefixIcon: const Icon(Icons.phone_android, color: Colors.orange)
            ),
          ),
          
          if (_validatedFriendName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 10),
              child: Text('سيتم التحويل إلى: $_validatedFriendName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
            ),

          const SizedBox(height: 15),
          
          TextField(
            controller: _transferAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'المبلغ المراد تحويله (ريال)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), prefixIcon: const Icon(Icons.money_off, color: Colors.orange)),
          ),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                double amount = double.tryParse(_transferAmountController.text) ?? 0;
                
                // 1. التحقق من المدخلات: هاتف صحيح + مبلغ صحيح + رصيد كافٍ
                if (_transferPhoneController.text.length >= 9 && amount > 0 && amount <= currentBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحويل $amount ريال بنجاح! ✅', textDirection: TextDirection.rtl), backgroundColor: Colors.green));
                  
                  // ملاحظة: هنا يجب أن نستدعي الخادم المحلي لخصم المبلغ فعلياً (مثلما فعلنا في صفحة الشراء)، ولكن لمحاكاة التحويل نكتفي بمسح الحقول
                  _transferAmountController.clear();
                  _transferPhoneController.clear();
                  setState(() => _validatedFriendName = '');
                  
                } 
                // 2. إذا كان الرصيد غير كافٍ
                else if (amount > currentBalance) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رصيدك الحالي لا يكفي لإتمام هذه الحوالة! 🚫', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
                // 3. أخطاء أخرى (رقم هاتف قصير أو مبلغ فارغ)
                else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى التأكد من كتابة الرقم والمبلغ بشكل صحيح! ❌', textDirection: TextDirection.rtl), backgroundColor: Colors.red));
                }
              },
              child: const Text('تحويل الآن', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // تبويب 3: الدفع والاستلام عبر QR Code
  // ==========================================
  Widget _buildQRTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('استلم أو ادفع في البقالة بثوانٍ ⚡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('اجعل صاحب البقالة يمسح هذا الكود لتحويل الرصيد إليك', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                border: Border.all(color: Colors.blue.shade100, width: 3),
              ),
              child: Icon(Icons.qr_code_2, size: 200, color: Colors.blue.shade900),
            ),
            
            const SizedBox(height: 30),
            
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم تشغيل كاميرا الهاتف لمسح الـ QR 📷', textDirection: TextDirection.rtl)));
              },
              icon: const Icon(Icons.camera_alt, color: Colors.purple),
              label: const Text('مسح كود بقالة (للدفع)', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                side: BorderSide(color: Colors.purple.shade300, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
