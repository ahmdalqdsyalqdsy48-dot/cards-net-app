const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const cron = require('node-cron');
const { RouterOSAPI } = require('node-routeros');
const admin = require('firebase-admin');

// ---------- تهيئة Firebase Admin (يستخدم اعتماديات البيئة بدون ملف) ----------
admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage().bucket('netcardsapp.appspot.com');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '10mb' }));

// ---------- مفتاح التوقيع (متغير بيئة أو افتراضي) ----------
const SECRET = process.env.SECRET_KEY || 'netcards_secret_change_me';

// ---------- دوال المصادقة (JWT بسيط) ----------
function generateToken(phone, role) {
  const payload = `${phone}:${role}:${Date.now()}`;
  const signature = crypto.createHmac('sha256', SECRET).update(payload).digest('hex');
  return `${Buffer.from(payload).toString('base64')}.${signature}`;
}

function verifyToken(token) {
  try {
    const [payload, signature] = token.split('.');
    const expectedSig = crypto.createHmac('sha256', SECRET)
        .update(Buffer.from(payload, 'base64').toString())
        .digest('hex');
    if (signature !== expectedSig) return null;
    const decoded = Buffer.from(payload, 'base64').toString();
    const [phone, role] = decoded.split(':');
    return { phone, role };
  } catch (e) { return null; }
}

async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'مصادقة مطلوبة' });
  }
  const token = authHeader.slice(7);
  const user = verifyToken(token);
  if (!user) return res.status(401).json({ error: 'رمز غير صالح' });
  const userDoc = await db.collection('users').doc(user.phone).get();
  if (!userDoc.exists) return res.status(401).json({ error: 'مستخدم غير موجود' });
  req.user = { phone: user.phone, role: userDoc.data().role };
  next();
}

// ==================== واجهات API ====================

app.get('/', (req, res) => res.send('NetCards Server Running'));

// تسجيل الدخول
app.post('/api/login', async (req, res) => {
  const { phone, password } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'البيانات ناقصة' });
  try {
    // المشرف العام (حساب ثابت)
    if (phone === '774578241' && password === '75486958aaa') {
      const token = generateToken(phone, 'super_admin');
      return res.json({ token, user: { phone, name: 'مالك النظام', role: 'super_admin', balance: 0, networkName: 'المركز الرئيسي', pin: '123456', permissions: {} } });
    }
    const userDoc = await db.collection('users').doc(phone).get();
    if (!userDoc.exists) return res.status(401).json({ error: 'المستخدم غير موجود' });
    const userData = userDoc.data();
    if (userData.password !== password) return res.status(401).json({ error: 'كلمة المرور خاطئة' });
    const token = generateToken(phone, userData.role);
    res.json({ token, user: { phone, name: userData.name, role: userData.role, balance: userData.balance || 0, networkName: userData.networkName, pin: userData.pin, permissions: userData.permissions || {} } });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تسجيل مستخدم جديد
app.post('/api/register', async (req, res) => {
  const { name, phone, password, role } = req.body;
  if (!name || !phone || !password || !role) return res.status(400).json({ error: 'البيانات ناقصة' });
  try {
    const existing = await db.collection('users').doc(phone).get();
    if (existing.exists) return res.status(400).json({ error: 'الرقم مسجل مسبقاً' });
    await db.collection('users').doc(phone).set({
      id: 'USER_' + Date.now(), name, phone, password, role,
      balance: 0, wallets: {}, networkName: 'غير محدد', dangerLimit: 0,
      status: 'نشط', purchasedCards: [], pin: '123456', isBiometricEnabled: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      hiddenSections: [], privacy_showPhone: true
    });
    res.json({ success: true, message: 'تم إنشاء الحساب' });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// شراء كرت
app.post('/api/purchase', authenticate, async (req, res) => {
  const { agentPhone, categoryId, cardTitle, price } = req.body;
  const buyerPhone = req.user.phone;
  if (!agentPhone || !categoryId || !price) return res.status(400).json({ error: 'بيانات ناقصة' });
  try {
    const cardsSnap = await db.collection('cards')
        .where('agentPhone', '==', agentPhone)
        .where('categoryId', '==', categoryId)
        .where('status', '==', 'متاح')
        .limit(1).get();
    if (cardsSnap.empty) return res.status(400).json({ error: 'لا توجد كروت متاحة' });
    const cardDoc = cardsSnap.docs[0];
    const cardData = cardDoc.data();

    await db.runTransaction(async (t) => {
      const buyerRef = db.collection('users').doc(buyerPhone);
      const buyerDoc = await t.get(buyerRef);
      const buyerData = buyerDoc.data();
      const wallets = buyerData.wallets || {};
      const currentBalance = wallets[agentPhone] || 0;
      if (currentBalance < price) throw new Error('الرصيد غير كافٍ');
      wallets[agentPhone] = currentBalance - price;
      t.update(buyerRef, { wallets });
      t.update(cardDoc.ref, { status: 'مباع', buyerPhone, soldAt: admin.firestore.FieldValue.serverTimestamp() });
      const invoice = { title: cardTitle, pin: cardData.pin, price, agentPhone, date: new Date().toISOString() };
      t.update(buyerRef, { purchasedCards: admin.firestore.FieldValue.arrayUnion(invoice) });
      t.update(db.collection('system').doc('main_info'), { totalSystemCards: admin.firestore.FieldValue.increment(-1) });
      t.set(db.collection('transactions').doc(), {
        fromPhone: buyerPhone, toPhone: agentPhone, agentPhone, agentName: req.user.phone,
        targetName: buyerData.name, networkName: buyerData.networkName, amount: price,
        fee: 0, paymentMethod: 'محفظة', type: 'sale', title: `بيع ${cardTitle}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    res.json({ success: true, pin: cardData.pin });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تحويل رصيد بين مستخدمين
app.post('/api/transfer', authenticate, async (req, res) => {
  const { targetPhone, amount } = req.body;
  const senderPhone = req.user.phone;
  if (!targetPhone || !amount || amount <= 0) return res.status(400).json({ error: 'بيانات ناقصة' });
  try {
    await db.runTransaction(async (t) => {
      const senderRef = db.collection('users').doc(senderPhone);
      const targetRef = db.collection('users').doc(targetPhone);
      const senderDoc = await t.get(senderRef);
      const targetDoc = await t.get(targetRef);
      if (!targetDoc.exists) throw new Error('المستقبل غير موجود');
      const senderData = senderDoc.data();
      const targetData = targetDoc.data();
      const senderWallets = senderData.wallets || {};
      let chosenAgent = null;
      for (const [agent, bal] of Object.entries(senderWallets)) {
        if (bal >= amount) { chosenAgent = agent; break; }
      }
      if (!chosenAgent) throw new Error('لا يوجد رصيد كافٍ لدى أي وكيل');
      senderWallets[chosenAgent] -= amount;
      const targetWallets = targetData.wallets || {};
      targetWallets[chosenAgent] = (targetWallets[chosenAgent] || 0) + amount;
      t.update(senderRef, { wallets: senderWallets });
      t.update(targetRef, { wallets: targetWallets });
      t.set(db.collection('transactions').doc(), {
        fromPhone: senderPhone, toPhone: targetPhone, agentPhone: chosenAgent,
        amount, type: 'transfer', timestamp: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// طلب شحن حصة (وكيل)
app.post('/api/recharge-request', authenticate, async (req, res) => {
  const { amount, bankName, transferSource, reference, receiptBase64 } = req.body;
  const userPhone = req.user.phone;
  try {
    await db.collection('recharge_requests').add({
      userPhone, userName: req.user.phone, networkName: '', targetPhone: '774578241',
      amount, fee: 0, bankName, transferSource, reference, receiptBase64,
      status: 'قيد الانتظار', type: 'saas_quota',
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    res.json({ success: true, message: 'تم إرسال الطلب' });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// قبول طلب شحن (مشرف)
app.post('/api/accept-recharge', authenticate, async (req, res) => {
  if (req.user.role !== 'super_admin') return res.status(403).json({ error: 'غير مصرح' });
  const { requestId, agentPhone, quotaAmount } = req.body;
  try {
    await db.runTransaction(async (t) => {
      const reqRef = db.collection('recharge_requests').doc(requestId);
      const reqDoc = await t.get(reqRef);
      if (!reqDoc.exists) throw new Error('الطلب غير موجود');
      if (reqDoc.data().status !== 'قيد الانتظار') throw new Error('الطلب تمت معالجته');
      t.update(reqRef, { status: 'مقبول' });
      t.update(db.collection('users').doc(agentPhone), { balance: admin.firestore.FieldValue.increment(quotaAmount) });
    });
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============== دوال الميكروتك (كما كانت سابقاً) ==============

app.post('/testConnection', async (req, res) => {
  const { host, user, pass, port } = req.body;
  if (!host || !user) return res.status(400).json({ error: 'بيانات ناقصة' });
  const api = new RouterOSAPI({ host, user, password: pass || '', port: parseInt(port) || 8728, timeout: 10 });
  try {
    await api.connect();
    await api.close();
    res.json({ success: true, message: 'تم الاتصال بالميكروتك' });
  } catch (e) { res.status(500).json({ error: `فشل الاتصال: ${e.message}` }); }
});

app.post('/generateMikrotikCards', async (req, res) => {
  const { networkId, categoryId, amount, agentPhone } = req.body;
  try {
    const netRef = db.collection('networks').doc(networkId);
    const netDoc = await netRef.get();
    if (!netDoc.exists) return res.status(404).json({ error: 'الشبكة غير موجودة' });
    const netData = netDoc.data();
    const categories = netData.categories || [];
    const catIndex = categories.findIndex(c => c.id === categoryId);
    if (catIndex === -1) return res.status(404).json({ error: 'الفئة غير موجودة' });

    const api = new RouterOSAPI({ host: netData.ip, user: netData.apiUser, password: netData.apiPassword, port: parseInt(netData.apiPort) || 8728, timeout: 20 });
    await api.connect();
    const batch = db.batch();
    const pins = [];
    for (let i = 0; i < amount; i++) {
      const pin = Math.floor(10000000 + Math.random() * 90000000).toString();
      await api.write('/ip/hotspot/user/add', [`=name=${pin}`, `=password=${pin}`, `=profile=${categories[catIndex].name}`, `=comment=App-Gen-${agentPhone}`]);
      const cardRef = db.collection('cards').doc();
      batch.set(cardRef, { pin, networkId, categoryId, cardTitle: `${netData.name} - ${categories[catIndex].name}`, agentPhone, status: 'متاح', createdAt: admin.firestore.FieldValue.serverTimestamp() });
      pins.push(pin);
    }
    await api.close();
    categories[catIndex].realStock = (categories[catIndex].realStock || 0) + amount;
    categories[catIndex].stock = (categories[catIndex].realStock || 0) + (categories[catIndex].simStock || 0);
    batch.update(netRef, { categories });
    await batch.commit();
    res.json({ success: true, pins });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============== النسخ الاحتياطي ==============
async function performBackup(prefix) {
  try {
    console.log(`[${prefix}] 📦 بدء النسخ الاحتياطي...`);
    const usersSnap = await db.collection('users').get();
    const usersData = usersSnap.docs.map(d => d.data());
    const transSnap = await db.collection('transactions').get();
    const transactionsData = transSnap.docs.map(d => d.data());
    const fullData = { backup_info: { type: prefix, timestamp: new Date().toISOString(), server: "Render" }, data: { users: usersData, transactions: transactionsData } };
    const now = new Date();
    const timeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' }).replace(':', '-');
    const dateStr = now.toISOString().split('T')[0];
    const fileName = `backups/NetCards_${prefix}_Backup_${dateStr}_${timeStr}.json`;
    const file = storage.file(fileName);
    await file.save(JSON.stringify(fullData), { contentType: 'application/json' });
    console.log(`✅ تم رفع النسخة الاحتياطية: ${fileName}`);
  } catch (e) { console.error('❌ فشل النسخ الاحتياطي:', e.message); }
}

cron.schedule('* * * * *', async () => {
  try {
    const configDoc = await db.collection('system').doc('backup_settings').get();
    if (configDoc.exists) {
      const { isAutoBackupEnabled, backupTime } = configDoc.data();
      const currentTime = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' });
      if (isAutoBackupEnabled && currentTime === backupTime) await performBackup('Auto');
    }
  } catch (e) {}
});

let lastTriggerTime = null;
db.collection('system').doc('backup_settings').onSnapshot(async (docSnap) => {
  if (docSnap.exists) {
    const data = docSnap.data();
    if (data.manualTrigger) {
      const triggerValue = data.manualTrigger.toMillis ? data.manualTrigger.toMillis() : data.manualTrigger;
      if (lastTriggerTime !== triggerValue) {
        lastTriggerTime = triggerValue;
        await performBackup('Manual');
      }
    }
  }
});

// ============== البوت الذكي للتوليد التلقائي ==============
async function autoGenerateBot() {
  try {
    const networksSnap = await db.collection('networks').get();
    for (const netDoc of networksSnap.docs) {
      const netData = netDoc.data();
      if (netData.isActive === false) continue;
      const categories = netData.categories || [];
      let categoriesUpdated = false;
      for (let i = 0; i < categories.length; i++) {
        const category = categories[i];
        const stock = (category.realStock || 0) + (category.simStock || 0);
        const minStock = category.botMinStock || 5;
        const refillAmount = category.botRefillAmount || 50;
        if (category.isBotEnabled === true && stock < minStock) {
          console.log(`🤖 البوت يعمل: فئة ${category.name}، جاري توليد ${refillAmount} كرت...`);
          const api = new RouterOSAPI({ host: netData.ip, user: netData.apiUser, password: netData.apiPassword, port: parseInt(netData.apiPort) || 8728, timeout: 20 });
          try {
            await api.connect();
            const batch = db.batch();
            for (let j = 0; j < refillAmount; j++) {
              const pin = Math.floor(10000000 + Math.random() * 90000000).toString();
              await api.write('/ip/hotspot/user/add', [`=name=${pin}`, `=password=${pin}`, `=profile=${category.name}`, `=comment=AutoBot-${netData.agentPhone}`]);
              batch.set(db.collection('cards').doc(), { pin, networkId: netDoc.id, categoryId: category.id, cardTitle: `${netData.name} - ${category.name}`, agentPhone: netData.agentPhone, status: 'متاح', createdAt: admin.firestore.FieldValue.serverTimestamp(), generatedBy: 'AutoBot' });
            }
            await api.close();
            categories[i].realStock = (categories[i].realStock || 0) + refillAmount;
            categories[i].stock = (categories[i].realStock || 0) + (categories[i].simStock || 0);
            categoriesUpdated = true;
            await batch.commit();
            console.log(`✅ نجاح البوت: تمت إضافة ${refillAmount} كرت لـ ${category.name}`);
          } catch (err) {
            console.error(`❌ خطأ البوت مع شبكة ${netData.name}:`, err.message);
            if (api && api.connected) await api.close().catch(() => {});
          }
        }
      }
      if (categoriesUpdated) await db.collection('networks').doc(netDoc.id).update({ categories });
    }
  } catch (e) { console.error('❌ خطأ عام في البوت:', e.message); }
}

cron.schedule('*/5 * * * *', async () => { await autoGenerateBot(); });

// ---------- تصدير الدالة السحابية ----------
exports.api = functions.https.onRequest(app);
