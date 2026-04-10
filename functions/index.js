const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

// إعداد صلاحيات الوصول لجوجل درايف
const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/drive.file'],
});
const drive = google.drive({ version: 'v3', auth });

/**
 * محرك النسخ الاحتياطي الآلي - يعمل كل دقيقة
 */
exports.automatedBackupEngine = functions.pubsub.schedule('* * * * *')
    .timeZone('Asia/Riyadh') // تأكد من ضبط التوقيت حسب دولتك
    .onRun(async (context) => {
        const db = admin.firestore();
        
        // 1. جلب إعدادات النسخ من قاعدة البيانات
        const configDoc = await db.collection('system_settings').doc('backup_config').get();
        
        if (!configDoc.exists) {
            console.log('إعدادات النسخ غير موجودة.');
            return null;
        }

        const { isAutoBackupEnabled, backupTime } = configDoc.data();

        // 2. الحصول على الوقت الحالي بتنسيق HH:mm (مثلاً 04:15)
        const now = new Date();
        const currentTime = now.toLocaleTimeString('en-GB', { 
            hour: '2-digit', 
            minute: '2-digit', 
            timeZone: 'Asia/Riyadh' 
        });

        console.log(`الوقت الحالي: ${currentTime} | وقت النسخ المطلوب: ${backupTime}`);

        // 3. التحقق من الشرط: هل التفعيل متاح وهل الوقت متطابق؟
        if (!isAutoBackupEnabled || currentTime !== backupTime) {
            return null;
        }

        console.log('بدء عملية النسخ الاحتياطي الدقيقة...');

        try {
            // 4. جلب البيانات (مثال لمجموعة المستخدمين)
            const snapshot = await db.collection('users').get();
            const allData = snapshot.docs.map(doc => doc.data());

            // 5. تجهيز الملف ورفعه لجوجل درايف
            const fileName = `Auto_Backup_${currentTime.replace(':', '-')}_${new Date().toISOString().split('T')[0]}.json`;
            
            await drive.files.create({
                requestBody: {
                    name: fileName,
                    mimeType: 'application/json',
                    parents: ['NetCards_Backups'] // سيتم الرفع للمجلد المخصص
                },
                media: {
                    mimeType: 'application/json',
                    body: JSON.stringify(allData),
                },
            });

            console.log(`تم بنجاح رفع النسخة: ${fileName}`);
        } catch (error) {
            console.error('حدث خطأ أثناء النسخ:', error);
        }

        return null;
    });
