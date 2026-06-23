import https from 'https';
import logger from '../utils/logger';

// ============================================================
//  极光推送 REST API v3 封装
//  文档: https://docs.jiguang.cn/jpush/server/push/rest_api_v3_push
// ============================================================

const JPUSH_CONFIG = {
  appKey: '113e14960cc6c1614b818614',
  masterSecret: '0e478a6c79c30908572e10c6',
  apnsProduction: process.env.NODE_ENV === 'production',
};

const BASIC_AUTH = Buffer.from(
  `${JPUSH_CONFIG.appKey}:${JPUSH_CONFIG.masterSecret}`
).toString('base64');

interface PushOptions {
  title: string;
  content: string;
  alias?: string[];       // 按别名推送（手机号）
  tags?: string[];        // 按标签推送（role_xxx）
  extras?: Record<string, string>;  // 附加字段（如 orderId）
}

function buildPushPayload(opts: PushOptions) {
  const audience: Record<string, any> = {};
  if (opts.alias && opts.alias.length > 0) {
    audience.alias = opts.alias;
  }
  if (opts.tags && opts.tags.length > 0) {
    audience.tag = opts.tags;
  }

  const payload: any = {
    platform: 'all',
    audience: Object.keys(audience).length > 0 ? audience : 'all',
    notification: {
      android: {
        alert: opts.content,
        title: opts.title,
        builder_id: 1,
        channel_id: 'message',  // 必须与 Android 端 MainActivity 创建的渠道 ID 一致
        priority: 1,            // -2~2，1=高优先级，确保弹出悬浮通知
        style: 0,               // 0=默认通知样式
        extras: opts.extras || {},
      },
      ios: {
        alert: {
          title: opts.title,
          body: opts.content,
        },
        sound: 'default',
        badge: '+1',
        extras: opts.extras || {},
      },
    },
    options: {
      apns_production: JPUSH_CONFIG.apnsProduction,
      time_to_live: 86400, // 1天
    },
  };

  return payload;
}

function doPush(payload: any): Promise<boolean> {
  return new Promise((resolve) => {
    try {
      const body = JSON.stringify(payload);
      const req = https.request(
        {
          hostname: 'api.jpush.cn',
          path: '/v3/push',
          method: 'POST',
          headers: {
            'Authorization': `Basic ${BASIC_AUTH}`,
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(body),
          },
          timeout: 10000,
        },
        (res) => {
          let data = '';
          res.on('data', (chunk: Buffer) => (data += chunk.toString()));
          res.on('end', () => {
            try {
              const result = JSON.parse(data);
              if (res.statusCode === 200 && !result.error) {
                logger.info({ msg_id: result.msg_id, sendno: result.sendno }, 'JPush push success');
                resolve(true);
              } else {
                logger.warn({ status: res.statusCode, result }, 'JPush push failed');
                resolve(false);
              }
            } catch {
              logger.warn({ status: res.statusCode, data }, 'JPush push parse error');
              resolve(false);
            }
          });
        }
      );
      req.on('error', (e: Error) => {
        logger.warn({ error: e.message }, 'JPush push network error');
        resolve(false);
      });
      req.on('timeout', () => {
        req.destroy();
        resolve(false);
      });
      req.write(body);
      req.end();
    } catch (e: any) {
      logger.warn({ error: e?.message }, 'JPush push exception');
      resolve(false);
    }
  });
}

/**
 * 按别名推送（单个用户，用手机号作别名）
 */
export async function pushToUser(
  phone: string,
  title: string,
  content: string,
  extras?: Record<string, string>
): Promise<void> {
  await doPush(buildPushPayload({ title, content, alias: [phone], extras }));
}

/**
 * 按别名批量推送（多个用户）
 */
export async function pushToUsers(
  phones: string[],
  title: string,
  content: string,
  extras?: Record<string, string>
): Promise<void> {
  if (phones.length === 0) return;
  // JPush 单次最多 1000 个别名
  const batchSize = 500;
  for (let i = 0; i < phones.length; i += batchSize) {
    const batch = phones.slice(i, i + batchSize);
    await doPush(buildPushPayload({ title, content, alias: batch, extras }));
  }
}

/**
 * 按标签推送（角色群推）
 * tag: role_admin, role_driver, etc.
 */
export async function pushToTag(
  tag: string,
  title: string,
  content: string,
  extras?: Record<string, string>
): Promise<void> {
  await doPush(buildPushPayload({ title, content, tags: [tag], extras }));
}

/**
 * 全量推送（所有已注册设备）
 */
export async function pushToAll(
  title: string,
  content: string,
  extras?: Record<string, string>
): Promise<void> {
  await doPush(buildPushPayload({ title, content, extras }));
}
