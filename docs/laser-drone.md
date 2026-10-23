# 0.5.3 激光无人机修正

依据用户提供的 N 1.4 `n_v1pc.zip`，本地反编译记录在 `sources/n14_reference/actions.json`。本轮摘录保存在同目录的 `laser-audit.txt` 与 `laser-draw-audit.txt`，未引入外部素材。

`DroneObject`（block 283）给出 `laserPrefireDelay=30`、`laserRate=80`、`laserPostfireDelay=40`。原版按 40 Hz 更新，换算分别为 0.75 秒、2 秒、1 秒；移植仍在独立的 120 Hz 模拟中计时，渲染帧率不影响这些时长。

`Think_TargetPlayer` 通过射线检查发现玩家后进入 `StartFiring_Laser`，结束移动与寻敌，按此时的视线计算固定 `targ`、`beamdx`、`beamdy`。`PreFire` 完成预警后才进入 `Fire_Laser` / `Update_FiringLaser`，持续检测玩家与该线段的距离。`PostFire` 结束后才调用 `StartMoving`。因此瞄准延迟表现为玩家可以在预警期间离开已锁定射线，不应持续追踪到开火瞬间。

旧移植在预警阶段每步重新瞄准，攻击中仍移动，光束仅维持 0.175 秒。本次恢复固定射线与上述三阶段时长，预警线、默认/自定义外观的光束及碰撞显示使用相同端点。动态关闭的门会重新裁剪光束；开门最多恢复到本次锁定时的端点。静止炮塔与机枪射击逻辑保持原有行为。

原版 `debugDroneMC` 的 `laser_move` 使用 shape 811（暗红 `#882222` / 黑），`chain_move` 叠加 shape 812（黑 / 灰 `#666666`）。当前八边形图标按此区分暗红激光与黑色机枪，机枪眼部为灰色；不覆盖玩家导入的自定义图片。

`game/tests/test_v053.gd` 检查预警无伤、准确开火时刻、离开预警线可躲避、持续光束后段伤害、完整冷却、攻击期间停机、下一次重新锁定、墙与门遮挡、重试清理状态及完整模拟中的移动躲避。截图检查覆盖两种图标、预警、持续光束、冷却和自定义贴图预警。此轮不代表所有原版关卡已逐关通关。
