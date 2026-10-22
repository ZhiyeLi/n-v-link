# 0.2 移动、按键与分部位动画技术记录

本轮按用户试玩反馈修订，日期：2026-10-22。

## 数值来源与有意修改

本地 `sources/n14_reference/actions.json` 的 Player.SetupParams / Think 记录原版半径 10、最大水平位移 5、地面加速度 0.15、空中加速度 0.1、常规重力 0.15、跳跃重力 0.025、常规阻尼 0.99。原版 APP_GAMETIME_BASETICKLEN 为 25 毫秒。因此原版速度以 ×40、加速度以 ×40² 换算为秒单位。40 只用于参考值换算；新模拟仍为 120 Hz。

| 项目 | 原版换算 / 0.1 参考值 | 0.2 |
| --- | --- | --- |
| 主动移动目标速度 | 200 px/s | **144 px/s** |
| 地面基础加速度 | 240 px/s² | **180 px/s²** |
| 空中基础加速度 | 160 px/s² | **120 px/s²** |
| 常规 / 跳跃重力 | 240 / 40 px/s² | 保持 |
| 平地起跳竖直冲量 | 120 px/s | 保持 |
| 最大持续低重力时间 | 0.75 s | 保持 |

降速不是“原版就这么慢”的结论，而是响应试玩反馈的明确调校：基础跑速降低 28%。如果以后要恢复原版尺度，应显式修改速度配置，不能把加速度倍率当作速度倍率。

## 加速度与最大速度分离

0.1 同时执行 `vx += axis * acceleration * multiplier * dt` 与固定水平阻尼。低倍率下，加速度与阻力会提前达到平衡，实际稳态速度低于配置上限；只检查 `speed <= cap` 无法发现这个错误。

0.2 正常主动移动执行：

```text
target = axis × 144
vx = move_toward(vx, target, base_acceleration × multiplier × dt)
```

主动水平移动不再叠加会降低终速的被动空气阻力；松键仍有指数阻力与落地摩擦。倍率改变到达目标速度或转向所需的时间，不改变目标速度。竖直阻力、重力与变高度跳跃保持独立。斜坡辅助的水平分量受同一上限约束；关卡机关的外部冲量另行保留，按键不能继续放大外部超速。

另外修正了弹性方块接触：不能把位置穿透修正量直接除以新步长当作额外速度；小步长会放大注入的能量。现在仅在有接近速度时交换冲量，位置修正独立进行。这是确认存在的潜在异常弹射来源；尚不能据此断言它就是用户上次所见现象的唯一原因。

## 验证结果

0.25、0.5、1、2、4 倍率，在地面和空中持续输入的终速均为 **144.0 px/s**。平地短按向右 100 毫秒，再松开等待两秒，总位移如下（包含松键后的滑行）：

| 加速度倍率 | 总位移 |
| --- | --- |
| 0.25× | 0.79 px |
| 0.5× | 2.22 px |
| 1× | 5.09 px |
| 2× | 10.80 px |
| 4× | 22.23 px |

一格地图砖为 24 px。测试覆盖正常地面短按，不代表弹射器、斜坡下落等关卡环境的全部运动范围。报告保存在 `logs/controls-tests.json`。三种渲染调度下的轨迹一致，记录在 `logs/fps-*.log`。

## 角色层级与换肤接口

`NinjaRig` 的 12 个部位：

```text
body
  head
  left_upper_arm → left_forearm
  right_upper_arm → right_forearm
  left_thigh → left_calf → left_foot
  right_thigh → right_calf → right_foot
```

手臂、大腿/小腿使用双段关节解算保持肢体长度；姿态间短时插值。跑动周期随实际位移速度推进；贴墙上升交替伸手、收腿，滑墙保持支撑，蹬墙有独立踢出姿态。贴墙上升是既有运动的动画表现，没有增加攀爬规则。

`NinjaRig.set_part_texture(part_name, texture)` 可替换单个部位；`NinjaPart` 目前使用线条作为默认图形。纹理沿各自骨段的本地 X 轴绘制，父子关节自动继承位置和转角。此轮没有加入换肤选择界面。

朝向记录最后一次方向键的按下事件，写入输入位 FACE_LEFT / FACE_RIGHT，松键后保留；与速度、碰撞法线分离。整套关节通过根节点镜像。模拟版本为 `n14-port-0.2`，输入格式版本为 2，为后续回放留下明确版本界限。

## 按键与窗口

七个游戏动作全部通过 InputMap 查询，各有三个可编辑键位。捕获新按键优先于执行游戏快捷键，冲突不会覆盖已有动作。退出绑定可用界面按钮，因此 Esc 本身也允许重绑。全屏在 `_input` 阶段处理，使输入框获得焦点时仍能执行；其他游戏快捷键避免干扰文字输入。封面的键位说明已删除。

`NinjaSettings.apply()` 只应用帧率与垂直同步，不再设置窗口模式。`NinjaWindowMode` 仅响应显式全屏操作，记录之前的窗口模式、大小和位置。恢复默认也不会修改当前窗口状态。真实 Windows 测试覆盖自定义窗口、最大化、全屏和焦点内快捷键，共 10 项检查通过。

## 核对的资料

- 本地原版参考：`sources/n14_reference/actions.json`、`player.txt`、`think-summary.txt`；可用 `python tools/reference_summary.py SetupParams` / `Think` 重新查看数值与分支。
- [Metanet 碰撞教程 A](https://www.metanetsoftware.com/technique/tutorialA.html)：位置投影与速度/摩擦处理应区分；教程没有提供本项目全部运动常数，常数来自本地原版参考。
- [Godot InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html)：动作与输入事件的安装、移除和查询。
- [Godot DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html)：窗口模式、窗口尺寸接口；无头模式不能验证真实窗口行为。
