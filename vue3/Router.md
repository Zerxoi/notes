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


## 路由传参

### query 参数与 params 参数

通过 Vue Router 中路由器 `push()` 和 `replace()` 函数可以传递 `query` 和 `params` 参数。

```js
const router = useRouter()

// 命名的路由，并加上参数，让路由建立 url
// params 参数需要与路由 name 联用，不能与 path 联用
router.push({ name: 'user', params: { username: 'eduardo' } })

// 带查询参数，结果是 /register?plan=private
router.push({ path: '/register', query: { plan: 'private' } })
```

在 Vue3 的组合 API 中路由参数会从 `useRoute()` 函数获取到的路由对象的 `query` 和 `params` 属性中分别获取 query 和 params 参数。

```js
const route = useRoute()

// 获取路由 params 参数
route.params.username
// 获取路由 query 参数
route.query.plan
```

### 动态路由

很多时候，我们需要将给定匹配模式的路由映射到同一个组件。例如，我们可能有一个 `User` 组件，它应该对所有用户进行渲染，但用户 ID 不同。在 Vue Router 中，我们可以在路径中使用一个动态字段来实现，我们称之为 路径参数 ：

```ts

const User = {
  template: '<div>User</div>',
}

// 这些都会传递给 `createRouter`
const routes: RouteRecordRaw[] = [
  // 动态字段以冒号开始
  {
    path: '/users/:id',
    name: 'user',
    component: User
  },
]
```

现在像 `/users/johnny` 和 `/users/jolyne` 这样的 URL 都会映射到同一个路由。

路由器通过如下形式传递动态参数：

```js
// 动态参数传递
router.push({
    name: "user",
    params: {
        id: 123
    }
})
```

路径参数 用冒号 `:` 表示。当一个路由被匹配时，它的 `params` 的值将在每个组件中以 `useRoute().params` 的形式暴露出来。

```ts
// 组合 API 获取路由
const route = useRoute()
// 动态参数接收
route.params.id
```

### 响应路由参数的变化

要对同一个组件中参数的变化做出响应的话，你可以简单地 watch `route` 对象上的任意属性，在这个场景中，就是 `route.params.id` ：

```ts
const route = useRoute()

watch(() => route.params.id, (val) => {
    itemInfo.item = data.find(item => item.id === Number(val))
})
```

## 嵌套路由

一些应用程序的 UI 由多层嵌套的组件组成。在这种情况下，URL 的片段通常对应于特定的嵌套组件结构，例如：

```txt
/user/johnny/profile                     /user/johnny/posts
+------------------+                  +-----------------+
| User             |                  | User            |
| +--------------+ |                  | +-------------+ |
| | Profile      | |  +------------>  | | Posts       | |
| |              | |                  | |             | |
| +--------------+ |                  | +-------------+ |
+------------------+                  +-----------------+
```

通过 Vue Router，你可以使用嵌套路由配置来表达这种关系。例如，在 User 组件的模板内添加一个 `<RouterView>` 来实现嵌套路由：

```vue
<!-- User.vue -->
<template>
    <div>
        <h2>User {{ $route.params.id }}</h2>
        <RouterView></RouterView>
    </div>
</template>
```

要将组件渲染到这个嵌套的 `<RouterView>` 中，我们需要在路由中配置 `children`：

```ts
const routes: RouteRecordRaw[] = [
    {
        path: "/user/:id",
        component: () => import("../components/Router/User.vue"),
        children: [
            // 当 /user/:id 匹配成功
            // UserHome 将被渲染到 User 的 <router-view> 内部
            {
                path: '',
                component: () => import("../components/Router/UserHome.vue")
            },
            {
                // 当 /user/:id/profile 匹配成功
                // UserProfile 将被渲染到 User 的 <router-view> 内部
                path: 'profile',
                component: () => import("../components/Router/UserProfile.vue"),
            },
            {
                // 当 /user/:id/posts 匹配成功
                // UserPosts 将被渲染到 User 的 <router-view> 内部
                path: 'posts',
                component: () => import("../components/Router/UserPosts.vue"),
            }
        ]
    },
]
```

## 命名视图

参考：[命名视图](https://router.vuejs.org/zh/guide/essentials/named-views.html)

有时候想同时 (同级) 展示多个视图，而不是嵌套展示，例如创建一个布局，有 `sidebar` (侧导航) 和 `main` (主内容) 两个视图，这个时候命名视图就派上用场了。你可以在界面中拥有多个单独命名的视图，而不是只有一个单独的出口。如果 `router-view` 没有设置名字，那么默认为 `default`。

```html
<router-view class="view left-sidebar" name="LeftSidebar"></router-view>
<router-view class="view main-content"></router-view>
<router-view class="view right-sidebar" name="RightSidebar"></router-view>
```

一个视图使用一个组件渲染，因此对于同个路由，多个视图就需要多个组件。确保正确使用 `components` 配置 (带上 s)：

```js
const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      components: {
        default: Home,
        // LeftSidebar: LeftSidebar 的缩写
        LeftSidebar,
        // 它们与 `<router-view>` 上的 `name` 属性匹配
        RightSidebar,
      },
    },
  ],
})
```
