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

## 编程式导航

参考:[编程式导航](https://router.vuejs.org/zh/guide/essentials/navigation.html)

### `router.push` 导航到不同的位置

想要导航到不同的 URL，可以使用 `router.push` 方法。这个方法会向 history 栈添加一个新的记录，所以，当用户点击浏览器后退按钮时，会回到之前的 URL。

当你点击 `<router-link>` 时，内部会调用这个方法，所以点击 `<router-link :to="...">` 相当于调用 `router.push(...)` ，由于属性 to 与 router.push 接受的对象种类相同，所以两者的规则完全相同。：

```js
// 字符串路径
router.push('/users/eduardo')

// 带有路径的对象
router.push({ path: '/users/eduardo' })

// 命名的路由，并加上参数，让路由建立 url
router.push({ name: 'user', params: { username: 'eduardo' } })

// 带查询参数，结果是 /register?plan=private
router.push({ path: '/register', query: { plan: 'private' } })

// 带 hash，结果是 /about#team
router.push({ path: '/about', hash: '#team' })
```

### `router.replace` 替换当前位置

它的作用类似于 `router.push`，唯一不同的是，它在导航时不会向 history 添加新记录，正如它的名字所暗示的那样——它取代了当前的条目。

| 声明式                            | 编程式                |
| --------------------------------- | --------------------- |
| `<router-link :to="..." replace>` | `router.replace(...)` |

也可以直接在传递给 `router.push` 的 `routeLocation` 中增加一个属性 `replace: true` ：

```js
router.push({ path: '/home', replace: true })
// 相当于
router.replace({ path: '/home' })
```

### `router.forward|back|go` 横跨历史

```js
// 向前移动一条记录，与 router.forward() 相同
router.go(1)

// 返回一条记录，与 router.back() 相同
router.go(-1)

// 前进 3 条记录
router.go(3)

// 如果没有那么多记录，静默失败
router.go(-100)
router.go(100)
```