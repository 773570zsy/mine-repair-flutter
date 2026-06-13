import { getDB } from '../db';
import { User } from '../models';

export class UserRepository {
  findByPhone(phone: string): User | undefined {
    return getDB().prepare('SELECT * FROM users WHERE phone = ?').get(phone) as User | undefined;
  }

  findById(id: number): User | undefined {
    return getDB().prepare('SELECT id, name, phone, role, repair_shop_id, avatar_url, department_id FROM users WHERE id = ?').get(id) as User | undefined;
  }

  findByIdWithPassword(id: number): User | undefined {
    return getDB().prepare('SELECT * FROM users WHERE id = ?').get(id) as User | undefined;
  }

  findByRole(role: string): User[] {
    return getDB().prepare('SELECT id, name, phone FROM users WHERE role = ? AND status = 1 ORDER BY name').all(role) as unknown as User[];
  }

  updatePassword(id: number, hash: string): void {
    getDB().prepare(`UPDATE users SET password = ?, updated_at = datetime('now') WHERE id = ?`).run(hash, id);
  }

  create(data: { name: string; phone: string; role: string; repair_shop_id?: number | null; department_id?: number | null }): number {
    const result = getDB().prepare(
      'INSERT INTO users (name, phone, role, repair_shop_id, department_id) VALUES (?, ?, ?, ?, ?)'
    ).run(data.name, data.phone || '', data.role, data.repair_shop_id || null, data.department_id || null);
    return result.lastInsertRowid as number;
  }
}

export const userRepo = new UserRepository();
