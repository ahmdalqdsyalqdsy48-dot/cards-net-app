const express = require('express');
const cors = require('cors');
const { initializeApp } = require('firebase/app');
const { 
    getFirestore, collection, doc, getDoc, getDocs, 
    setDoc, updateDoc, serverTimestamp, writeBatch, onSnapshot 
} = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getStorage, ref, uploadString } = require('firebase/storage');
const { RouterOSAPI } = require('node-routeros');
const cron = require('node-cron');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// 1. إعدادات المشروع (تأكد أنها مطابقة تماماً لملف الـ Web الخاص بك)
const firebaseConfig = {
  apiKey: "AIzaSyDdZzU6VXrmmk9Ul99GTN5RLtza95tLkVE",
  authDomain: "netcardsapp.firebaseapp.com",
  projectId: "netcardsapp",
  storageBucket: "netcardsapp.firebasestorage.app",
  messagingSenderId: "100057914511",
  appId: "1:100057914511:web:75b015601ca5cb836724fa"
};

// 2. تهيئة فايربيز (Firebase SDK for Web/Node)
const firebaseApp = initializeApp(firebaseConfig);
const db = getFirestore(firebaseApp);
const auth = getAuth(firebaseApp);
const storage = getStorage(firebaseApp);

// 3. دالة تسجيل دخول السيرفر (للحصول على توكن الوصول)
async function serverLogin() {
    const email = process.env.SERVER_EMAIL || "server@netcardsapp.com";
    const password = process.env.SERVER_PASSWORD || "password123456";
    try {
        return await signInWithEmailAndPassword(auth, email, password);
    } catch (error) {
        console.error("❌ Firebase Auth Error:", error.message);
        throw new Error("فشل تسجيل دخول السيرفر في فايربيز");
    }
}

// ==========================================
// ⚡ وظيفة اختبار الاتصال بالميكروتك (جديد)
// ==========================================
app.post('/testConnection', async (req, res) => {
    const { host, user, pass, port } = req.body;

    if (!host || !user) {
        return res.status(400).json({ success: false, error: "بيانات الاتصال ناقصة" });
    }

    const api = new RouterOSAPI({
        host: host,
        user: user,
        password: pass || "",
        port: parseInt(port) || 8728,
        timeout: 10 // مهلة 10 ثوانٍ للاختبار
    });

    try {
        console.log(`📡 محاولة اختبار الاتصال بـ: ${host}`);
        await api.connect();
        await api.close(); // نغلق الاتصال فوراً بعد النجاح
        console.log(`✅ نجاح الاتصال بـ: ${host}`);
        res.status(200).json({ success: true, message: "تم الاتصال بالميكروتك بنجاح" });
    } catch (error) {
        console.error(`❌ فشل الاتصال بالميكروتك (${host}):`, error.message);
        res.status(500).json({ 
            success: false, 
            error: `فشل الاتصال: ${error.message}. تأكد من فتح الـ API Port وتفعيل DDNS.` 
        });
    }
});

// ==========================================
// 📡 محرك توليد كروت الميكروتيك الحقيقي
// ==========================================
app.post('/generateMikrotikCards', async (req, res) => {
    const { networkId, categoryId, amount, agentPhone } = req.body;

    try {
        // 1. تسجيل الدخول للحصول على الصلاحية
        await serverLogin();

        // 2. جلب بيانات الشبكة من Firestore
        const netRef = doc(db, 'networks', networkId);
        const netDoc = await getDoc(netRef);
        
        if (!netDoc.exists()) {
            return res.status(404).json({ success: false, error: "الشبكة غير موجودة في قاعدة البيانات" });
        }

        const netData = netDoc.data();
        const categories = netData.categories || [];
        const catIndex = categories.findIndex(c => c.id === categoryId);
        
        if (catIndex === -1) {
            return res.status(404).json({ success: false, error: "الفئة (Profile) غير موجودة" });
        }

        const category = categories[catIndex];

        // 3. الاتصال الفعلي بجهاز الميكروتك
        const api = new RouterOSAPI({
            host: netData.ip,
            user: netData.apiUser,
            password: netData.apiPassword,
            port: parseInt(netData.apiPort) || 8728,
            timeout: 20
        });

        await api.connect();
        const batch = writeBatch(db);
        const generatedPins = [];

        console.log(`🚀 بدء توليد ${amount} كرت لشبكة ${netData.name}`);

        // 4. حلقة التوليد (الميكروتك + Firestore)
        for (let i = 0; i < amount; i++) {
            // توليد رقم عشوائي فريد (8 أرقام)
            const pin = Math.floor(10000000 + Math.random() * 90000000).toString();
            
            // إضافة المستخدم للميكروتك
            await api.write('/ip/hotspot/user/add', [
                `=name=${pin}`,
                `=password=${pin}`,
                `=profile=${category.name}`,
                `=comment=App-Gen-${agentPhone}`
            ]);

            // حجز الكرت في Firestore
            const cardRef = doc(collection(db, 'cards'));
            batch.set(cardRef, {
                pin: pin,
                networkId: networkId,
                categoryId: categoryId,
                cardTitle: `${netData.name} - ${category.name}`,
                agentPhone: agentPhone,
                status: 'متاح',
                createdAt: serverTimestamp()
            });

            generatedPins.push(pin);
        }

        // 5. إغلاق اتصال الميكروتك
        await api.close();

        // 6. تحديث المخزون في الفئة
        categories[catIndex].stock = (categories[catIndex].stock || 0) + parseInt(amount);
        batch.update(netRef, { categories: categories });

        // 7. تنفيذ جميع عمليات Firestore في دفعة واحدة
        await batch.commit();

        console.log(`✅ تم الانتهاء من توليد ${amount} كرت بنجاح.`);
        res.json({ success: true, message: `تم توليد ${amount} كرت بنجاح.`, pins: generatedPins });

    } catch (error) {
        console.error("❌ Mikrotik/Firestore Error:", error.message);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ==========================================
// ☁️ محرك النسخ الاحتياطي (إلى Firebase Storage)
// ==========================================
async function performBackup(prefix) {
    try {
        await serverLogin();
        console.log(`[${prefix}] 📦 بدء عملية النسخ الاحتياطي...`);

        const usersSnap = await getDocs(collection(db, 'users'));
        const usersData = usersSnap.docs.map(doc => doc.data());
        
        const transSnap = await getDocs(collection(db, 'transactions'));
        const transactionsData = transSnap.docs.map(doc => doc.data());

        const fullData = {
            backup_info: { 
                type: prefix, 
                timestamp: new Date().toISOString(),
                server: "Render-Node-Server"
            },
            data: { 
                users: usersData, 
                transactions: transactionsData 
            }
        };

        const now = new Date();
        const timeStr = now.toLocaleTimeString('en-GB', { 
            hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' 
        }).replace(':', '-');
        const dateStr = now.toISOString().split('T')[0];
        const fileName = `backups/NetCards_${prefix}_Backup_${dateStr}_${timeStr}.json`;

        const storageRef = ref(storage, fileName);
        await uploadString(storageRef, JSON.stringify(fullData), 'raw', { contentType: 'application/json' });
        
        console.log(`✅ تم رفع النسخة الاحتياطية: ${fileName}`);
    } catch (error) {
        console.error('❌ فشل النسخ الاحتياطي:', error.message);
    }
}

// ⏰ فحص النسخ التلقائي (كل دقيقة)
cron.schedule('* * * * *', async () => {
    try {
        await serverLogin();
        const configDoc = await getDoc(doc(db, 'system', 'backup_settings'));
        if (configDoc.exists()) {
            const { isAutoBackupEnabled, backupTime } = configDoc.data();
            const currentTime = new Date().toLocaleTimeString('en-GB', { 
                hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' 
            });
            if (isAutoBackupEnabled && currentTime === backupTime) {
                await performBackup('Auto');
            }
        }
    } catch(e) { }
});

// ⚡ مراقبة زر النسخ اليدوي من التطبيق (onSnapshot)
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

// الصفحة الرئيسية للسيرفر
app.get('/', (req, res) => {
    res.send(`
        <div style="text-align:center; padding:50px; font-family:sans-serif;">
            <h1 style="color:#2ecc71;">🚀 NetCards Mikrotik Server is LIVE</h1>
            <p>Status: All systems functional</p>
            <p>Time: ${new Date().toLocaleString()}</p>
        </div>
    `);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Server is running on port ${PORT}`);
});
