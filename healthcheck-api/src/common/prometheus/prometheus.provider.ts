import { Registry, collectDefaultMetrics } from 'prom-client';

export function createPrometheusRegistry(): Registry {
    const registry = new Registry();
    collectDefaultMetrics({ register: registry });
    return registry;
}
