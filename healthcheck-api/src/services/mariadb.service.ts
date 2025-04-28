import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import * as mariadb from 'mariadb';
import { AppLogger } from '@common/logger/logger.service.js';

@Injectable()
export class MariaDBService implements OnModuleInit, OnModuleDestroy {
  private pool!: mariadb.Pool;

  constructor(private readonly logger: AppLogger) {
    this.logger.setContext('MariaDBService');
  }

  async onModuleInit() {
    this.pool = mariadb.createPool({
      host: process.env.MYSQL_HOST,
      port: Number(process.env.MYSQL_PORT),
      user: process.env.MYSQL_USER || 'root',
      password: process.env.MYSQL_ROOT_PASSWORD,
      database: process.env.MYSQL_DATABASE,
      ssl: false,
      connectionLimit: 5,
    });

    const conn = await this.pool.getConnection();
    await conn.ping();
    await conn.release();
  }

  async onModuleDestroy() {
    if (this.pool && !this.pool.closed) {
      await this.pool.end();
    }
  }

  getPool() {
    return this.pool;
  }

  async getConnection() {
    if (!this.pool || this.pool.closed) {
      this.logger.error('MySQL ERROR', 'MariaDB pool is not initialized or already closed');
      throw new Error('MariaDB pool is not initialized or already closed');
    }
    return this.pool.getConnection();
  }
}
