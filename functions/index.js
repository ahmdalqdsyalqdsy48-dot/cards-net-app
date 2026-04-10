const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

// الاعتماد على هوية السيرفر الداخلية
const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/drive.file'],
});
const drive = google.drive({ version: 'v3', auth });

exports.automatedBackupEngine = functions.pubsub.schedule('0 * * * *')
    .timeZone('Asia/Riyadh') 
    .onRun(async (context) => {
        const db = admin.firestore();
        const config = await db.collection('system_settings').doc('backup_config').get();
        if (!config.exists) return null;

        const { isAutoBackupEnabled, backupTime } = config.data();
        const currentHour = new Date().getHours(); 
        const targetHour = parseInt(backupTime); 

        if (!isAutoBackupEnabled || currentHour !== targetHour) return null;

        // سحب بيانات المستخدمين والوكلاء (كمثال)
        const usersSnap = await db.collection('users').get();
        const agentsSnap = await db.collection('agents').get();
        
        const data = {
           users: usersSnap.docs.map(d => d.data()),
           agents: agentsSnap.docs.map(d => d.data())
        };

        const fileName = `NetCards_Backup_${new Date().toISOString()}.json`;

        await drive.files.create({
            requestBody: {
                name: fileName,
                mimeType: 'application/json',
                // لا تنسَ وضع رمز المجلد الذي شاركناه هنا! 👇
                parents: ['ضع_معرف_المجلد_هنا'] 
            },
            media: {
                mimeType: 'application/json',
                body: JSON.stringify(data),
            },
        });
        console.log(`تم رفع النسخة ${fileName} بنجاح!`);
    });
