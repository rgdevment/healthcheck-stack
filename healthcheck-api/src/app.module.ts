import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthcheckController } from './controllers/healthcheck.controller.js';
import { HealthcheckService } from './services/healthcheck.service.js';
import { MetricsController } from './controllers/metrics.controller.js';
import { MariaDBService } from './services/mariadb.service.js';
import { LoggerModule } from '@common/logger/logger.module.js';
import { PrometheusModule } from '@common/prometheus/prometheus.module.js';

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), LoggerModule, PrometheusModule],
  controllers: [HealthcheckController, MetricsController],
  providers: [HealthcheckService, MariaDBService],
})
export class AppModule {}
