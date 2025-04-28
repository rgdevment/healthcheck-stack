import { Module, Global } from '@nestjs/common';
import { AppLogger } from './logger.service.js';

@Global()
@Module({
  providers: [AppLogger],
  exports: [AppLogger],
})
export class LoggerModule {}
