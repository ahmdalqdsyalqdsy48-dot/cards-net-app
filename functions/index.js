const express = require('express');
const cors = require('cors');
const { initializeApp } = require('firebase/app');
const { getFirestore, collection, doc, getDoc, getDocs, setDoc, updateDoc, serverTimestamp, writeBatch, onSnapshot } = require('firebase/firestore');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getStorage, ref, uploadString } = require('firebase/storage');
const { RouterOSAPI } = require('node-routeros');
const cron = require('node-cron');

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// 1. إعدادات مشروعك
const firebaseConfig = {
  apiKey: "AIzaSyDdZzU6VXrmmk9Ul99GTN5RLtza95tLkVE",
  authDomain: "netcardsapp.firebaseapp.com",
  projectId: "netcardsapp",
  storageBucket: "netcardsapp.firebasestorage.app",
  messagingSenderId: "100057914511",
  appId: "1:100057914511:web:75b015601ca5cb836724fa"
};

// 2. تهيئة فايربيز
const firebaseApp = initializeApp(firebaseConfig);
const db = getFirestore(firebaseApp);
const auth = getAuth(firebaseApp);
const storage = getStorage(firebaseApp);

// 3. دالة تسجيل دخول السيرفر
async function serverLogin() {
    const email = process.env.SERVER_EMAIL || "server@netcardsapp.com";
    const password = process.env.SERVER_PASSWORD || "password123456";
    return signInWithEmailAndPassword(auth, email, password);
}

// ==========================================
// 📡 محرك توليد كروت الميكروتيك
// ==========================================
app.post('/generateMikrotikCards', async (req, res) => {
    const { networkId, categoryId, amount, agentPhone } = req.body;

    try {
        await serverLogin();

        const netRef = doc(db, 'networks', networkId);
        const netDoc = await getDoc(netRef);
        if (!netDoc.exists()) throw new Error('الشبكة غير موجودة');

        const netData = netDoc.data();
        const categories = netData.categories || [];
        const catIndex = categories.findIndex(c => c.id === categoryId);
        const category = categories[catIndex];

        const api = new RouterOSAPI({ host: netData.ip, user: netData.apiUser, password: netData.apiPassword, port: parseInt(netData.apiPort) || 8728, timeout: 15 });
        await api.connect();
        
        const batch = writeBatch(db);
        const generatedPins = [];
        
        for (let i = 0; i < amount; i++) {
            const pin = Math.floor(10000000 + Math.random() * 90000000).toString(); 
            await api.write('/ip/hotspot/user/add', [`=name=${pin}`, `=password=${pin}`, `=profile=${category.name}`, `=comment=App-Gen-${agentPhone}`]);

            const cardRef = doc(collection(db, 'cards'));
            batch.set(cardRef, { pin, networkId, categoryId, cardTitle: `${netData.name} - ${category.name}`, agentPhone, status: 'متاح', createdAt: serverTimestamp() });
            generatedPins.push(pin);
        }

        api.close();
        categories[catIndex].stock = (categories[catIndex].stock || 0) + parseInt(amount);
        batch.update(netRef, { categories });
        await batch.commit();

        res.json({ success: true, message: `تم توليد ${amount} كرت بنجاح.`, pins: generatedPins });
    } catch (error) {
        console.error("Mikrotik Error:", error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ==========================================
// ☁️ محرك النسخ الاحتياطي (إلى Firebase Storage)
// ==========================================
async function performBackup(prefix) {
    try {
        await serverLogin();
        console.log(`[${prefix}] بدء عملية النسخ الاحتياطي...`);

        const usersSnap = await getDocs(collection(db, 'users'));
        const usersData = usersSnap.docs.map(doc => doc.data());
        
        const transSnap = await getDocs(collection(db, 'transactions'));
        const transactionsData = transSnap.docs.map(doc => doc.data());

        const fullData = {
            backup_info: { type: prefix, timestamp: new Date().toISOString() },
            data: { users: usersData, transactions: transactionsData }
        };

        const now = new Date();
        const timeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' }).replace(':', '-');
        const dateStr = now.toISOString().split('T')[0];
        const fileName = `backups/NetCards_${prefix}_Backup_${dateStr}_${timeStr}.json`;

        // الرفع إلى Firebase Storage
        const storageRef = ref(storage, fileName);
        await uploadString(storageRef, JSON.stringify(fullData), 'raw', { contentType: 'application/json' });
        
        console.log(`✅ تم بنجاح رفع الملف إلى مساحة التخزين: ${fileName}`);
    } catch (error) {
        console.error('❌ فشل في عملية الرفع:', error);
    }
}

// ⏰ فحص النسخ التلقائي (كل دقيقة)
cron.schedule('* * * * *', async () => {
    try {
        await serverLogin();
        const configDoc = await getDoc(doc(db, 'system', 'backup_settings'));
        if (configDoc.exists()) {
            const { isAutoBackupEnabled, backupTime } = configDoc.data();
            const currentTime = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' });
            if (isAutoBackupEnabled && currentTime === backupTime) {
                await performBackup('Auto');
            }
        }
    } catch(e) { }
});

// ⚡ مراقبة زر النسخ اليدوي من التطبيق
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

app.get('/', (req, res) => res.send('🚀 Mikrotik & Backup Server is LIVE!'));

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => console.log(`✅ Server running on port ${PORT}`));
