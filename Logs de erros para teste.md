**```**

**=== Zomboid Settings ===**

**Version: 42.21.0 4a0e9546ec (Steam)**

**Mode: SINGLE PLAYER**



**\[x1]**

**Lua((MOD:ZE Guns Of Bohemia - Reloading)).Add(ZGB\_ReloadHooks.lua:72)**

**```
```**

**=== Zomboid Settings ===**

**Version: 42.21.0 4a0e9546ec (Steam)**

**Mode: SINGLE PLAYER**



**\[x11]**

**Lua((MOD:ZE Guns Of Bohemia - Reloading)).Add(ZGB\_ReloadHooks.lua:72)**

**java.lang.RuntimeException: Object tried to call nil in Add**

&#x20;   **at se.krka.kahlua.vm.KahluaUtil.fail(KahluaUtil.java:100)**

&#x20;   **at se.krka.kahlua.vm.KahluaThread.luaMainloop(KahluaThread.java:763)**

&#x20;   **at se.krka.kahlua.vm.KahluaThread.call(KahluaThread.java:162)**

&#x20;   **at se.krka.kahlua.vm.KahluaThread.pcall(KahluaThread.java:1740)**

&#x20;   **at se.krka.kahlua.vm.KahluaThread.pcallvoid(KahluaThread.java:1572)**

&#x20;   **at se.krka.kahlua.integration.LuaCaller.pcallvoid(LuaCaller.java:60)**

&#x20;   **at se.krka.kahlua.integration.LuaCaller.protectedCallVoid(LuaCaller.java:131)**

&#x20;   **at zombie.Lua.Event.trigger(Event.java:55)**

&#x20;   **at zombie.Lua.LuaEventManager.triggerEvent(LuaEventManager.java:279)**

&#x20;   **at zombie.gameStates.IngameState.onTick(IngameState.java:1657)**

&#x20;   **at zombie.gameStates.IngameState.updateInternal(IngameState.java:1573)**

&#x20;   **at zombie.gameStates.IngameState.update(IngameState.java:1370)**

&#x20;   **at zombie.gameStates.GameStateMachine.update(GameStateMachine.java:65)**

&#x20;   **at zombie.GameWindow.logic(GameWindow.java:391)**

&#x20;   **at zombie.GameWindow.frameStep(GameWindow.java:791)**

&#x20;   **at zombie.GameWindow.mainThreadStep(GameWindow.java:568)**

&#x20;   **at zombie.MainThread.mainLoop(MainThread.java:69)**

&#x20;   **at java.base/java.lang.Thread.run(Unknown Source)**



**```**

```

=== Zomboid Settings ===

Version: 42.21.0 4a0e9546ec (Steam)

Mode: SINGLE PLAYER



\[x1]

Lua((MOD:ZE Guns Of Bohemia - Core)).validate(ZGB\_WeaponFactory.lua:108)

&#x20;   Lua((MOD:ZE Guns Of Bohemia - Core)).define(ZGB\_WeaponFactory.lua:141)

&#x20;   Lua((MOD:ZE Guns Of Bohemia - Core)).ZGB\_Def\_Weapons.lua(ZGB\_Def\_Weapons.lua:43)

java.lang.RuntimeException: Object tried to call nil in validate

&#x20;   at se.krka.kahlua.vm.KahluaUtil.fail(KahluaUtil.java:100)

&#x20;   at se.krka.kahlua.vm.KahluaThread.luaMainloop(KahluaThread.java:763)

&#x20;   at se.krka.kahlua.vm.KahluaThread.call(KahluaThread.java:162)

&#x20;   at se.krka.kahlua.vm.KahluaThread.pcall(KahluaThread.java:1740)

&#x20;   at se.krka.kahlua.vm.KahluaThread.pcall(KahluaThread.java:1544)

&#x20;   at se.krka.kahlua.integration.LuaCaller.pcall(LuaCaller.java:69)

&#x20;   at se.krka.kahlua.integration.LuaCaller.protectedCall(LuaCaller.java:109)

&#x20;   at zombie.Lua.LuaManager.RunLuaInternal(LuaManager.java:1394)

&#x20;   at zombie.Lua.LuaManager.RunLua(LuaManager.java:1346)

&#x20;   at zombie.Lua.LuaManager.RunLua(LuaManager.java:1335)

&#x20;   at zombie.Lua.LuaManager.LoadDirBase(LuaManager.java:1225)

&#x20;   at zombie.Lua.LuaManager.LoadDirBase(LuaManager.java:1139)

&#x20;   at zombie.Lua.LuaManager.LoadDirBase(LuaManager.java:1261)

&#x20;   at zombie.gameStates.IngameState.exit(IngameState.java:1082)

&#x20;   at zombie.gameStates.GameStateMachine.update(GameStateMachine.java:68)

&#x20;   at zombie.GameWindow.logic(GameWindow.java:391)

&#x20;   at zombie.GameWindow.frameStep(GameWindow.java:791)

&#x20;   at zombie.GameWindow.mainThreadStep(GameWindow.java:568)

&#x20;   at zombie.MainThread.mainLoop(MainThread.java:69)

&#x20;   at java.base/java.lang.Thread.run(Unknown Source)



```

```

=== Zomboid Settings ===

Version: 42.21.0 4a0e9546ec (Steam)

Mode: SINGLE PLAYER



\[x1]

Lua((MOD:ZE Guns Of Bohemia - Core)).validate(ZGB\_WeaponFactory.lua:108)

&#x20;   Lua((MOD:ZE Guns Of Bohemia - Core)).define(ZGB\_WeaponFactory.lua:141)

&#x20;   Lua((MOD:ZE Guns Of Bohemia - Core)).ZGB\_Def\_Weapons.lua(ZGB\_Def\_Weapons.lua:43)

java.lang.RuntimeException: Object tried to call nil in validate

&#x20;   at se.krka.kahlua.vm.KahluaUtil.fail(KahluaUtil.java:100)

&#x20;   at se.krka.kahlua.vm.KahluaThread.luaMainloop(KahluaThread.java:763)

&#x20;   at se.krka.kahlua.vm.KahluaThread.call(KahluaThread.java:162)

&#x20;   at se.krka.kahlua.vm.KahluaThread.pcall(KahluaThread.java:1740)

&#x20;   at se.krka.kahlua.vm.KahluaThread.pcall(KahluaThread.java:1544)

&#x20;   at se.krka.kahlua.integration.LuaCaller.pcall(LuaCaller.java:69)

&#x20;   at se.krka.kahlua.integration.LuaCaller.protectedCall(LuaCaller.java:109)

&#x20;   at zombie.Lua.LuaManager.RunLuaInternal(LuaManager.java:1394)

&#x20;   at zombie.Lua.LuaManager.RunLua(LuaManager.java:1346)

&#x20;   at zombie.Lua.LuaManager.RunLua(LuaManager.java:1335)

&#x20;   at zombie.Lua.LuaManager.LoadDirBase(LuaManager.java:1225)

&#x20;   at zombie.Lua.LuaManager.LoadDirBase(LuaManager.java:1139)

&#x20;   at zombie.Lua.LuaManager.LoadDirBase(LuaManager.java:1261)

&#x20;   at zombie.core.Core.ResetLua(Core.java:4169)

&#x20;   at java.base/jdk.internal.reflect.DirectMethodHandleAccessor.invoke(Unknown Source)

&#x20;   at java.base/java.lang.reflect.Method.invoke(Unknown Source)

&#x20;   at se.krka.kahlua.integration.expose.caller.MethodCaller.call(MethodCaller.java:58)

&#x20;   at se.krka.kahlua.integration.expose.LuaJavaInvoker.call(LuaJavaInvoker.java:194)

&#x20;   at se.krka.kahlua.integration.expose.MultiLuaJavaInvoker.call(MultiLuaJavaInvoker.java:59)

&#x20;   at se.krka.kahlua.vm.KahluaThread.callJava(KahluaThread.java:178)

&#x20;   at se.krka.kahlua.vm.KahluaThread.luaMainloop(KahluaThread.java:795)

&#x20;   at se.krka.kahlua.vm.KahluaThread.call(KahluaThread.java:162)

&#x20;   at se.krka.kahlua.vm.KahluaThread.pcall(KahluaThread.java:1740)

&#x20;   at se.krka.kahlua.vm.KahluaThread.pcallBoolean(KahluaThread.java:1676)

&#x20;   at se.krka.kahlua.integration.LuaCaller.protectedCallBoolean(LuaCaller.java:96)

&#x20;   at zombie.ui.UIElement.onMouseUp(UIElement.java:1411)

&#x20;   at zombie.ui.UIElement.onMouseUp(UIElement.java:1384)

&#x20;   at zombie.ui.UIElement.onMouseUp(UIElement.java:1384)

&#x20;   at zombie.ui.UIElement.onConsumeMouseButtonUp(UIElement.java:1474)

&#x20;   at zombie.ui.UIManager.updateMouseButtons(UIManager.java:748)

&#x20;   at zombie.ui.UIManager.update(UIManager.java:622)

&#x20;   at zombie.GameWindow.logic(GameWindow.java:348)

&#x20;   at zombie.GameWindow.frameStep(GameWindow.java:791)

&#x20;   at zombie.GameWindow.mainThreadStep(GameWindow.java:568)

&#x20;   at zombie.MainThread.mainLoop(MainThread.java:69)

&#x20;   at java.base/java.lang.Thread.run(Unknown Source)



```

