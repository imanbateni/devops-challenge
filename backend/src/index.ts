import express from 'express';
import { Pool } from 'pg';
import axios from 'axios';
import { z } from 'zod';

// Validation schemas
const createUserSchema = z.object({
  username: z.string().min(3).max(50),
  email: z.string().email()
});

// Vault configuration
interface VaultConfig {
  url: string;
  roleId: string;
  secretId: string;
}

interface DatabaseCredentials {
  username: string;
  password: string;
}

class VaultClient {
  private token?: string;
  private config: VaultConfig;

  constructor(config: VaultConfig) {
    this.config = config;
  }

  async authenticate(): Promise<void> {
    try {
      const response = await axios.post(
        `${this.config.url}/v1/auth/approle/login`,
        {
          role_id: this.config.roleId,
          secret_id: this.config.secretId
        }
      );
      this.token = response.data.auth.client_token;
      console.log('Successfully authenticated with Vault');
    } catch (error) {
      console.error('Failed to authenticate with Vault:', error);
      throw error;
    }
  }

  async getSecret(path: string): Promise<any> {
    if (!this.token) {
      throw new Error('Not authenticated with Vault');
    }

    try {
      const response = await axios.get(
        `${this.config.url}/v1/${path}`,
        {
          headers: {
            'X-Vault-Token': this.token
          }
        }
      );
      return response.data.data.data;
    } catch (error) {
      console.error('Failed to retrieve secret from Vault:', error);
      throw error;
    }
  }
}

class DatabaseManager {
  private pool: Pool;

  constructor(pool: Pool) {
    this.pool = pool;
  }

  async initialize(): Promise<void> {
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `;

    try {
      await this.pool.query(createTableQuery);
      console.log('Database initialized successfully');
    } catch (error) {
      console.error('Failed to initialize database:', error);
      throw error;
    }
  }

  async createUser(username: string, email: string): Promise<any> {
    const query = 'INSERT INTO users (username, email) VALUES ($1, $2) RETURNING *';
    const result = await this.pool.query(query, [username, email]);
    return result.rows[0];
  }

  async getUsers(): Promise<any[]> {
    const result = await this.pool.query('SELECT * FROM users ORDER BY created_at DESC');
    return result.rows;
  }

  async checkConnection(): Promise<boolean> {
    try {
      await this.pool.query('SELECT 1');
      return true;
    } catch {
      return false;
    }
  }
}

async function getDatabaseCredentials(): Promise<DatabaseCredentials> {
  if (process.env.VAULT_ADDR && process.env.VAULT_ROLE_ID && process.env.VAULT_SECRET_ID) {
    try {
      const vaultClient = new VaultClient({
        url: process.env.VAULT_ADDR,
        roleId: process.env.VAULT_ROLE_ID,
        secretId: process.env.VAULT_SECRET_ID
      });

      await vaultClient.authenticate();
      const secrets = await vaultClient.getSecret('secret/data/database/postgres');
      
      return {
        username: secrets.username,
        password: secrets.password
      };
    } catch (error) {
      console.warn('Failed to retrieve credentials from Vault, falling back to environment variables');
    }
  }

  if (!process.env.DB_USER || !process.env.DB_PASSWORD) {
    throw new Error('Database credentials not found in Vault or environment variables');
  }

  return {
    username: process.env.DB_USER,
    password: process.env.DB_PASSWORD
  };
}

async function createApp(): Promise<express.Application> {
  const app = express();
  app.use(express.json());

  const credentials = await getDatabaseCredentials();

  const pool = new Pool({
    host: process.env.DB_HOST || 'postgres',
    port: parseInt(process.env.DB_PORT || '5432'),
    database: process.env.DB_NAME || 'userdb',
    user: credentials.username,
    password: credentials.password,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
  });

  const dbManager = new DatabaseManager(pool);

  await dbManager.initialize();

  app.get('/api/health', async (_req, res) => {
    const dbConnected = await dbManager.checkConnection();
    const health = {
      status: dbConnected ? 'healthy' : 'degraded',
      timestamp: new Date().toISOString(),
      services: {
        api: 'running',
        database: dbConnected ? 'connected' : 'disconnected'
      }
    };

    res.status(dbConnected ? 200 : 503).json(health);
  });

  app.post('/api/users', async (req, res) => {
    try {
      const validatedData = createUserSchema.parse(req.body);
      const user = await dbManager.createUser(
        validatedData.username,
        validatedData.email
      );

      res.status(201).json({
        success: true,
        data: user
      });
    } catch (error: unknown) {
      if (error instanceof z.ZodError) {
        res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: error.errors
        });
      } else if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        (error as any).code === '23505'
      ) {
        res.status(409).json({
          success: false,
          error: 'User already exists with this username or email'
        });
      } else {
        console.error('Error creating user:', error);
        res.status(500).json({
          success: false,
          error: 'Internal server error'
        });
      }
    }
  });

  app.get('/api/users', async (_req, res) => {
    try {
      const users = await dbManager.getUsers();
      res.json({
        success: true,
        data: users,
        count: users.length
      });
    } catch (error) {
      console.error('Error fetching users:', error);
      res.status(500).json({
        success: false,
        error: 'Internal server error'
      });
    }
  });

  app.use((_req, res) => {
    res.status(404).json({
      success: false,
      error: 'Endpoint not found'
    });
  });

  app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
      success: false,
      error: 'Internal server error'
    });
  });

  return app;
}

async function start() {
  try {
    const app = await createApp();
    const port = parseInt(process.env.PORT || '3000');

    app.listen(port, '0.0.0.0', () => {
      console.log(`Backend service started on port ${port}`);
      console.log('Available endpoints:');
      console.log('  - GET  /api/health');
      console.log('  - GET  /api/users');
      console.log('  - POST /api/users');
    });
  } catch (error) {
    console.error('Failed to start application:', error);
    process.exit(1);
  }
}

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully...');
  process.exit(0);
});

start();
