const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const cron = require('node-cron');
const nodemailer = require('nodemailer');
const { RouterOSAPI } = require('node-routeros');
const { initializeApp } = require('firebase/app');
const {
  getFirestore,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  addDoc,
  query,
  where,
  limit,
  runTransaction,
  serverTimestamp,
  writeBatch,
  arrayUnion,
  increment,
  onSnapshot
} = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getStorage, ref, uploadString } = require('firebase/storage');

// ---------- إعدادات Firebase ----------
const firebaseConfig = {
  apiKey: "AIzaSyDdZzU6VXrmmk9Ul99GTN5RLtza95tLkVE",
  authDomain: "netcardsapp.firebaseapp.com",
  projectId: "netcardsapp",
  storageBucket: "netcardsapp.firebasestorage.app",
  messagingSenderId: "100057914511",
  appId: "1:100057914511:web:75b015601ca5cb836724fa"
};

const firebaseApp = initializeApp(firebaseConfig);
const db = getFirestore(firebaseApp);
const auth = getAuth(firebaseApp);
const storage = getStorage(firebaseApp);

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '10mb' }));

// ---------- إعداد البريد الإلكتروني ----------
let transporter = null;
async function initTransporter() {
  if (transporter) return;
  if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });
    console.log('✅ تم إعداد البريد من متغيرات البيئة');
    return;
  }
  try {
    const mailDoc = await getDoc(doc(db, 'system', 'mail_settings'));
    if (mailDoc.exists()) {
      const { user, pass } = mailDoc.data();
      if (user && pass) {
        transporter = nodemailer.createTransport({
          service: 'gmail',
          auth: { user, pass },
        });
        console.log('✅ تم إعداد البريد من Firestore');
      }
    }
  } catch (e) {
    console.warn('⚠️ لا توجد إعدادات بريد، لن يتم إرسال التقارير');
  }
}

// ---------- تسجيل دخول السيرفر ----------
async function serverLogin() {
  const email = process.env.SERVER_EMAIL || "server@netcardsapp.com";
  const password = process.env.SERVER_PASSWORD || "password123456";
  await signInWithEmailAndPassword(auth, email, password);
}

// ---------- مفتاح التوقيع ----------
const SECRET = process.env.SECRET_KEY || 'netcards_secret_change_me';

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
  req.user = { phone: user.phone, role: user.role };
  next();
}

// ==================== API ====================
app.get('/', (req, res) => res.send('NetCards Server Running'));

// تسجيل الدخول
app.post('/api/login', async (req, res) => {
  const { phone, password } = req.body;
  if (!phone || !password) return res.status(400).json({ error: 'البيانات ناقصة' });
  try {
    if (phone === '774578241' && password === '75486958aaa') {
      const token = generateToken(phone, 'super_admin');
      return res.json({
        token,
        user: { phone, name: 'مالك النظام', role: 'super_admin', balance: 0, networkName: 'المركز الرئيسي', pin: '123456', permissions: {} }
      });
    }
    await serverLogin();
    const userDoc = await getDoc(doc(db, 'users', phone));
    if (!userDoc.exists()) return res.status(401).json({ error: 'المستخدم غير موجود' });
    const userData = userDoc.data();
    if (userData.password !== password) return res.status(401).json({ error: 'كلمة المرور خاطئة' });
    const token = generateToken(phone, userData.role);
    res.json({
      token,
      user: { phone, name: userData.name, role: userData.role, balance: userData.balance || 0, networkName: userData.networkName, pin: userData.pin, permissions: userData.permissions || {} }
    });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تسجيل مستخدم جديد
app.post('/api/register', async (req, res) => {
  const { name, phone, password, role } = req.body;
  if (!name || !phone || !password || !role) return res.status(400).json({ error: 'البيانات ناقصة' });
  try {
    await serverLogin();
    const existing = await getDoc(doc(db, 'users', phone));
    if (existing.exists()) return res.status(400).json({ error: 'الرقم مسجل مسبقاً' });
    await setDoc(doc(db, 'users', phone), {
      id: 'USER_' + Date.now(),
      name, phone, password, role,
      balance: 0, wallets: {}, networkName: 'غير محدد', dangerLimit: 0,
      status: 'نشط', purchasedCards: [], pin: '123456', isBiometricEnabled: false,
      createdAt: serverTimestamp(),
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
    await serverLogin();
    const cardsSnap = await getDocs(query(
      collection(db, 'cards'),
      where('agentPhone', '==', agentPhone),
      where('categoryId', '==', categoryId),
      where('status', '==', 'متاح'),
      limit(1)
    ));
    if (cardsSnap.empty) return res.status(400).json({ error: 'لا توجد كروت متاحة' });
    const cardDocRef = cardsSnap.docs[0].ref;
    const cardData = cardsSnap.docs[0].data();

    await runTransaction(db, async (transaction) => {
      const buyerRef = doc(db, 'users', buyerPhone);
      const buyerDoc = await transaction.get(buyerRef);
      if (!buyerDoc.exists()) throw new Error('المشتري غير موجود');
      const buyerData = buyerDoc.data();
      const wallets = buyerData.wallets || {};
      const currentBalance = wallets[agentPhone] || 0;
      if (currentBalance < price) throw new Error('الرصيد غير كافٍ');

      wallets[agentPhone] = currentBalance - price;
      transaction.update(buyerRef, { wallets });
      transaction.update(cardDocRef, {
        status: 'مباع',
        buyerPhone,
        soldAt: serverTimestamp()
      });
      const invoice = { title: cardTitle, pin: cardData.pin, price, agentPhone, date: new Date().toISOString() };
      transaction.update(buyerRef, { purchasedCards: arrayUnion(invoice) });
      transaction.update(doc(db, 'system', 'main_info'), { totalSystemCards: increment(-1) });
      transaction.set(doc(collection(db, 'transactions')), {
        fromPhone: buyerPhone, toPhone: agentPhone, agentPhone,
        agentName: buyerData.name,
        targetName: buyerData.name,
        networkName: buyerData.networkName || '',
        amount: price,
        fee: 0,
        paymentMethod: 'محفظة',
        type: 'sale',
        title: `بيع ${cardTitle}`,
        timestamp: serverTimestamp()
      });
    });
    res.json({ success: true, pin: cardData.pin });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// تحويل رصيد
app.post('/api/transfer', authenticate, async (req, res) => {
  const { targetPhone, amount } = req.body;
  const senderPhone = req.user.phone;
  if (!targetPhone || !amount || amount <= 0) return res.status(400).json({ error: 'بيانات ناقصة' });
  try {
    await serverLogin();
    await runTransaction(db, async (transaction) => {
      const senderRef = doc(db, 'users', senderPhone);
      const targetRef = doc(db, 'users', targetPhone);
      const senderDoc = await transaction.get(senderRef);
      const targetDoc = await transaction.get(targetRef);
      if (!targetDoc.exists()) throw new Error('المستقبل غير موجود');
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
      transaction.update(senderRef, { wallets: senderWallets });
      transaction.update(targetRef, { wallets: targetWallets });
      transaction.set(doc(collection(db, 'transactions')), {
        fromPhone: senderPhone, toPhone: targetPhone, agentPhone: chosenAgent,
        amount, type: 'transfer', timestamp: serverTimestamp()
      });
    });
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// طلب شحن حصة
app.post('/api/recharge-request', authenticate, async (req, res) => {
  const { amount, bankName, transferSource, reference, receiptBase64 } = req.body;
  const userPhone = req.user.phone;
  try {
    await serverLogin();
    await addDoc(collection(db, 'recharge_requests'), {
      userPhone, userName: req.user.phone,
      networkName: '', targetPhone: '774578241',
      amount, fee: 0, bankName, transferSource, reference, receiptBase64,
      status: 'قيد الانتظار', type: 'saas_quota',
      timestamp: serverTimestamp()
    });
    res.json({ success: true, message: 'تم إرسال الطلب' });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// قبول طلب شحن
app.post('/api/accept-recharge', authenticate, async (req, res) => {
  if (req.user.role !== 'super_admin') return res.status(403).json({ error: 'غير مصرح' });
  const { requestId, agentPhone, quotaAmount } = req.body;
  try {
    await serverLogin();
    await runTransaction(db, async (transaction) => {
      const reqRef = doc(db, 'recharge_requests', requestId);
      const reqDoc = await transaction.get(reqRef);
      if (!reqDoc.exists()) throw new Error('الطلب غير موجود');
      if (reqDoc.data().status !== 'قيد الانتظار') throw new Error('الطلب تمت معالجته');
      transaction.update(reqRef, { status: 'مقبول' });
      transaction.update(doc(db, 'users', agentPhone), { balance: increment(quotaAmount) });
    });
    res.json({ success: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============== الميكروتك ==============
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
    await serverLogin();
    const netDoc = await getDoc(doc(db, 'networks', networkId));
    if (!netDoc.exists()) return res.status(404).json({ error: 'الشبكة غير موجودة' });
    const netData = netDoc.data();
    const categories = netData.categories || [];
    const catIndex = categories.findIndex(c => c.id === categoryId);
    if (catIndex === -1) return res.status(404).json({ error: 'الفئة غير موجودة' });

    const api = new RouterOSAPI({ host: netData.ip, user: netData.apiUser, password: netData.apiPassword, port: parseInt(netData.apiPort) || 8728, timeout: 20 });
    await api.connect();
    const batch = writeBatch(db);
    const pins = [];
    for (let i = 0; i < amount; i++) {
      const pin = Math.floor(10000000 + Math.random() * 90000000).toString();
      await api.write('/ip/hotspot/user/add', [`=name=${pin}`, `=password=${pin}`, `=profile=${categories[catIndex].name}`, `=comment=App-Gen-${agentPhone}`]);
      const cardRef = doc(collection(db, 'cards'));
      batch.set(cardRef, { pin, networkId, categoryId, cardTitle: `${netData.name} - ${categories[catIndex].name}`, agentPhone, status: 'متاح', createdAt: serverTimestamp() });
      pins.push(pin);
    }
    await api.close();
    categories[catIndex].realStock = (categories[catIndex].realStock || 0) + amount;
    categories[catIndex].stock = (categories[catIndex].realStock || 0) + (categories[catIndex].simStock || 0);
    batch.update(netDoc.ref, { categories });
    await batch.commit();
    res.json({ success: true, pins });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

// ============== النسخ الاحتياطي ==============
async function performBackup(prefix) {
  try {
    await serverLogin();
    console.log(`[${prefix}] 📦 بدء النسخ الاحتياطي...`);
    const usersSnap = await getDocs(collection(db, 'users'));
    const usersData = usersSnap.docs.map(d => d.data());
    const transSnap = await getDocs(collection(db, 'transactions'));
    const transactionsData = transSnap.docs.map(d => d.data());
    const fullData = { backup_info: { type: prefix, timestamp: new Date().toISOString(), server: "Render" }, data: { users: usersData, transactions: transactionsData } };
    const now = new Date();
    const timeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' }).replace(':', '-');
    const dateStr = now.toISOString().split('T')[0];
    const fileName = `backups/NetCards_${prefix}_Backup_${dateStr}_${timeStr}.json`;
    const storageRef = ref(storage, fileName);
    await uploadString(storageRef, JSON.stringify(fullData), 'raw', { contentType: 'application/json' });
    console.log(`✅ تم رفع النسخة الاحتياطية: ${fileName}`);
  } catch (e) { console.error('❌ فشل النسخ الاحتياطي:', e.message); }
}

cron.schedule('* * * * *', async () => {
  try {
    await serverLogin();
    const configDoc = await getDoc(doc(db, 'system', 'backup_settings'));
    if (configDoc.exists()) {
      const { isAutoBackupEnabled, backupTime } = configDoc.data();
      const currentTime = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' });
      if (isAutoBackupEnabled && currentTime === backupTime) await performBackup('Auto');
    }
  } catch (e) {}
});

let lastTriggerTime = null;
onSnapshot(doc(db, 'system', 'backup_settings'), async (docSnap) => {
  if (docSnap.exists()) {
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

// ============== البوت الذكي ==============
async function autoGenerateBot() {
  try {
    await serverLogin();
    const networksSnap = await getDocs(collection(db, 'networks'));
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
            const batch = writeBatch(db);
            for (let j = 0; j < refillAmount; j++) {
              const pin = Math.floor(10000000 + Math.random() * 90000000).toString();
              await api.write('/ip/hotspot/user/add', [`=name=${pin}`, `=password=${pin}`, `=profile=${category.name}`, `=comment=AutoBot-${netData.agentPhone}`]);
              batch.set(doc(collection(db, 'cards')), { pin, networkId: netDoc.id, categoryId: category.id, cardTitle: `${netData.name} - ${category.name}`, agentPhone: netData.agentPhone, status: 'متاح', createdAt: serverTimestamp(), generatedBy: 'AutoBot' });
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
      if (categoriesUpdated) await updateDoc(doc(db, 'networks', netDoc.id), { categories });
    }
  } catch (e) { console.error('❌ خطأ عام في البوت:', e.message); }
}

cron.schedule('*/5 * * * *', async () => { await autoGenerateBot(); });

// ============== الإرسال التلقائي للتقارير المجدولة ==============
async function generateReportContent(phone, email) {
  const userDoc = await getDoc(doc(db, 'users', phone));
  const userName = userDoc.exists() ? userDoc.data().name : 'مستخدم';
  const now = new Date();
  return {
    subject: `تقرير كروت نت - ${userName} - ${now.toLocaleDateString('ar-EG')}`,
    text: `السلام عليكم ${userName}،\n\nهذا تقريرك المجدول من نظام كروت نت.\nتاريخ الإصدار: ${now.toLocaleString('ar-EG')}.\n\nمع تحيات فريق كروت نت.`,
    html: `<div dir="rtl"><h3>تقرير ${userName}</h3><p>تاريخ: ${now.toLocaleString('ar-EG')}</p></div>`
  };
}

async function checkAndSendScheduledReports() {
  await initTransporter();
  if (!transporter) return;

  const now = new Date();
  const currentHour = now.getHours(); // 24 ساعة
  const currentMinute = now.getMinutes();
  const currentDayOfWeek = now.getDay(); // 0=أحد, 1=إثنين ... 6=سبت (JavaScript)
  const currentDayOfMonth = now.getDate();

  const schedulesSnap = await getDocs(collection(db, 'scheduled_reports'));
  for (const docSnap of schedulesSnap.docs) {
    const schedule = docSnap.data();
    const { frequency, day, hour: hour12, amPm, email, phone, minute = 0 } = schedule;

    // تحويل الساعة 12 إلى نظام 24
    let scheduleHour = (hour12 % 12);
    if (amPm === 'مساءاً') scheduleHour += 12;

    // ✅ التحقق من الساعة والدقيقة المحددة
    if (currentHour !== scheduleHour) continue;
    if (currentMinute !== minute) continue;

    let shouldSend = false;
    if (frequency === 'يومياً') {
      shouldSend = true;
    } else if (frequency === 'أسبوعياً') {
      // day: 1=السبت, 2=الأحد... 7=الجمعة
      // JavaScript getDay: 0=الأحد، 1=الإثنين، ... 6=السبت
      const jsDayMap = { 1: 6, 2: 0, 3: 1, 4: 2, 5: 3, 6: 4, 7: 5 };
      const targetDay = jsDayMap[day] ?? 0;
      if (currentDayOfWeek === targetDay) shouldSend = true;
    } else if (frequency === 'شهرياً') {
      if (currentDayOfMonth === day) shouldSend = true;
    }

    if (!shouldSend) continue;

    // تجنب تكرار الإرسال خلال نفس الدقيقة (حسب آخر إرسال)
    const lastSent = schedule.lastSentAt ? schedule.lastSentAt.toDate() : null;
    if (lastSent && lastSent.toDateString() === now.toDateString() && lastSent.getHours() === currentHour && lastSent.getMinutes() === currentMinute) {
      continue; // تم الإرسال بالفعل في هذه الدقيقة
    }

    try {
      const report = await generateReportContent(phone, email);
      await transporter.sendMail({
        from: `"نظام كروت نت" <${process.env.EMAIL_USER || 'noreply@netcardsapp.com'}>`,
        to: email,
        subject: report.subject,
        text: report.text,
        html: report.html,
      });
      // تحديث آخر إرسال
      await updateDoc(docSnap.ref, { lastSentAt: serverTimestamp() });
      console.log(`✅ تم إرسال التقرير إلى ${email} في ${currentHour}:${currentMinute}`);
    } catch (err) {
      console.error(`❌ فشل إرسال التقرير إلى ${email}:`, err.message);
    }
  }
}

// تشغيل فحص الجدولة كل دقيقة
cron.schedule('* * * * *', async () => {
  await checkAndSendScheduledReports();
});

// ---------- بدء الخادم ----------
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`✅ Server is running on port ${PORT}`);
  await initTransporter();
});
