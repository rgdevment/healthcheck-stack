import { Module } from '@nestjs/common';
import { AppLogger } from './logger.service.js';

@Module({
  providers: [AppLogger],
  exports: [AppLogger],
})
export class LoggerModule {}
