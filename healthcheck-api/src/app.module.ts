import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthcheckController } from './controllers/healthcheck.controller.js';
import { HealthcheckService } from './services/healthcheck.service.js';
import { MetricsController } from './controllers/metrics.controller.js';
import { MariaDBService } from './services/mariadb.service.js';
import {LoggerModule} from "@common/logger/logger.module";
import {PrometheusModule} from "@common/prometheus/prometheus.module";

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), LoggerModule],
  controllers: [HealthcheckController, MetricsController],
  providers: [
    HealthcheckService,
    MariaDBService,
    PrometheusModule,
  ],
})
export class AppModule {}
