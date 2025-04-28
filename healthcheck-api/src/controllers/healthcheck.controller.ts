import { Controller, Get } from '@nestjs/common';
import { HealthcheckService } from '../services/healthcheck.service.js';
import {HealthcheckResponseDto} from "@common/dto/healthcheck-response.dto.js";

@Controller()
export class HealthcheckController {
  constructor(private readonly service: HealthcheckService) {}

  @Get()
  async getRootStatus(): Promise<HealthcheckResponseDto> {
    const [mysql, redis, grafana, external] = await Promise.all([
      this.timeoutPromise(this.checkMySQL(), 5000),
      this.timeoutPromise(this.checkRedis(), 5000),
      this.timeoutPromise(this.checkGrafana(), 5000),
      this.timeoutPromise(this.checkExternalDependencies(), 5000),
    ]);

    const services = {
      ...mysql,
      ...redis,
      ...grafana,
      ...external,
    };

    const hasError = Object.values(services).some((status) => status === 'error');

    return {
      status: hasError ? 'error' : 'ok',
      timestamp: new Date().toISOString(),
      services: services as Record<string, 'ok' | 'error'>,
    };
  }

  @Get('/ping/external')
  checkExternalDependencies() {
    return this.service.checkExternalDependencies();
  }

  @Get('/ping')
  ping() {
    return this.service.getPing();
  }

  @Get('/time')
  time() {
    return this.service.getTime();
  }

  @Get('/ping/db')
  checkMySQL() {
    return this.service.checkMySQL();
  }

  @Get('/ping/redis')
  checkRedis() {
    return this.service.checkRedis();
  }

  @Get('/ping/grafana')
  checkGrafana() {
    return this.service.checkGrafana();
  }

  private async timeoutPromise<T>(promise: Promise<T>, ms: number): Promise<T> {
    const timeout = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Timeout')), ms),
    );
    return Promise.race([promise, timeout]);
  }
}
