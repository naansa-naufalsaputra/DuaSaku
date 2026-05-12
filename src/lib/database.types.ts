/* eslint-disable @typescript-eslint/no-unused-vars */
type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      budgets: {
        Row: {
          id: string
          month: string
          total_budget: number
          user_id: string | null
        }
        Insert: {
          id?: string
          month: string
          total_budget: number
          user_id?: string | null
        }
        Update: {
          id?: string
          month?: string
          total_budget?: number
          user_id?: string | null
        }
        Relationships: []
      }
      category_budgets: {
        Row: {
          budget_amount: number
          category: string
          id: string
          month: string
          user_id: string | null
        }
        Insert: {
          budget_amount: number
          category: string
          id?: string
          month: string
          user_id?: string | null
        }
        Update: {
          budget_amount?: number
          category?: string
          id?: string
          month?: string
          user_id?: string | null
        }
        Relationships: []
      }
      category_targets: {
        Row: {
          category_name: string
          created_at: string | null
          id: string
          target_amount: number
          user_id: string | null
        }
        Insert: {
          category_name: string
          created_at?: string | null
          id?: string
          target_amount: number
          user_id?: string | null
        }
        Update: {
          category_name?: string
          created_at?: string | null
          id?: string
          target_amount?: number
          user_id?: string | null
        }
        Relationships: []
      }
      chat_history: {
        Row: {
          content: string
          created_at: string | null
          id: string
          role: string | null
          user_id: string | null
        }
        Insert: {
          content: string
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string | null
        }
        Update: {
          content?: string
          created_at?: string | null
          id?: string
          role?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      custom_categories: {
        Row: {
          color: string
          created_at: string | null
          emoji: string
          id: string
          name: string
          target_amount: number | null
          user_id: string | null
        }
        Insert: {
          color: string
          created_at?: string | null
          emoji: string
          id?: string
          name: string
          target_amount?: number | null
          user_id?: string | null
        }
        Update: {
          color?: string
          created_at?: string | null
          emoji?: string
          id?: string
          name?: string
          target_amount?: number | null
          user_id?: string | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          id: string
          created_at: string | null
          expo_push_token: string | null
          budget_alert_threshold: number | null
          financial_goal: string | null
        }
        Insert: {
          id: string
          created_at?: string | null
          expo_push_token?: string | null
          budget_alert_threshold?: number | null
          financial_goal?: string | null
        }
        Update: {
          id?: string
          created_at?: string | null
          expo_push_token?: string | null
          budget_alert_threshold?: number | null
          financial_goal?: string | null
        }
        Relationships: []
      }
      recurring_transactions: {
        Row: {
          amount: number
          category: string
          created_at: string | null
          day_of_month: number | null
          day_of_week: number | null
          frequency: string | null
          id: string
          is_active: boolean | null
          next_due: string
          title: string
          type: string | null
          user_id: string | null
        }
        Insert: {
          amount: number
          category: string
          created_at?: string | null
          day_of_month?: number | null
          day_of_week?: number | null
          frequency?: string | null
          id?: string
          is_active?: boolean | null
          next_due: string
          title: string
          type?: string | null
          user_id?: string | null
        }
        Update: {
          amount?: number
          category?: string
          created_at?: string | null
          day_of_month?: number | null
          day_of_week?: number | null
          frequency?: string | null
          id?: string
          is_active?: boolean | null
          next_due?: string
          title?: string
          type?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      transactions: {
        Row: {
          amount: number
          category: string
          created_at: string
          id: string
          latitude: number | null
          location_name: string | null
          longitude: number | null
          title: string
          type: string
          user_id: string | null
          wallet_id: string | null
          is_transfer: boolean | null
          transfer_group_id: string | null
        }
        Insert: {
          amount: number
          category: string
          created_at?: string
          id?: string
          latitude?: number | null
          location_name?: string | null
          longitude?: number | null
          title: string
          type: string
          user_id?: string | null
          wallet_id?: string | null
          is_transfer?: boolean | null
          transfer_group_id?: string | null
        }
        Update: {
          amount?: number
          category?: string
          created_at?: string
          id?: string
          latitude?: number | null
          location_name?: string | null
          longitude?: number | null
          title?: string
          type?: string
          user_id?: string | null
          wallet_id?: string | null
          is_transfer?: boolean | null
          transfer_group_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "transactions_wallet_id_fkey"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
        ]
      }
      wallets: {
        Row: {
          balance: number
          icon_name: string
          id: string
          name: string
          user_id: string | null
        }
        Insert: {
          balance?: number
          icon_name: string
          id?: string
          name: string
          user_id?: string | null
        }
        Update: {
          balance?: number
          icon_name?: string
          id?: string
          name?: string
          user_id?: string | null
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never
