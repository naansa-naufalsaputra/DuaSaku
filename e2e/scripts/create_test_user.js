const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Basic .env parser
const envPath = path.join(__dirname, '../../.env');
const envContent = fs.readFileSync(envPath, 'utf8');
const env = {};
envContent.split('\n').forEach(line => {
  const [key, value] = line.split('=');
  if (key && value) env[key.trim()] = value.trim();
});

const supabaseUrl = env['EXPO_PUBLIC_SUPABASE_URL'];
const supabaseKey = env['EXPO_PUBLIC_SUPABASE_SERVICE_ROLE_KEY'];

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials in .env');
  console.log('You need EXPO_PUBLIC_SUPABASE_SERVICE_ROLE_KEY to create users via script.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function setupTestUser() {
  console.log('👤 Setting up test user...');

  const email = 'test@duasaku.com';
  const password = 'password123';

  // 1. Create or get user
  const { data: userData, error: userError } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  });

  if (userError) {
    if (userError.message.includes('already registered')) {
      console.log('ℹ️ User already exists, fetching ID...');
      const { data: users, error: listError } = await supabase.auth.admin.listUsers();
      if (listError) {
        console.error('Error listing users:', listError);
        process.exit(1);
      }
      const existingUser = users.users.find(u => u.email === email);
      console.log(`✅ Test User ID: ${existingUser.id}`);
      return existingUser.id;
    } else {
      console.error('Error creating user:', userError);
      process.exit(1);
    }
  }

  console.log(`✅ Test User Created! ID: ${userData.user.id}`);
  return userData.user.id;
}

setupTestUser().then(id => {
  if (id) {
    // Update seed_db.js with the new ID
    const seedPath = path.join(__dirname, 'seed_db.js');
    let seedContent = fs.readFileSync(seedPath, 'utf8');
    seedContent = seedContent.replace(
      /const TEST_USER_ID = '.*';/,
      `const TEST_USER_ID = '${id}';`
    );
    fs.writeFileSync(seedPath, seedContent);
    console.log('📝 seed_db.js updated with new User ID.');
  }
});
