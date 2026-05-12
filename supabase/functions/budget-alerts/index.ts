import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

serve(async (req) => {
  try {
    // 1. Ambil semua profil yang memiliki expo_push_token
    const { data: profiles, error: profileError } = await supabase
      .from("profiles")
      .select("id, expo_push_token, budget_alert_threshold")
      .not("expo_push_token", "is", null);

    if (profileError) throw profileError;
    if (!profiles || profiles.length === 0) {
      return new Response(JSON.stringify({ message: "No push tokens found." }), { status: 200 });
    }

    const currentMonthDate = new Date();
    const currentMonthString = `${currentMonthDate.getFullYear()}-${String(currentMonthDate.getMonth() + 1).padStart(2, '0')}-01`;

    const messages = [];

    // 2. Iterasi setiap user
    for (const profile of profiles) {
      // Ambil budget bulan ini
      const { data: budgetData } = await supabase
        .from("budgets")
        .select("total_budget")
        .eq("user_id", profile.id)
        .eq("month", currentMonthString)
        .single();

      if (!budgetData || !budgetData.total_budget) continue;
      const totalBudget = parseFloat(budgetData.total_budget);

      // Ambil total pengeluaran bulan ini
      const startOfMonth = new Date(currentMonthDate.getFullYear(), currentMonthDate.getMonth(), 1).toISOString();
      const endOfMonth = new Date(currentMonthDate.getFullYear(), currentMonthDate.getMonth() + 1, 0, 23, 59, 59).toISOString();

      const { data: expenses } = await supabase
        .from("transactions")
        .select("amount")
        .eq("user_id", profile.id)
        .eq("type", "out")
        .gte("created_at", startOfMonth)
        .lte("created_at", endOfMonth);

      const totalSpent = expenses ? expenses.reduce((sum, t) => sum + parseFloat(t.amount), 0) : 0;
      const spentRatio = totalSpent / totalBudget;

      const alertThreshold = profile.budget_alert_threshold ? parseFloat(profile.budget_alert_threshold) : 0.8;

      // 3. Jika pengeluaran >= batas (threshold), kirim notifikasi
      if (spentRatio >= alertThreshold) {
        messages.push({
          to: profile.expo_push_token,
          sound: "default",
          title: "Peringatan Budget! ⚠️",
          body: `Kamu sudah memakai ${(spentRatio * 100).toFixed(0)}% dari budget bulan ini. Yuk lebih hemat!`,
          data: { url: "/(tabs)/insights" },
        });
      }
    }

    // 4. Kirim ke Expo Push API
    if (messages.length > 0) {
      const expoRes = await fetch("https://exp.host/--/api/v2/push/send", {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Accept-encoding": "gzip, deflate",
          "Content-Type": "application/json",
        },
        body: JSON.stringify(messages),
      });
      
      const expoData = await expoRes.json();
      return new Response(JSON.stringify({ success: true, expoData }), { status: 200, headers: { "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ success: true, message: "No alerts needed" }), { status: 200, headers: { "Content-Type": "application/json" } });

  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500, headers: { "Content-Type": "application/json" } });
  }
});
