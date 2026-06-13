import ExcelJS from 'exceljs';
import { Response } from 'express';

/** Excel 样式常量 */
const STYLE = {
  headerFont: { bold: true, color: { argb: 'FFFFFFFF' }, size: 12 },
  headerFill: { type: 'pattern' as const, pattern: 'solid' as const, fgColor: { argb: 'FF2A2E38' } },
  headerBorder: { style: 'thin' as const, color: { argb: 'FF3A3F4A' } },
  cellBorder: { style: 'thin' as const, color: { argb: 'FFE0E0E0' } },
  currencyFormat: '#,##0.00',
  dateFormat: 'yyyy-mm-dd',
  datetimeFormat: 'yyyy-mm-dd hh:mm',
};

/** 列定义 */
export interface ColumnDef {
  header: string;
  key?: string;
  width?: number;
  style?: 'normal' | 'currency' | 'date' | 'datetime';
}

/** 生成并发送 Excel 文件 */
export async function sendExcel(
  res: Response,
  filename: string,
  sheetName: string,
  columns: ColumnDef[],
  rows: Record<string, unknown>[],
) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = '总调度室综合管理系统';
  const sheet = workbook.addWorksheet(sheetName);

  // 设置列
  sheet.columns = columns.map(col => ({
    header: col.header,
    key: col.key || col.header,
    width: col.width || 16,
  }));

  // 写入数据行
  rows.forEach(row => sheet.addRow(row));

  // === 样式美化 ===
  // 表头行
  const headerRow = sheet.getRow(1);
  headerRow.height = 28;
  headerRow.eachCell((cell, _colNumber) => {
    cell.font = STYLE.headerFont;
    cell.fill = STYLE.headerFill;
    cell.border = {
      top: STYLE.headerBorder,
      left: STYLE.headerBorder,
      bottom: { style: 'medium', color: { argb: 'FFC8A04A' } },
      right: STYLE.headerBorder,
    };
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
  });

  // 数据行
  for (let i = 2; i <= sheet.rowCount; i++) {
    const row = sheet.getRow(i);
    row.height = 22;
    row.eachCell((cell, colNumber) => {
      const colDef = columns[colNumber - 1];
      // 边框
      cell.border = {
        top: STYLE.cellBorder,
        left: STYLE.cellBorder,
        bottom: STYLE.cellBorder,
        right: STYLE.cellBorder,
      };
      // 字体
      cell.font = { size: 11, color: { argb: 'FF333333' } };
      // 对齐
      if (colDef?.style === 'currency') {
        cell.alignment = { horizontal: 'right', vertical: 'middle' };
        cell.numFmt = STYLE.currencyFormat;
      } else if (colDef?.style === 'date') {
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
        cell.numFmt = STYLE.dateFormat;
      } else if (colDef?.style === 'datetime') {
        cell.alignment = { horizontal: 'center', vertical: 'middle' };
        cell.numFmt = STYLE.datetimeFormat;
      } else {
        cell.alignment = { vertical: 'middle', wrapText: true };
      }
    });
  }

  // 冻结首行
  sheet.views = [{ state: 'frozen', ySplit: 1 }];

  // 输出
  res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"`);
  await workbook.xlsx.write(res);
  res.end();
}
