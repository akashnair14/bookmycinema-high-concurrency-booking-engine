import Redis from 'ioredis';
import dotenv from 'dotenv';

dotenv.config();

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REDIS_PORT = Number(process.env.REDIS_PORT) || 6379;
const REDIS_PASSWORD = process.env.REDIS_PASSWORD || undefined;

export interface ICacheClient {
  eval(script: string, numKeys: number, ...args: (string | number)[]): Promise<any>;
  set(key: string, value: string, ...args: any[]): Promise<any>;
  get(key: string): Promise<string | null>;
  del(...keys: string[]): Promise<number>;
  quit(): Promise<'OK' | void>;
}

// In-memory fallback if Redis server is not actively running locally
class InMemoryRedisMock implements ICacheClient {
  private store = new Map<string, { val: string; expiresAt: number }>();

  async eval(script: string, numKeys: number, ...args: (string | number)[]): Promise<any> {
    const keys = args.slice(0, numKeys).map(String);
    const argv = args.slice(numKeys).map(String);
    const now = Date.now();

    // Check if script is the atomic multi-lock script
    if (script.includes('redis.call(\'EXISTS\'')) {
      const ttlMs = parseInt(argv[argv.length - 1], 10) * 1000;
      const userId = argv[0];

      // Check if any key is currently occupied
      for (const k of keys) {
        const item = this.store.get(k);
        if (item && item.expiresAt > now) {
          return 0; // Lock acquisition failed
        }
      }

      // Lock all keys
      for (const k of keys) {
        this.store.set(k, { val: userId, expiresAt: now + ttlMs });
      }
      return 1; // All keys locked successfully
    }

    // Release script
    if (script.includes('redis.call(\'GET\'')) {
      const userId = argv[0];
      let released = 0;
      for (const k of keys) {
        const item = this.store.get(k);
        if (item && item.val === userId) {
          this.store.delete(k);
          released++;
        }
      }
      return released;
    }

    return 0;
  }

  async set(key: string, value: string, mode?: string, duration?: number, flag?: string): Promise<string | null> {
    const now = Date.now();
    const item = this.store.get(key);
    if (flag === 'NX' && item && item.expiresAt > now) {
      return null;
    }
    const expiresAt = duration ? now + duration * 1000 : Infinity;
    this.store.set(key, { val: value, expiresAt });
    return 'OK';
  }

  async get(key: string): Promise<string | null> {
    const item = this.store.get(key);
    if (!item) return null;
    if (item.expiresAt < Date.now()) {
      this.store.delete(key);
      return null;
    }
    return item.val;
  }

  async del(...keys: string[]): Promise<number> {
    let count = 0;
    for (const k of keys) {
      if (this.store.delete(k)) count++;
    }
    return count;
  }

  async quit(): Promise<'OK'> {
    this.store.clear();
    return 'OK';
  }
}

const inMemoryInstance = new InMemoryRedisMock();
let cachedClient: ICacheClient | null = null;
let connectionAttempted = false;

export const getCacheClient = async (): Promise<ICacheClient> => {
  if (cachedClient) {
    return cachedClient;
  }

  if (connectionAttempted) {
    return inMemoryInstance;
  }

  connectionAttempted = true;

  try {
    const realRedis = new Redis({
      host: REDIS_HOST,
      port: REDIS_PORT,
      password: REDIS_PASSWORD,
      lazyConnect: true,
      maxRetriesPerRequest: 1,
      connectTimeout: 500,
      retryStrategy: () => null,
    });

    realRedis.on('error', () => {
      // Suppress unhandled connection errors
    });

    await realRedis.connect();
    await realRedis.ping();
    console.log('⚡ Connected to live Redis instance successfully.');
    cachedClient = realRedis as unknown as ICacheClient;
    return cachedClient;
  } catch {
    console.warn('⚠️  Redis server unavailable. Utilizing atomic in-memory cache engine for high-concurrency simulation.');
    cachedClient = inMemoryInstance;
    return cachedClient;
  }
};

