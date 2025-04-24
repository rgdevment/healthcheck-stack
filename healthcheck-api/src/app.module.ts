import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthcheckController } from './healthcheck.controller';
import { HealthcheckService } from './healthcheck.service';
import { PrometheusModule } from '@willsoto/nestjs-prometheus';
import { Registry, collectDefaultMetrics } from 'prom-client';
import { MetricsController } from './metrics.controller';
import { dbProvider } from './db.provider';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrometheusModule.register(),
  ],
  controllers: [HealthcheckController, MetricsController],
  providers: [
    HealthcheckService,
    {
      provide: 'PrometheusRegistry',
      useValue: (() => {
        const registry = new Registry();
        collectDefaultMetrics({ register: registry });
        return registry;
      })(),
    },
    dbProvider,
  ],
})
export class AppModule {}
