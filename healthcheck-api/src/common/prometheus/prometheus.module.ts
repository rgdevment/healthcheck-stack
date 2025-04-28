import { Module } from '@nestjs/common';
import { createPrometheusRegistry } from '@common/prometheus/prometheus.provider.js';

@Module({
  providers: [
    {
      provide: 'PrometheusRegistry',
      useValue: createPrometheusRegistry(),
    },
  ],
  exports: ['PrometheusRegistry'],
})
export class PrometheusModule {}
