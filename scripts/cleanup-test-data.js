const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

async function cleanup() {
  console.log('🧹 Starting cleanup for test data...');

  try {
    // 1. Get all users
    const { data: { users }, error: listError } = await supabase.auth.admin.listUsers();
    
    if (listError) throw listError;

    // 2. Filter test users (email contains 'test@')
    const testUsers = users.filter(user => user.email && user.email.includes('test@'));
    
    console.log(`🔍 Found ${testUsers.length} test users.`);

    for (const user of testUsers) {
      console.log(`🚮 Cleaning up data for user: ${user.email} (${user.id})`);

      // Delete transactions for this user
      const { error: txError } = await supabase
        .from('transactions')
        .delete()
        .eq('user_id', user.id);
      
      if (txError) console.error(`⚠️ Error deleting transactions for ${user.id}:`, txError.message);

      // Delete categories for this user (if any)
      const { error: catError } = await supabase
        .from('categories')
        .delete()
        .eq('user_id', user.id);
      
      if (catError) console.error(`⚠️ Error deleting categories for ${user.id}:`, catError.message);

      // Delete the user from auth
      const { error: authError } = await supabase.auth.admin.deleteUser(user.id);
      
      if (authError) {
        console.error(`❌ Error deleting user ${user.id}:`, authError.message);
      } else {
        console.log(`✅ Successfully deleted user ${user.email}`);
      }
    }

    console.log('✨ Cleanup finished successfully!');
  } catch (error) {
    console.error('💥 Cleanup failed:', error.message);
    process.exit(1);
  }
}

cleanup();
