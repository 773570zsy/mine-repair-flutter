import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';

const router = Router();

// 照片来源定义（表 + 字段 + 日期字段 + 标签）
const PHOTO_SOURCES = [
  { table: 'repair_orders',       field: 'fault_images',  dateField: 'created_at',      type: 'repair',        label: '维修报修' },
  { table: 'daily_inspections',   field: 'photos',        dateField: 'inspection_date', type: 'inspection',    label: '点检' },
  { table: 'hazards',             field: 'photos_before', dateField: 'created_at',      type: 'hazard_before', label: '隐患(整改前)' },
  { table: 'hazards',             field: 'photos_after',  dateField: 'created_at',      type: 'hazard_after',  label: '隐患(整改后)' },
  { table: 'assessments',         field: 'photos',        dateField: 'created_at',      type: 'assessment',    label: '考核通报' },
  { table: 'vehicle_archives',    field: 'photos',        dateField: 'created_at',      type: 'vehicle',       label: '车辆档案' },
  { table: 'repair_progress',     field: 'images',        dateField: 'created_at',      type: 'progress',      label: '维修进度' },
  { table: 'repair_quotes',       field: 'damage_photos', dateField: 'created_at',      type: 'quote_damage',  label: '报价(损坏件)' },
  { table: 'repair_quotes',       field: 'new_photos',    dateField: 'created_at',      type: 'quote_new',     label: '报价(新配件)' },
  { table: 'external_repair_orders', field: 'fault_images', dateField: 'created_at',   type: 'external',      label: '外部报修' },
  { table: 'external_repair_progress', field: 'images',   dateField: 'created_at',      type: 'ext_progress',  label: '外部维修进度' },
  { table: 'machinery_applications', field: 'briefing_files', dateField: 'created_at', type: 'machinery',     label: '工程机械' },
];

/**
 * GET /api/photos/history?year=2026&month=6&page=1&limit=50
 *
 * 聚合查询所有表中的照片，按日期倒序，支持年月筛选 + 分页
 */
router.get('/history', auth, asyncHandler(async (req: Request, res: Response) => {
  const year = (req.query.year as string) || '';
  const month = (req.query.month as string) || '';
  const page = Math.max(1, parseInt(req.query.page as string) || 1);
  const limit = Math.min(Math.max(1, parseInt(req.query.limit as string) || 50), 100);
  const offset = (page - 1) * limit;

  // 构建日期筛选条件
  let dateWhere = '';
  const params: string[] = [];
  if (year) {
    if (month && month !== '0') {
      dateWhere = `AND strftime('%Y-%m', __DATE_FIELD__) = ?`;
      params.push(`${year}-${month.padStart(2, '0')}`);
    } else {
      dateWhere = `AND strftime('%Y', __DATE_FIELD__) = ?`;
      params.push(year);
    }
  }

  const allPhotos: Array<{
    url: string;
    source_type: string;
    source_label: string;
    record_date: string;
    record_id: number;
  }> = [];

  const db = getDB();

  for (const src of PHOTO_SOURCES) {
    try {
      const where = dateWhere.replace(/__DATE_FIELD__/g, src.dateField);
      const sql = `SELECT ${src.field} AS photos, ${src.dateField} AS record_date, id AS record_id
                   FROM ${src.table}
                   WHERE ${src.field} IS NOT NULL AND ${src.field} != '' AND ${src.field} != '[]'
                   ${where}`;
      const rows = db.prepare(sql).all(...params) as any[];

      for (const row of rows) {
        try {
          const urls = JSON.parse(row.photos as string);
          if (!Array.isArray(urls)) continue;
          for (const url of urls) {
            if (url && typeof url === 'string' && url.trim()) {
              allPhotos.push({
                url: url.trim(),
                source_type: src.type,
                source_label: src.label,
                record_date: row.record_date || '',
                record_id: row.record_id,
              });
            }
          }
        } catch { /* 跳过无效 JSON */ }
      }
    } catch { /* 跳过不存在的表或字段 */ }
  }

  // 按日期倒序
  allPhotos.sort((a, b) => b.record_date.localeCompare(a.record_date));

  // 分页
  const total = allPhotos.length;
  const items = allPhotos.slice(offset, offset + limit);

  res.json({
    code: 200,
    data: { items, total, page, limit, totalPages: Math.ceil(total / limit) },
  });
}));

export default router;
