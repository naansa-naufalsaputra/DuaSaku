import { supabase } from './supabase';
import { useUserStore } from '../store/useUserStore';

export type LogLevel = 'info' | 'warn' | 'error' | 'fatal';

interface LogContext {
  [key: string]: any;
}

class Logger {
  private async getUserId(): Promise<string | null> {
    try {
      const { data: { session } } = await supabase.auth.getSession();
      return session?.user?.id || null;
    } catch {
      return null;
    }
  }

  async log(level: LogLevel, message: string, error?: any, context: LogContext = {}) {
    const userId = await this.getUserId();
    
    // Always print to console in dev
    if (__DEV__) {
      const consoleMethod = level === 'fatal' ? 'error' : level;
      console[consoleMethod](`[${level.toUpperCase()}] ${message}`, error || '', context);
    }

    // Prepare log data
    const logData = {
      user_id: userId,
      level,
      message,
      stack: error instanceof Error ? error.stack : (typeof error === 'object' ? JSON.stringify(error) : String(error || '')),
      context: {
        ...context,
        device: 'mobile',
        timestamp: new Date().toISOString(),
      },
    };

    // Push to Supabase if internet available
    try {
      const { error: sbError } = await supabase.from('error_logs').insert(logData);
      if (sbError) {
        console.warn('[Logger] Failed to push log to Supabase:', sbError.message);
      }
    } catch (e) {
      // Fail silently to avoid infinite loops if supabase itself fails
      console.warn('[Logger] Network error while logging:', e);
    }
  }

  async info(message: string, context?: LogContext) {
    return this.log('info', message, undefined, context);
  }

  async warn(message: string, context?: LogContext) {
    return this.log('warn', message, undefined, context);
  }

  async error(message: string, error?: any, context?: LogContext) {
    return this.log('error', message, error, context);
  }

  async fatal(message: string, error?: any, context?: LogContext) {
    return this.log('fatal', message, error, context);
  }
}

export const logger = new Logger();
