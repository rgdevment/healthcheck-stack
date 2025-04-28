import { Injectable, LoggerService } from '@nestjs/common';

@Injectable()
export class AppLogger implements LoggerService {
  private context = 'App'; // Default context

  setContext(context: string) {
    this.context = context;
  }

  private formatContext(context?: string): string {
    return `[${context || this.context}]`;
  }

  private normalizeTrace(trace?: unknown): string {
    if (!trace) return '';
    if (typeof trace === 'string') return trace;
    if (trace instanceof Error) return trace.stack || trace.message;
    return JSON.stringify(trace);
  }

  log(message: any, context?: string) {
    console.log(`[LOG] ${this.formatContext(context)}`, message);
  }

  error(message: any, trace?: unknown, context?: string) {
    console.error(`[ERROR] ${this.formatContext(context)}`, message, this.normalizeTrace(trace));
  }

  warn(message: any, context?: string) {
    console.warn(`[WARN] ${this.formatContext(context)}`, message);
  }

  debug(message: any, context?: string) {
    if (process.env.NODE_ENV !== 'production') {
      console.debug(`[DEBUG] ${this.formatContext(context)}`, message);
    }
  }

  verbose(message: any, context?: string) {
    if (process.env.NODE_ENV !== 'production') {
      console.info(`[VERBOSE] ${this.formatContext(context)}`, message);
    }
  }
}
