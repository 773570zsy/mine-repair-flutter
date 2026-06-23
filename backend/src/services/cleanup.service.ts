import fs from 'fs';
import path from 'path';
import { getDB } from '../db';
import logger from '../utils/logger';

const UPLOAD_DIR = path.join(__dirname, '../../uploads');

const PHOTO_FIELDS = [
  { table: 'repair_orders',          field: 'fault_images' },
  { table: 'daily_inspections',      field: 'photos' },
  { table: 'hazards',                field: 'photos_before' },
  { table: 'hazards',                field: 'photos_after' },
  { table: 'assessments',            field: 'photos' },
  { table: 'vehicle_archives',       field: 'photos' },
  { table: 'repair_progress',        field: 'images' },
  { table: 'repair_quotes',          field: 'damage_photos' },
  { table: 'repair_quotes',          field: 'new_photos' },
  { table: 'external_repair_orders', field: 'fault_images' },
  { table: 'external_repair_progress', field: 'images' },
  { table: 'machinery_applications', field: 'briefing_files' },
];

/** 收集数据库中所有被引用文件的相对路径（如 2026/06/xxx.jpg） */
export function collectReferencedFiles(): Set<string> {
  const refs = new Set<string>();
  const db = getDB();
  for (const src of PHOTO_FIELDS) {
    try {
      const rows = db.prepare(
        `SELECT ${src.field} AS photos FROM ${src.table} WHERE ${src.field} IS NOT NULL AND ${src.field} != '' AND ${src.field} != '[]'`
      ).all() as any[];
      for (const row of rows) {
        try {
          const urls: string[] = JSON.parse(row.photos as string);
          for (const url of urls) {
            if (url && typeof url === 'string') {
              // /uploads/2026/06/xxx.jpg → 2026/06/xxx.jpg
              // /uploads/xxx.jpg → xxx.jpg（兼容旧格式）
              const rel = url.replace(/^\/uploads\//, '').replace(/\\/g, '/');
              if (rel) refs.add(rel);
            }
          }
        } catch { /* 跳过无效JSON */ }
      }
    } catch { /* 跳过不存在的表 */ }
  }
  return refs;
}

/** 递归列出目录中所有文件（相对于 baseDir） */
function listFilesRecursive(dir: string, baseDir: string): string[] {
  const result: string[] = [];
  if (!fs.existsSync(dir)) return result;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      result.push(...listFilesRecursive(full, baseDir));
    } else if (entry.isFile()) {
      result.push(path.relative(baseDir, full).replace(/\\/g, '/'));
    }
  }
  return result;
}

/** 清理 uploads 目录中未被数据库引用的孤儿文件（支持年月子目录） */
export function cleanupOrphanUploads(): { deleted: number; freedBytes: number } {
  if (!fs.existsSync(UPLOAD_DIR)) return { deleted: 0, freedBytes: 0 };

  const allFiles = listFilesRecursive(UPLOAD_DIR, UPLOAD_DIR);
  if (allFiles.length === 0) return { deleted: 0, freedBytes: 0 };

  const refs = collectReferencedFiles();

  let deleted = 0;
  let freedBytes = 0;

  for (const rel of allFiles) {
    if (!refs.has(rel)) {
      const filePath = path.join(UPLOAD_DIR, rel);
      try {
        const stat = fs.statSync(filePath);
        if (stat.isFile()) {
          freedBytes += stat.size;
          fs.unlinkSync(filePath);
          deleted++;
        }
      } catch { /* 文件可能已被删除 */ }
    }
  }

  // 尝试删除空子目录
  for (const entry of fs.readdirSync(UPLOAD_DIR, { withFileTypes: true })) {
    if (entry.isDirectory()) {
      const subDir = path.join(UPLOAD_DIR, entry.name);
      try { fs.rmdirSync(subDir); } catch { /* 非空则跳过 */ }
    }
  }

  if (deleted > 0) {
    logger.info({ deleted, freedBytes, totalOnDisk: allFiles.length, referenced: refs.size }, 'Orphan uploads cleaned');
  }

  return { deleted, freedBytes };
}

/** 启动定时清理：每1小时自动扫描一次 */
export function startAutoCleanup(): void {
  // 启动后延迟30秒首次执行（等数据库完全初始化）
  setTimeout(() => {
    cleanupOrphanUploads();
    // 之后每小时一次
    setInterval(() => cleanupOrphanUploads(), 60 * 60 * 1000);
  }, 30_000);
}
