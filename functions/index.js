const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

// إعداد صلاحيات الوصول لجوجل درايف
const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive'],
});
const drive = google.drive({ version: 'v3', auth });

// ✅ تم إدراج الـ ID الخاص بمجلدك هنا بنجاح
const DRIVE_FOLDER_ID = '1moLLVojVAaYVUAripWiUOr9dBR5RzJy0'; 

/**
 * دالة المحرك الأساسي لرفع البيانات
 */
async function performBackup(db, prefix) {
    try {
        console.log(`[${prefix}] بدء عملية النسخ الاحتياطي...`);
        
        // جلب بيانات المستخدمين والعمليات (قاعدة البيانات كاملة)
        const usersSnap = await db.collection('users').get();
        const usersData = usersSnap.docs.map(doc => doc.data());
        
        const transactionsSnap = await db.collection('transactions').get();
        const transactionsData = transactionsSnap.docs.map(doc => doc.data());

        const fullData = {
            backup_info: {
                type: prefix,
                timestamp: new Date().toISOString(),
                folder_id: DRIVE_FOLDER_ID
            },
            data: {
                users: usersData,
                transactions: transactionsData
            }
        };

        const now = new Date();
        const timeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Riyadh' }).replace(':', '-');
        const dateStr = now.toISOString().split('T')[0];
        const fileName = `NetCards_${prefix}_Backup_${dateStr}_${timeStr}.json`;
        
        // تنفيذ الرفع الفعلي لمجلدك في درايف
        await drive.files.create({
            requestBody: {
                name: fileName,
                mimeType: 'application/json',
                parents: [DRIVE_FOLDER_ID]
            },
            media: {
                mimeType: 'application/json',
                body: JSON.stringify(fullData),
            },
        });

        console.log(`✅ تم بنجاح رفع الملف: ${fileName} إلى المجلد المحدد.`);
    } catch (error) {
        console.error('❌ فشل في عملية الرفع:', error);
    }
}

/**
 * ⏰ المحرك المجدول: يعمل كل دقيقة ويفحص "ساعة المنبه"
 */
exports.automatedBackupEngine = functions.pubsub.schedule('* * * * *')
    .timeZone('Asia/Riyadh')
    .onRun(async (context) => {
        const db = admin.firestore();
        const configDoc = await db.collection('system').doc('backup_settings').get();
        
        if (!configDoc.exists) return null;

        const { isAutoBackupEnabled, backupTime } = configDoc.data();
        const now = new Date();
        const currentTime = now.toLocaleTimeString('en-GB', { 
            hour: '2-digit', 
            minute: '2-digit', 
            timeZone: 'Asia/Riyadh' 
        });

        // المقارنة بالدقيقة
        if (isAutoBackupEnabled && currentTime === backupTime) {
            await performBackup(db, 'Auto');
        }
        return null;
    });

/**
 * ⚡ المحرك الفوري: يستجيب لضغط الزر في التطبيق فوراً
 */
exports.manualBackupTrigger = functions.firestore
    .document('system/backup_settings')
    .onUpdate(async (change, context) => {
        const newValue = change.after.data();
        const previousValue = change.before.data();

        if (newValue.manualTrigger && (!previousValue.manualTrigger || newValue.manualTrigger.toMillis() !== previousValue.manualTrigger.toMillis())) {
            const db = admin.firestore();
            await performBackup(db, 'Manual');
        }
        return null;
    });
