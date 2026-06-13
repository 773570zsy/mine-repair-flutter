import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12;

/** 哈希密码 */
export function hashPassword(password: string): string {
  return bcrypt.hashSync(password, SALT_ROUNDS);
}

/** 验证密码 */
export function verifyPassword(password: string, hash: string): boolean {
  return bcrypt.compareSync(password, hash);
}

/** 兼容旧系统：检查是否为旧版SHA256哈希（无$前缀） */
export function isLegacyHash(hash: string): boolean {
  return !hash.startsWith('$');
}
