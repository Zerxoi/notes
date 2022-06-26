# Vue Router

## 安装

Vue Router 安装命令

```bash
npm install -S vue-router
```

配置并创建路由插件

```ts
import { createRouter, createWebHistory, RouteRecordRaw } from "vue-router";

const routes: RouteRecordRaw[] = [
    {
        path: "/",
        component: () => import("../components/Router/RouterLogin.vue")
    }, {
        path: "/register",
        component: () => import("../components/Router/RouterRegister.vue")
    }
]

const router = createRouter({
    history: createWebHistory(),
    routes: routes
})

export default router
```

安装路由插件

```ts
createApp(App).use(router).mount('#app')
```

编写路由视图组件

```vue
<template>
    <div class="content">
        <RouterLink to="/">Login</RouterLink>
        <RouterLink to="/register">Register</RouterLink>
        <RouterView></RouterView>
    </div>
</template>
```

## 路由历史记录模式

对于 Vue 这类渐进式前端开发框架，为了构建 SPA（单页面应用），需要引入前端路由系统，这也就是 Vue Router 存在的意义。前端路由的核心，就在于**改变视图的同时不会向后端发出请求**。

### hash模式

hash 是 URL 中 hash(#) 及后面的部分。例如 URL `http://www.abc.com/#/hello` 中的 hash 的值为 `#/hello`。

`hash` 虽然出现在 URL 中，但不会被包括在 HTTP 请求中，对后端完全没有影响，因此改变 `hash` 不会重新加载页面。

通过 `window.location.hash` 可以访问和修改 `hash` 值，`hash `值的改变会触发 `hashchange` 事件来监听路由。

```js
window.addEventListener('hashChange',function(){
    // 监听 hash 变化,点击浏览器的前进后退会触发
})
```

Vue Router 使用 hash 路由模式：

```js
createRouter({
    history: createWebHashHistory(),
    // ...
})
```

### history模式

history模式是利用了 HTML5 History Interface 中提供的 `pushState()` 和 `replaceState()` 方法来实现的。这两个方法应用于浏览器的历史记录栈，在当前已有的 `back()`、`forward()`、`go()` 的基础之上提供了对历史记录进行修改的功能。

和 hash模式一样，当它们执行修改时，虽然改变了当前的 URL，但浏览器不会立即向后端发送请求。

浏览器的前进和后退事件会被 `popstate` 监听到，但是`pushState` 与 `replaceState` 方法不会触发该事件，而 `back()`、`forward()` 和 `go()` 函数会被监听。

```js
window.addEventListener('popstate',function(){
    // 监听浏览器的前进后退事件
    // pushState 与 replaceState 方法不会触发
})
```

Vue Router 使用 hash 路由模式：

```js
createRouter({
    history: createWebHistory(),
    // ...
})
```