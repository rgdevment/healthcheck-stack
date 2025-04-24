import mariadb from 'mariadb';

export const dbProvider = {
  provide: 'MARIADB_POOL',
  useFactory: async () => {
    return mariadb.createPool({
      host: process.env.MYSQL_HOST,
      port: Number(process.env.MYSQL_PORT),
      user: process.env.MYSQL_USER || 'root',
      password: process.env.MYSQL_ROOT_PASSWORD,
      database: process.env.MYSQL_DATABASE,
      ssl: false,
      connectionLimit: 5,
    });
  },
};
