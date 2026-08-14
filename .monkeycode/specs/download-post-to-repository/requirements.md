# Requirements Document

## Introduction

用户在展示区(首页)可以浏览他人发布的盲文记录帖子,但当前只能查看、点赞、收藏,无法将他人帖子中的数据保存到自己的存储库中使用。本功能允许用户将展示区帖子的数据"下载"到自己的存储库,复用他人共享的盲文内容。

## Glossary

- **帖子 (Post)**: 展示区中的 `ShowcasePost`,包含标题、来源类型、页数、文字内容、描述、作者等信息
- **存储库记录 (BrailleRecord)**: 用户本地存储库中的盲文记录,包含标题、来源类型、点阵数据、文字内容等
- **下载 (Download)**: 将帖子中的文字内容等数据以一条新的 `BrailleRecord` 保存到当前用户的存储库

## Requirements

### Requirement 1: 帖子详情页提供"下载到存储库"入口

**User Story:** AS 用户, I want 在帖子详情页将他人帖子下载到我的存储库, SO THAT 我可以复用他人共享的盲文内容。

#### Acceptance Criteria

1. WHEN 用户打开帖子详情页, the system SHALL 在操作栏提供"下载到存储库"按钮
2. WHEN 用户点击"下载到存储库"按钮, the system SHALL 将该帖子的数据保存为一条新的 `BrailleRecord` 到当前用户的存储库
3. WHILE 下载进行中, the system SHALL 显示加载状态,禁止用户重复触发下载
4. IF 下载成功, the system SHALL 提示用户"已保存到存储库",并允许用户跳转到存储库查看
5. IF 下载失败, the system SHALL 显示失败原因,且不产生任何部分保存的记录

### Requirement 2: 下载记录的数据映射

**User Story:** AS 用户, I want 下载后的记录保留帖子的核心数据, SO THAT 我能识别和使用这些共享内容。

#### Acceptance Criteria

1. WHEN 下载一条帖子, the system SHALL 使用帖子标题作为新记录标题
2. WHEN 下载一条帖子, the system SHALL 使用帖子来源类型作为新记录来源类型
3. WHEN 下载一条帖子, the system SHALL 使用帖子页数作为新记录页数
4. WHEN 帖子包含文字内容, the system SHALL 将文字内容保存到新记录的 `textContent`
5. WHEN 帖子不含文字内容, the system SHALL 仍可下载并创建记录,`textContent` 置空
6. WHEN 下载成功, the system SHALL 将新记录同步到后端,并出现在存储库列表中

### Requirement 3: 下载状态的唯一性处理

**User Story:** AS 用户, I want 明确知晓哪些帖子已下载, SO THAT 避免重复下载产生冗余记录。

#### Acceptance Criteria

1. IF 同一帖子被重复下载, the system SHALL 拒绝重复下载并提示"该帖子已下载到存储库"
2. WHEN 当前用户查看帖子详情页, the system SHALL 标记该帖子是否已被当前用户下载过
3. WHEN 帖子已被当前用户下载过, the system SHALL 在"下载到存储库"按钮上显示"已下载"状态并禁用
4. WHEN 当前用户删除该条已下载记录, the system SHALL 清除对应的"已下载"标记,允许再次下载

## Out of Scope

- 下载他人帖子的点赞数、收藏数、评论数据
- 同步下载他人帖子的作者头像等个人信息
- 从他人帖子反推点阵数据(仅保存文字内容)
