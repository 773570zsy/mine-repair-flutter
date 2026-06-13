# mine_repair_flutter — 矿山维修 Flutter App

## 项目
- **目标**: Flutter 三端（Android + iOS + Web + Windows）覆盖矿山维修系统全部功能
- **后端**: `C:\Users\Administrator\mine_repair_flutter\backend`（项目自带独立后端，不依赖 mine-repair-app）
- **当前状态**: 全部 7 阶段 + 维修预算模块完成，编译通过

## 启动
```bash
# 后端（端口 3000）
cd C:\Users\Administrator\mine_repair_flutter\backend && npm run dev

# Flutter Web 开发（端口 5555）
# ⚠️ 每次改代码必须：杀进程 + 清缓存 + 重启（热重载不响应结构性变更）
cd C:\Users\Administrator\mine_repair_flutter
rm -rf .dart_tool/flutter_build
flutter run -d web-server --web-port 5555 --web-hostname 0.0.0.0

# Windows 桌面
flutter run -d windows

# 构建
flutter build web      # Web
flutter build windows  # Windows 桌面
```

## 技术栈
- Flutter 3.44.0 / Dart 3.12.0
- flutter_riverpod 2.6.x / go_router 14.x / dio 5.x
- flutter_secure_storage / image_picker / cached_network_image

## 代码结构（67+ Dart 文件）
```
lib/
├── main.dart                     ← 入口（ProviderScope）
├── app.dart                      ← MaterialApp.router（dark theme, zh locale）
├── config/
│   ├── api_config.dart           ← API 基址（localhost:3000 / jlkydds.cn）
│   ├── color_constants.dart      ← 统一颜色（bg/surface/border/text/gold/danger/...）
│   ├── constants.dart            ← 角色/状态映射
│   ├── routes.dart               ← GoRouter 全套路由（~40条）
│   └── guards.dart               ← 角色路由守卫
├── models/                       ← 数据模型（fromJson/toJson）共14个
├── services/                     ← 后端 API 封装（Dio + JWT）共13个
├── providers/                    ← Riverpod 状态管理 共9个
└── pages/
    ├── login/                    ← 登录页
    ├── home/                     ← 7种角色仪表盘（driver/shop/leader/admin/safety/applicant/dispatcher）
    ├── repair/                   ← 维修流程 9页
    ├── hazard/                   ← 隐患闭环 3页
    ├── safety/                   ← 考核通报 3页
    ├── inspection/               ← 点检/考勤/配件 10页
    ├── vehicle_archive/          ← 车辆档案 3页
    ├── weather/                  ← 天气预警 4页
    ├── machinery/                ← 工程机械 9页
    ├── ledger/                   ← 单车核算 7页
    │   ├── ledger_home_page.dart    ← 仪表盘+导航
    │   ├── monthly_ledger_page.dart ← 月度清单生成/提交/审批
    │   ├── kpi_ranking_page.dart    ← KPI排名
    │   ├── threshold_config_page.dart ← KPI阈值配置
    │   ├── budget_page.dart         ← 维修预算仪表盘（2026-06-11新增）
    │   ├── budget_config_page.dart  ← 车型增幅率配置
    │   └── budget_import_page.dart  ← 基准数据导入
    ├── admin/                    ← 管理后台 8页
    ├── profile/                  ← 个人中心
    ├── notification/             ← 消息通知
    └── photo_history_page.dart  ← 【2026-06-13新增】照片历史查看器（5年追溯+年月筛选+网格）
```

## API 格式
- 返回格式: `{code:200, msg, data}` 统一包装
- JWT: `Authorization: Bearer <token>`
- 文件上传: multipart/form-data
- 照片URL: 拼接 `ApiConfig.fileUrl()`

## 预置测试账号
| 角色 | 手机号 | 密码 |
|------|--------|------|
| 超管 | 15129505737 | zsyjw773570 |
| 管理员 | 13900000000 | 123456 |
| 驾驶员 | 13900000001 | 123456 |
| 安全员 | 13900000111 | 123456 |

## 已知待办
1. ~~**照片历史查看器**~~ — 2026-06-13 已完成
2. ~~**后端加固**~~ — 2026-06-13: better-sqlite3+Zod+Pino+70 tests
3. ~~**CI/CD 部署流水线**~~ — 2026-06-13: GitHub Actions push→test→deploy
4. **原生打包** — Android APK + iOS IPA + Windows EXE

## 维修预算模块
- 公式: 月预算 = 基准月费 × (1+增幅率)^(今年−基准年) × (1+增幅率×车龄/10)
- 不含燃油费，只计维修费+配件领用
- 15种车型已预设，增幅率默认5%可调
- 后端API在 `ledger.routes.ts`，数据库表在 `schema.ts`
- Flutter模型: `lib/models/budget.dart`

## 颜色（Web 一致）
bg=#1a1d23, surface=#242830, border=#3a3f4a, text=#d0d4dc, text2=#9098a6, gold=#c8a04a, warning=#d4a017, danger=#e05555, success=#5a9e5f

## 题库
- **180题**，29个类别，答案A/B/C/D均匀分布（~23%/18%/28%/31%）
- 导入脚本: `backend/seed_all_quiz.py`（合并自 reseed_quiz/add_questions/add_safety_qs/add_redline_qs）
- 每天随机抽5题，约36天一循环
- 同步到云服务器: `scp data/mine_repair.db root@162.14.75.235:/opt/mine-repair-app/backend/data/`

## 开发规则
- 不改后端代码
- 不改 pubspec.yaml 依赖（除非明确需要）
- **每次代码改动后**：杀旧进程 → 清 `.dart_tool/flutter_build` → 重启 dev server（Flutter web-server 热重载不响应结构性变更）
- 颜色用 AppColors 常量，不硬编码
- 角色路由守卫在 guards.dart 统一管理
- 先确认再动手（参见 memory 协作方式）
