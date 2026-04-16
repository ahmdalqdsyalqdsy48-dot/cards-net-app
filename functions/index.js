const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');
const { RouterOSAPI } = require('node-routeros'); // 👈 إضافة مكتبة الميكروتيك

admin.initializeApp();
const db = admin.firestore();

// ==========================================
// 📡 أولاً: محرك توليد كروت الميكروتيك الحقيقي
// ==========================================
exports.generateMikrotikCards = functions.https.onCall(async (data, context) => {
    const { networkId, categoryId, amount, agentPhone } = data;

    if (!networkId || !categoryId || !amount) {
        throw new functions.https.HttpsError('invalid-argument', 'بيانات ناقصة.');
    }

    try {
        // 1. جلب بيانات الشبكة من الفايربيز
        const netDoc = await db.collection('networks').doc(networkId).get();
        if (!netDoc.exists) throw new Error('الشبكة غير موجودة');

        const netData = netDoc.data();
        const categories = netData.categories || [];
        const catIndex = categories.findIndex(c => c.id === categoryId);
        const category = categories[catIndex];

        // 2. فتح اتصال حقيقي بجهاز الميكروتيك
        const api = new RouterOSAPI({
            host: netData.ip,
            user: netData.apiUser,
            password: netData.apiPassword,
            port: parseInt(netData.apiPort) || 8728,
            timeout: 15
        });

        await api.connect();

        const batch = db.batch();
        const cardTitle = `${netData.name} - ${category.name}`;

        // 3. حلقة التوليد (الميكروتيك + الفايربيز)
        for (let i = 0; i < amount; i++) {
            const pin = Math.floor(10000000 + Math.random() * 90000000).toString(); 

            // إضافة المستخدم داخل الميكروتيك فعلياً
            await api.write('/ip/hotspot/user/add', [
                `=name=${pin}`,
                `=password=${pin}`,
                `=profile=${category.name}`,
                `=comment=App-Gen-${agentPhone}`
            ]);

            // إضافة الكرت لقاعدة بيانات التطبيق للبيع
            const cardRef = db.collection('cards').doc();
            batch.set(cardRef, {
                pin: pin,
                networkId: networkId,
                categoryId: categoryId,
                cardTitle: cardTitle,
                agentPhone: agentPhone,
                status: 'متاح',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }

        api.close(); // إغلاق الاتصال بالراوتر

        // 4. تحديث المخزون في واجهة التطبيق
        categories[catIndex].stock = (categories[catIndex].stock || 0) + parseInt(amount);
        batch.update(db.collection('networks').doc(networkId), { categories: categories });

        await batch.commit();

        return { success: true, message: `تم بنجاح توليد ${amount} كرت في الراوتر وحفظها في التطبيق.` };

    } catch (error) {
        console.error("Mikrotik Error:", error);
        throw new functions.https.HttpsError('internal', `خطأ في الميكروتيك: ${error.message}`);
    }
});

// ==========================================
// ☁️ ثانياً: نظام النسخ الاحتياطي (كودك القديم)
// ==========================================

const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive'],
});
const drive = google.drive({ version: 'v3', auth });
const DRIVE_FOLDER_ID = '1moLLVojVAaYVUAripWiUOr9dBR5RzJy0'; 

async function performBackup(db, prefix) {
    try {
        console.log(`[${prefix}] بدء عملية النسخ الاحتياطي...`);
        const usersSnap = await db.collection('users').get();
        const usersData = usersSnap.docs.map(doc => doc.data());
        const transactionsSnap = await db.collection('transactions').get();
        const transactionsData = transactionsSnap.docs.map(doc => doc.data());

        const fullData = {
            backup_info: { type: prefix, timestamp: new Date().toISOString(), folder_id: DRIVE_FOLDER_ID },
            data: { users: usersData, transactions: transactionsData }
        };

        const now = new Date();
        const timeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' }).replace(':', '-');
        const dateStr = now.toISOString().split('T')[0];
        const fileName = `NetCards_${prefix}_Backup_${dateStr}_${timeStr}.json`;
        
        await drive.files.create({
            requestBody: { name: fileName, mimeType: 'application/json', parents: [DRIVE_FOLDER_ID] },
            media: { mimeType: 'application/json', body: JSON.stringify(fullData) },
        });
        console.log(`✅ تم بنجاح رفع الملف: ${fileName}`);
    } catch (error) {
        console.error('❌ فشل في عملية الرفع:', error);
    }
}

exports.automatedBackupEngine = functions.pubsub.schedule('* * * * *')
    .timeZone('Asia/Riyadh')
    .onRun(async (context) => {
        const configDoc = await db.collection('system').doc('backup_settings').get();
        if (!configDoc.exists) return null;
        const { isAutoBackupEnabled, backupTime } = configDoc.data();
        const now = new Date();
        const currentTime = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' });
        if (isAutoBackupEnabled && currentTime === backupTime) {
            await performBackup(db, 'Auto');
        }
        return null;
    });

exports.manualBackupTrigger = functions.firestore
    .document('system/backup_settings')
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();
        if (newValue.manualTrigger && (!previousValue.manualTrigger || newValue.manualTrigger.toMillis() !== previousValue.manualTrigger.toMillis())) {
            await performBackup(db, 'Manual');
        }
        return null;
    });
