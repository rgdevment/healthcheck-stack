import { Controller, Get } from '@nestjs/common';
import { HealthcheckService } from './healthcheck.service';

@Controller()
export class HealthcheckController {
  constructor(private readonly service: HealthcheckService) {}

  @Get()
  async getRootStatus() {
    const [mongo, mysql, redis, grafana] = await Promise.all([
      this.checkMongo(),
      this.checkMySQL(),
      this.checkRedis(),
      this.checkGrafana(),
    ]);

    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      services: {
        ...mongo,
        ...mysql,
        ...redis,
        ...grafana,
      },
    };
  }

  @Get('/ping')
  ping() {
    return this.service.getPing();
  }

  @Get('/time')
  time() {
    return this.service.getTime();
  }

  @Get('/ping/mongo')
  checkMongo() {
    return this.service.checkMongo();
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
}
