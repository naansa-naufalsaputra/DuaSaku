import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization')!
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

    // Mengambil profil untuk mendapatkan financial goal
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('financial_goal')
      .eq('id', user.id)
      .single()

    // Mengambil transaksi yang dirampingkan untuk hemat token
    const { data: transactions } = await supabaseClient
      .from('transactions')
      .select('amount, category, type, created_at')
      .limit(20)
      .order('created_at', { ascending: false })

    const goal = profile?.financial_goal || 'Berhemat bulanan';
    const apiKey = Deno.env.get('GEMINI_API_KEY');

    // Prompt dinamis berdasarkan data user
    const promptText = `
      Konteks User: Target finansial utamanya saat ini adalah "${goal}".
      Data Transaksi Terakhir: ${JSON.stringify(transactions)}. 
      Tugas: 
      1. Klasifikasikan secara internal transaksi pengeluaran (out) tersebut menjadi "Kebutuhan" (primer) vs "Keinginan" (sekunder).
      2. Berikan 3 saran finansial singkat, santai, dan sangat spesifik berdasarkan data transaksi tersebut untuk membantu mencapai target finansialnya.
      3. Soroti secara spesifik jika ada "kebocoran" dana di kategori "Keinginan".
      Gunakan bahasa Indonesia.
    `;

    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: promptText }] }]
      })
    })

    const result = await response.json()
    const content = result.candidates[0].content.parts[0].text

    // Keep JSON structure backward compatible with UI
    return new Response(JSON.stringify({ advice: content }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 500, headers: corsHeaders })
  }
})
