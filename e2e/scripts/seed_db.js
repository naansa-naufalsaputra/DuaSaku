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
const supabaseKey = env['EXPO_PUBLIC_SUPABASE_SERVICE_ROLE_KEY'] || env['EXPO_PUBLIC_SUPABASE_ANON_KEY'];

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials in .env');
  console.log('TIP: Use EXPO_PUBLIC_SUPABASE_SERVICE_ROLE_KEY to bypass RLS for seeding.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Test User ID (Replace with a dedicated test user ID from your Supabase dashboard)
const TEST_USER_ID = 'ced39e12-b953-46ae-be12-4b9f65ff9172'; // Default placeholder

async function seed() {
  console.log('🌱 Seeding database for E2E tests...');

  // Note: Using anon key means we need to handle RLS or use service role key.
  // For this demonstration, we'll assume the user is already logged in or RLS allows it.
  
  const { error: deleteError } = await supabase
    .from('transactions')
    .delete()
    .eq('user_id', TEST_USER_ID);

  if (deleteError) {
    console.error('Error clearing transactions:', deleteError);
    // Don't exit, might be RLS related
  }

  const mockTransactions = [
    {
      user_id: TEST_USER_ID,
      title: 'Monthly Salary',
      amount: 15000000,
      type: 'income',
      category: 'Salary',
      created_at: new Date().toISOString()
    },
    {
      user_id: TEST_USER_ID,
      title: 'Rent',
      amount: 5000000,
      type: 'expense',
      category: 'Rent',
      created_at: new Date().toISOString()
    }
  ];

  const { error: insertError } = await supabase
    .from('transactions')
    .insert(mockTransactions);

  if (insertError) {
    console.error('Error inserting mock data:', insertError);
    process.exit(1);
  }

  console.log('✅ Database seeded successfully.');
}

seed();
