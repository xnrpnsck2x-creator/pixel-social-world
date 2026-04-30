# Game Design Bible
# 项目：2D像素在线社交世界
# 版本：v1.0
# 说明：本文档为游戏设计圣经，所有 Agent 在涉及玩法、美术、经济相关决策时必须遵守。
#       本文档不约束技术架构，技术约束见 AGENTS.md。

---

## 一、项目定位（核心）

这不是传统 MMORPG。

> 轻量级 2D 像素在线社交世界 + 房屋系统 + 小游戏平台 + 长线成长 + 持续运营平台

### 核心体验目标

- 每天上线 20～60 分钟也有乐趣
- 社交氛围强，主城挂机聊天有感觉
- 房屋有归属感
- 小游戏有娱乐性
- 成长轻度但长期存在
- 玩家愿意长期回来

### 设计原则

| 原则 | 说明 |
|------|------|
| 轻度优先 | 任何系统都不能让玩家感到"必须肝" |
| 社交优先 | 所有功能设计先问：这能促进社交吗？ |
| 归属感优先 | 房屋、角色外观、成就是核心留存锚点 |
| 不 Pay to Win | 付费只影响外观和体验速度，不影响玩法公平性 |

---

## 二、世界观与视觉风格

### 参考作品

| 作品 | 参考维度 |
|------|---------|
| Ragnarok Online（仙境传说）| 世界氛围、职业感、社交热闹感 |
| Moonfrost | 生活节奏、温暖感 |
| Stardew Valley | 像素质感、生活系统 |

### 整体基调

> 温暖日系像素奇幻世界。有烟火气，有奇幻元素，不黑暗，不硬核。

---

## 三、画面要求

### 地图风格

- 视角：2D 俯视角 / 微斜视角（类 RO 风格）
- 像素质量：高品质像素，细节丰富
- 主城氛围：适合挂机聊天，有生活感
- 必要元素：丰富植物、喷泉、摊位、灯光、路人 NPC

### 人物风格

- Q 版像素角色（头身比约 1:2 或 1:3）
- 多职业风格外观
- 多头饰、饰品系统
- 表情动作丰富（至少 8 种基础表情）
- 可爱且辨识度高

### UI 风格

- 像素 + 现代感结合
- 半透明面板（毛玻璃质感）
- 手机端：大按钮，单手可操作
- PC 端：布局清晰，信息密度适中

---

## 四、资源规划与 AI 生图提示词（Image 2）

> Pixel Art Agent 输出代码或资源时，必须参考以下提示词模板。

### 地图资源

#### 主城系列

**港口城（主城 1）**
```
prompt: top-down 2D pixel art port city, warm sunset lighting, wooden docks, 
fishing boats, market stalls, lanterns, RPG game map tile, Ragnarok Online style, 
cozy atmosphere, 32px tile size, rich details, no UI
```

**森林城（主城 2）**
```
prompt: top-down 2D pixel art forest town, magical glowing trees, 
mushroom houses, fairy lights, stone paths, cozy RPG map, 
warm green palette, 32px tile, Stardew Valley inspired, no UI
```

**沙漠城（主城 3）**
```
prompt: top-down 2D pixel art desert oasis city, sandstone buildings, 
palm trees, colorful market, warm orange palette, RPG game map, 
Middle Eastern inspired, 32px tile, detailed, no UI
```

#### 功能地图

**钓鱼地图**
```
prompt: top-down 2D pixel art fishing lake area, calm water reflections, 
wooden pier, lily pads, willow trees, cozy atmosphere, 32px tile, 
soft blue-green palette, no UI, game map
```

**矿洞地图**
```
prompt: top-down 2D pixel art mine cave interior, glowing crystals, 
wooden support beams, lanterns, rock walls, RPG dungeon map, 
dark blue-purple palette with warm light accents, 32px tile, no UI
```

**小游戏大厅**
```
prompt: top-down 2D pixel art game hall interior, colorful banners, 
multiple game tables, festive lighting, NPC characters, 
warm indoor atmosphere, 32px tile, no UI, RPG interior map
```

**房屋内部（默认）**
```
prompt: top-down 2D pixel art cozy room interior, wooden floor, 
simple furniture, window with curtains, warm lighting, 
customizable home RPG style, 32px tile, no UI
```

---

### 人物资源

**男性基础角色**
```
prompt: 2D pixel art male character sprite, Q-version chibi style, 
1:2 head-body ratio, front/back/left/right walk animation frames, 
RPG adventurer outfit, warm colors, 32x48px, white background, 
Ragnarok Online inspired
```

**女性基础角色**
```
prompt: 2D pixel art female character sprite, Q-version chibi style, 
1:2 head-body ratio, front/back/left/right walk animation frames, 
RPG mage outfit, pastel colors, 32x48px, white background, 
Ragnarok Online inspired
```

**商人 NPC**
```
prompt: 2D pixel art merchant NPC, chibi style, round friendly face, 
carrying a large pack, apron, warm smile, idle animation, 
32x48px, white background, cozy RPG style
```

**渔夫 NPC**
```
prompt: 2D pixel art fisherman NPC, chibi style, straw hat, 
fishing rod, casual outfit, friendly expression, idle animation, 
32x48px, white background, Stardew Valley inspired
```

**邮差 NPC**
```
prompt: 2D pixel art mailman NPC, chibi style, uniform cap, 
mail bag, cheerful expression, idle + walk animation, 
32x48px, white background, cozy RPG style
```

**小游戏主持人 NPC**
```
prompt: 2D pixel art game host NPC, chibi style, colorful jester hat, 
playful expression, holding a microphone, festive outfit, 
idle animation, 32x48px, white background
```

**可爱宠物（猫系）**
```
prompt: 2D pixel art cute cat companion, chibi style, 
round body, big eyes, idle + walk + sit animation frames, 
pastel color, 16x16px or 24x24px, white background, RPG pet style
```

---

### UI 资源

**登录界面**
```
prompt: 2D pixel art game login screen, fantasy RPG theme, 
logo area top center, username/password fields, pixel font, 
semi-transparent panel, warm color scheme, mobile optimized, 
1080x1920px, no actual text
```

**背包界面**
```
prompt: 2D pixel art inventory UI panel, grid slots 5x8, 
semi-transparent dark background, pixel border frame, 
item slots with hover state, RPG style, mobile friendly, 
warm wood texture frame, no actual items
```

**聊天框**
```
prompt: 2D pixel art chat UI panel, semi-transparent background, 
message list area, input field at bottom, channel tabs at top, 
pixel style border, mobile optimized, warm color palette
```

**好友栏**
```
prompt: 2D pixel art friends list UI, avatar slots, 
online/offline status indicators, pixel style, 
semi-transparent panel, mobile optimized, cozy RPG theme
```

**商店面板**
```
prompt: 2D pixel art shop UI panel, item grid display, 
coin currency icon, buy button, semi-transparent background, 
pixel border, warm merchant theme, mobile optimized
```

**排行榜**
```
prompt: 2D pixel art leaderboard UI, ranked list with avatar slots, 
gold/silver/bronze top 3 highlight, pixel style, 
semi-transparent panel, festive border, mobile optimized
```

**小游戏大厅界面**
```
prompt: 2D pixel art minigame lobby UI, game card grid layout, 
each card with game preview thumbnail and title, 
festive colorful theme, pixel border, mobile optimized, 
semi-transparent background
```

---

## 五、核心玩法系统（首发）

### 主世界

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 多人在线主城 | 玩家实时同屏移动 | P0 |
| 聊天频道 | 主城公屏、私聊、好友频道 | P0 |
| 表情互动 | 8+ 种表情动作，可触发动画 | P1 |
| 摆摊系统 | 玩家在主城摆摊出售道具 | P1 |
| 邮件系统 | 玩家间异步传递物品/金币/消息 | P1 |
| 好友系统 | 添加好友、查看在线状态、传送到好友位置 | P1 |
| 外观展示 | 角色外观、称号、宠物展示 | P1 |

### 房屋系统

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 玩家私人房屋 | 每人一间，可进行个性化装饰 | P1 |
| 好友可进入 | 好友访问房屋，可留言 | P1 |
| 家具摆放 | 拖拽式布局，多种家具 | P1 |
| 房屋内聊天 | 在房屋内可与访客聊天 | P2 |

### 生活技能

| 技能 | 玩法简述 | 掉落 |
|------|---------|------|
| 钓鱼 | 节奏类小操作，等待 + 时机点击 | 鱼、金币、随机道具 |
| 挖矿 | 定点采集，有耐久度 | 矿石、金币、技能碎片 |
| 采集 | 野外随机刷新，跑图采集 | 草药、食材、稀有素材 |

### 小游戏大厅

主城建筑中设置入口，首发只上线 1～2 个小游戏：

| 场馆 | 游戏类型 | 首发 |
|------|---------|------|
| 棋牌馆 | 麻将 | 候选 |
| 酒馆 | 德州扑克 | 候选 |
| 训练场 | 塔防 | ✅ 首发候选 |
| 竞技馆 | 回合制 PVP | 候选 |

> Producer Agent 建议：首发选塔防或钓鱼扩展版，开发成本最低，规则简单，适合单人快速完成。

---

## 六、成长系统

### 设计原则

> 无等级制。成长来自积累，而非数值压制。

### 成长维度

| 维度 | 内容 |
|------|------|
| 属性点 | 通过活动/任务缓慢积累，影响生活技能效率 |
| 技能 | 主动技能、被动天赋、大招，带随机词条 |
| 外观收藏 | 头饰、服装、宠物、房屋主题 |
| 成就系统 | 长线目标，驱动探索行为 |

### 三技能结构

```
被动（天赋）   → 持续生效，影响属性/掉落/效率
主动技能       → 手动触发，有 CD
大招           → 长 CD，高收益，特殊效果
```

### 技能词条系统

- 每个技能携带 1～3 个随机词条（类 Roguelike）
- 词条可影响：效果量、CD 时间、触发条件、额外掉落
- 词条可通过「洗天赋」（消耗金币）重新随机
- 玩家可自由组合 Build，鼓励分享和讨论

### 获取方式

- 每日任务（稳定产出）
- 活动奖励（限时高价值）
- 生活技能随机掉落（钓鱼、挖矿、采集）

---

## 七、经济系统

### 货币设计

| 货币 | 获取 | 用途 |
|------|------|------|
| 金币（软货币）| 游戏内所有活动 | 日常消耗 |
| 星钻（硬货币）| 充值 / 少量活动 | 外观、加速、稀有内容 |

> 原则：金币不可充值购买。星钻不影响战力。

### 金币产出

| 来源 | 日产出量级 | 备注 |
|------|-----------|------|
| 钓鱼 | 中 | 受渔具品质影响 |
| 挖矿 | 中 | 受工具品质影响 |
| 小游戏奖励 | 低～高 | 视排名和投入 |
| 每日任务 | 低（稳定）| 保底产出 |
| 活动任务 | 高（限时）| 节假日/版本活动 |

### 金币消耗

| 消耗点 | 说明 | 防通胀作用 |
|--------|------|-----------|
| 房屋装修 | 家具购买、装饰升级 | ✅ 大额沉淀 |
| 表情动作 | 购买特殊表情 | ✅ 小额持续 |
| 小游戏门票 | 参与需消耗 | ✅ 游玩成本 |
| 邮件手续费 | 寄送物品收手续费 | ✅ 流通税 |
| 洗天赋 | 重置技能词条 | ✅ 高频消耗 |
| 摆摊税 | 按成交额抽成 | ✅ 交易税 |

### 经济健康目标

- 防通胀：每日金币净产出 ≤ 净消耗的 110%
- 不 Pay to Win：付费内容只影响外观 / 速度，不影响公平
- 长期价值：金币始终有意义的消耗出口
- 创作者激励：玩家小游戏被游玩时，创作者获得金币分成（比例待定）

---

## 八、运营节奏（长线）

### 日常留存

- 每日签到（简单奖励）
- 每日任务（3～5 个，30 分钟内可完成）
- 生活技能每日上限（防止无限刷）

### 周期活动

| 周期 | 活动类型 |
|------|---------|
| 每周 | 排行榜重置 + 奖励 |
| 每月 | 新外观/家具上线 |
| 季度 | 大型版本更新（新地图/小游戏）|
| 节假日 | 限时主题活动（春节/万圣节等）|

### 社交裂变设计

- 好友同在线 → 给额外奖励
- 访问好友房屋 → 双方获得小奖励
- 邀请新用户 → 阶梯奖励
- 小游戏排行榜 → 分享功能

---

## 九、内容扩展路线（Post-MVP）

```
MVP（第1～6月）
├── 港口主城 + 钓鱼 + 聊天 + 房屋 + 金币系统

V1.1（第7～9月）
├── 森林城 + 挖矿 + 摆摊系统 + 更多家具

V1.2（第10～12月）
├── 小游戏大厅正式开放 + 玩家自创游戏接入

V2.0（第二年）
├── 沙漠城 + 宠物系统 + 公会系统 + 大型活动
```

---

## 十、给 AI 创作者的游戏规范摘要

> 以下内容面向使用 AI 创建小游戏的玩家创作者，所有 Agent 在生成创作者文档时必须包含以下约束。

- 游戏必须继承 `IMinigame` 接口（详见技术文档）
- 视觉风格：像素风，Tile 尺寸 32×32px，调色板 ≤ 32 色
- 禁止访问主城节点或系统 API
- 禁止内嵌广告或外部链接
- 资源总大小 ≤ 5MB
- 必须支持单人模式（多人为可选）
- 结算必须通过 `on_end()` 返回标准格式
- 文案必须提供英文版本（日文/中文可选）
