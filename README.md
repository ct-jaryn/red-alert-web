# 红色警戒 - 网页版

基于 Godot 4 开发的即时战略游戏，支持 Web 导出，可在浏览器中直接游玩。

## 游戏特性

- **即时战略玩法** - 建造基地、训练部队、消灭敌人
- **完整科技树** - 从电厂到战车工厂，逐步解锁高级建筑和单位
- **资源采集** - 采矿车自动采集矿石换取金币
- **建筑放置** - 邻近已有建筑放置，有建造动画
- **AI 对手** - 电脑玩家自动建造、生产、进攻
- **中文界面** - 全中文 UI
- **像素风素材** - 使用 Elite Command 开源素材

## 操作方式

| 操作 | 按键 |
|------|------|
| 选择单位/建筑 | 左键点击 |
| 框选多个单位 | 左键拖拽 |
| 移动/攻击 | 右键点击 |
| 滚动视角 | WASD / 鼠标边缘 |
| 缩放 | 滚轮 |
| 暂停 | ESC |
| 编队 | Ctrl+1~9 |
| 选中编队 | 1~9 |

## 建筑科技树

```
建造厂 → 电厂 → 兵营 → 机枪碉堡
                → 矿厂 → 战车工厂 → 维修平台
                        → 雷达 → 导弹碉堡
```

## 单位列表

**步兵** (兵营生产)
- 步枪兵 - 基础步兵
- 工程师 - 占领敌方建筑
- 火箭兵 - 反载具步兵

**载具** (战车工厂生产)
- 采矿车 - 采集矿石
- 轻型坦克 - 快速侦察
- 中型坦克 - 均衡主力
- 重型坦克 - 重型火力

## 本地运行

### Godot 编辑器
1. 用 Godot 4.x 打开项目
2. 按 F5 运行

### Web 导出
```bash
# 需要安装 Godot 4.3+ 和 Web 导出模板
godot --headless --path . --export-release "Web" export/web/index.html
python serve.py
# 访问 http://localhost:9000
```

## 素材来源

- 单位/建筑精灵: [Elite Command](https://opengameart.org/content/pixel-art-units-from-elite-command) by Chris Vincent (CC-BY 4.0)
- 中文字体: 黑体 (simhei.ttf)

## 技术栈

- Godot 4.3
- GDScript
- WebAssembly 导出
