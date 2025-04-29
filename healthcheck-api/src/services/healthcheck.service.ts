import { Injectable } from '@nestjs/common';
import * as redis from 'redis';
import axios from 'axios';
import { MariaDBService } from './mariadb.service.js';
import { AppLogger } from '@common/logger/logger.service.js';

@Injectable()
export class HealthcheckService {
  constructor(
    private readonly mariadbService: MariaDBService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext('HealthcheckService');
  }

  getPing() {
    return {
      status: 'ok',
      message: 'pong',
      timestamp: new Date().toISOString(),
    };
  }

  async checkExternalDependencies(): Promise<Record<string, 'ok' | 'error'>> {
    const dependencies: Record<string, 'ok' | 'error'> = {};

    const urls = {
      retrieveCountries: process.env.API_RETRIEVE_COUNTRIES || '',
      indicadoresChile: process.env.API_INDICADORES_CHILE || '',
    };

    this.logger.log(`URLs a consultar: ${urls.retrieveCountries}`);
    this.logger.log(`URLs a consultar: ${urls.indicadoresChile}`);

    for (const [name, url] of Object.entries(urls)) {
      try {
        if (!url) {
          this.logger.error(`No URL configured for ${name}`);
          dependencies[name] = 'error';
          continue;
        }

        const res = await axios.get(url, { timeout: 5000 });

        if (res.status === 200 && res.data?.status === 'ok') {
          dependencies[name] = 'ok';
        } else {
          dependencies[name] = 'error';
        }
      } catch (error) {
        // @ts-ignore
        this.logger.error(`Error checking ${name}:`, error.message || error);
        dependencies[name] = 'error';
      }
    }

    return dependencies;
  }

  getTime() {
    return { now: new Date().toString() };
  }

  async checkMySQL() {
    try {
      const conn = await this.mariadbService.getConnection();
      await conn.query('SELECT 1');
      await conn.release();
      return { mysql: 'ok' };
    } catch (err) {
      this.logger.error('MySQL ERROR', err);
      return { mysql: 'error' };
    }
  }

  async checkRedis() {
    try {
      const client = redis.createClient({
        socket: {
          host: process.env.REDIS_HOST || 'localhost',
          port: parseInt(process.env.REDIS_PORT || '6379'),
        },
      });
      await client.connect();
      await client.ping();
      await client.disconnect();
      return { redis: 'ok' };
    } catch (err) {
      this.logger.error('REDIS ERROR', err);
      return { redis: 'error' };
    }
  }

  async checkGrafana() {
    try {
      const res = await axios.get(`${process.env.GRAFANA_URL}/login`);
      return { grafana: res.status === 200 ? 'ok' : 'unreachable' };
    } catch (err) {
      this.logger.error('GRAFANA ERROR', err);
      return { grafana: 'error' };
    }
  }
}
