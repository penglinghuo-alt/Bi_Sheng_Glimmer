# Task List: 下载帖子到存储库

## 1. 后端改动

- [ ] 1.1 `backend/models.py`: `BrailleRecord` 新增 `source_post_id` 列
- [ ] 1.2 `backend/schemas.py`: `BrailleRecordCreate` 与 `BrailleRecordResponse` 新增 `source_post_id` 字段
- [ ] 1.3 `backend/api/routers/records.py`: `create_record` 保存 `source_post_id`;`list_records`/`get_record`/`rename_record` 返回该字段
- [ ] 1.4 `backend/database.py`: `init_db` 后执行幂等 `ALTER TABLE` 迁移(兼容 MySQL/SQLite)
- [ ] 1.5 后端语法校验 + 本地启动验证迁移

## 2. 前端改动

- [ ] 2.1 `book_scanner/lib/data/models/braille_record.dart`: 新增 `sourcePostId` 字段,同步 `toJson`/`fromJson`/`copyWith`
- [ ] 2.2 `book_scanner/lib/features/showcase/view/post_detail_page.dart`: 操作栏新增"下载到存储库"按钮
- [ ] 2.3 去重判断:依据存储库中 `sourcePostId == post.id` 的记录决定按钮状态
- [ ] 2.4 下载执行流程:创建 `BrailleRecord` → `saveToBackend` → `addRecord` → 提示
- [ ] 2.5 加载/失败/空文字内容等边界处理

## 3. 提交与交付

- [ ] 3.1 git commit + push
- [ ] 3.2 服务器部署指引(替换文件 + 重启 + 验证列迁移)
- [ ] 3.3 前端 pull + 重新构建验证指引
