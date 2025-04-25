import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthcheckController } from './controllers/healthcheck.controller';
import { HealthcheckService } from './services/healthcheck.service';
import { PrometheusModule } from '@willsoto/nestjs-prometheus';
import { Registry, collectDefaultMetrics } from 'prom-client';
import { MetricsController } from './controllers/metrics.controller';
import {MariaDBService} from "./services/mariadb.service";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrometheusModule.register(),
  ],
  controllers: [HealthcheckController, MetricsController],
  providers: [
    HealthcheckService,
    MariaDBService,
    {
      provide: 'PrometheusRegistry',
      useValue: (() => {
        const registry = new Registry();
        collectDefaultMetrics({ register: registry });
        return registry;
      })(),
    },
  ],
})
export class AppModule {}
