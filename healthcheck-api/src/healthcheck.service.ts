import { Inject, Injectable } from '@nestjs/common';
import * as redis from 'redis';
import axios from 'axios';

@Injectable()
export class HealthcheckService {
  @Inject('MARIADB_POOL') private readonly pool: { getConnection: () => any; end: () => any; };

  async getPing() {
    return {
      status: 'ok',
      message: 'pong',
      timestamp: new Date().toISOString(),
    };
  }

  getTime() {
    return { now: new Date().toString() };
  }

  async checkMySQL() {
    try {
      const conn = await this.pool.getConnection();
      await conn.query('SELECT 1');
      conn.release();
      await this.pool.end();
      return { mysql: 'ok' };
    } catch (err) {
      console.error('MySQL ERROR:', err);
      return { mysql: 'error' };
    }
  }
  async checkRedis() {
    try {
      const client = redis.createClient({
        socket: {
          host: process.env.REDIS_HOST,
          port: parseInt(process.env.REDIS_PORT),
        },
      });
      await client.connect();
      await client.ping();
      await client.disconnect();
      return { redis: 'ok' };
    } catch {
      return { redis: 'error' };
    }
  }

  async checkGrafana() {
    try {
      const res = await axios.get(`${process.env.GRAFANA_URL}/login`);
      return { grafana: res.status === 200 ? 'ok' : 'unreachable' };
    } catch {
      return { grafana: 'error' };
    }
  }
}
