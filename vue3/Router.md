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

## 重定向和别名

### 重定向

重定向也是通过 `routes` 配置来完成，下面例子是从 `/home` 重定向到 `/`：

```js
const routes = [{ path: '/home', redirect: '/' }]
```

重定向的目标也可以是一个命名的路由：

```js
const routes = [{ path: '/home', redirect: { name: 'homepage' } }]
```

甚至是一个方法，动态返回重定向目标：

```js
const routes = [
  {
    // /search/screens -> /search?q=screens
    path: '/search/:searchText',
    redirect: to => {
      // 方法接收目标路由作为参数
      // return 重定向的字符串路径/路径对象
      return { path: '/search', query: { q: to.params.searchText } }
    },
  },
  {
    path: '/search',
    // ...
  },
]
```

请注意，导航守卫并没有应用在跳转路由上，而仅仅应用在其目标上。在上面的例子中，在 `/home` 路由中添加 `beforeEnter` 守卫不会有任何效果。

在写 `redirect` 的时候，可以省略 `component` 配置，因为它从来没有被直接访问过，所以没有组件要渲染。唯一的例外是嵌套路由：如果一个路由记录有 `children` 和 `redirect` 属性，它也应该有 `component` 属性。

### 相对重定向

也可以重定向到相对位置：

```js
const routes = [
  {
    // 将总是把/users/123/posts重定向到/users/123/profile。
    path: '/users/:id/posts',
    redirect: to => {
      // 该函数接收目标路由作为参数
      // 相对位置不以`/`开头
      // 或 { path: 'profile'}
      return 'profile'
    },
  },
]
```

### 别名

重定向是指当用户访问 `/home` 时，URL 会被 `/` 替换，然后匹配成 `/`。那么什么是别名呢？

将 `/` 别名为 `/home`，意味着当用户访问 `/`home 时，URL 仍然是 `/home`，但会被匹配为用户正在访问 `/`。

上面对应的路由配置为：

```js
const routes = [{ path: '/', component: Homepage, alias: '/home' }]
```

通过别名，你可以自由地将 UI 结构映射到一个任意的 URL，而不受配置的嵌套结构的限制。使别名以 `/` 开头，以使嵌套路径中的路径成为绝对路径。你甚至可以将两者结合起来，用一个数组提供多个别名：

```js
const routes = [
  {
    path: '/users',
    component: UsersLayout,
    children: [
      // 为这 3 个 URL 呈现 UserList
      // - /users
      // - /users/list
      // - /people
      { path: '', component: UserList, alias: ['/people', 'list'] },
    ],
  },
]
```

如果你的路由有参数，请确保在任何绝对别名中包含它们：

```js
const routes = [
  {
    path: '/users/:id',
    component: UsersByIdLayout,
    children: [
      // 为这 3 个 URL 呈现 UserDetails
      // - /users/24
      // - /users/24/profile
      // - /24
      { path: 'profile', component: UserDetails, alias: ['/:id', ''] },
    ],
  },
]
```

## 导航守卫

正如其名，vue-router 提供的导航守卫主要用来通过跳转或取消的方式守卫导航。这里有很多方式植入路由导航中：全局的，单个路由独享的，或者组件级的。

### 全局前置守卫

你可以使用 `router.beforeEach` 注册一个全局前置守卫：

```js
const router = createRouter({ ... })

router.beforeEach((to, from) => {
  // ...
  // 返回 false 以取消导航
  return false
})
```

当一个导航触发时，全局前置守卫按照创建顺序调用。守卫是异步解析执行，此时导航在所有守卫 resolve 完之前一直处于**等待中**。

每个守卫方法接收两个参数：

- `to`: 即将要进入的目标 用一种标准化的方式
- `from`: 当前导航正要离开的路由 用一种标准化的方式

可以返回的值如下:

- `false`: 取消当前的导航。如果浏览器的 URL 改变了(可能是用户手动或者浏览器后退按钮)，那么 URL 地址会重置到 from 路由对应的地址。
- 一个路由地址: 通过一个路由地址跳转到一个不同的地址，就像你调用 `router.push()` 一样，你可以设置诸如 `replace: true` 或 `name: 'home'` 之类的配置。当前的导航被中断，然后进行一个新的导航，就和 `from` 一样。
- 如果什么都没有，`undefined`  或返回 `true`，则导航是有效的，并调用下一个导航守卫

```js
const whiteList = ['/']
router.beforeEach((to, from) => {
    app.config.globalProperties.$bar.startLoading()
    if (whiteList.includes(to.path) || localStorage.getItem('token')) {
        return true
    } else {
        return '/'
    }
})
```

在之前的 Vue Router 版本中，也是可以使用 第三个参数 `next` 的。这是一个常见的错误来源，可以通过 RFC 来消除错误。所以不建议使用。

### 全局后置钩子

使用场景一般可以用来做 LoadingBar。

你也可以注册全局后置钩子，然而和守卫不同的是，这些钩子不会接受 `next` 函数也不会改变导航本身：

```js
router.afterEach((to, from) => {
  sendToAnalytics(to.fullPath)
})
```

LoadingBar 组件如下：

```vue
<script setup lang="ts">
const speed = ref(1)
const timer = ref(0)

const bar = ref<HTMLElement>()

const startLoading = () => {
    let dom = bar.value as HTMLElement
    timer.value = window.requestAnimationFrame(function fn() {
        if (speed.value < 90) {
            speed.value++
            dom.style.width = speed.value + '%'
            timer.value = window.requestAnimationFrame(fn)
        } else {
            speed.value = 1;
            window.cancelAnimationFrame(timer.value)
        }
    })
}

const endLoading = () => {
    let dom = bar.value as HTMLElement
    window.requestAnimationFrame(() => {
        speed.value = 100
        dom.style.width = speed.value + '%';
    })
}

defineExpose({
    startLoading,
    endLoading
})
</script>

<template>
    <div class="wrap">
        <div ref="bar" class="bar"></div>
    </div>
</template>

<style scoped lang="less">
.wrap {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;

    .bar {
        height: 1px;
        width: 0;
        background: red;
    }
}
</style>
```

将组件封装成一个插件 

```ts
import { App, createVNode, render, VNode } from 'vue'
import Loading from './index.vue'

export default {
    install(app: App) {
        // 创建虚拟DOM
        const vnode: VNode = createVNode(Loading)
        // 将虚拟 DOM 渲染成真实 DOM
        render(vnode, document.body)
        // 将组件中定义的函数放入全局变量中供所有组件使用
        app.config.globalProperties.$bar = {
            startLoading: vnode.component?.exposed?.startLoading,
            endLoading: vnode.component?.exposed?.endLoading
        }
    }
}
```

在安装完插件 `app.use(LoadingBar)` 之后在分别全局前置守卫和后置钩子调用 `startLoading` 和 `endLoading` 函数。

```ts
router.beforeEach((to, from) => {
    app.config.globalProperties.$bar.startLoading()
    if (whiteList.includes(to.path) || localStorage.getItem('token')) {
        return
    } else {
        return '/'
    }
})

router.afterEach((to, from) => {
    app.config.globalProperties.$bar.endLoading()
})
```

## 路由元信息

通过路由记录的 `meta` 属性可以定义路由的**元信息**。使用路由元信息可以在路由中附加自定义的数据，例如：

- 权限校验标识。
- 路由组件的过渡名称。
- 路由组件持久化缓存 (keep-alive) 的相关配置。
- 标题名称

```ts
const routes: RouteRecordRaw[] = [
    {
        path: "/",
        name: "Login",
        meta: {
            title: '登录'
        },
        component: () => import("../components/Router/RouterLogin.vue")
    },
    {
        path: "/register",
        name: "Register",
        meta: {
            title: '注册'
        },
        component: () => import("../components/Router/RouterRegister.vue")
    },
    {
        path: "/detail/:id",
        name: "Detail",
        component: () => import("../components/Router/RouterDetail.vue")
    },
]
```

我们可以在**导航守卫**或者是**路由对象**中访问路由的元信息数据。


```ts
declare module 'vue-router' {
    interface RouteMeta {
        // 是可选的
        title?: string
    }
}

router.beforeEach((to, from) => {
    document.title = to.meta.title || "Vue Demo"
    return true
})
```

## 过渡动效

```ts
const routes: RouteRecordRaw[] = [
    {
        path: "/",
        name: "Login",
        meta: {
            title: '登录',
            transition: "animate__fadeInUp",
        },
        component: () => import("../components/Router/RouterLogin.vue")
    },
    {
        path: "/register",
        name: "Register",
        meta: {
            title: '注册',
            transition: "animate__bounceIn",
        },
        component: () => import("../components/Router/RouterRegister.vue")
    },
    {
        path: "/detail/:id",
        name: "Detail",
        component: () => import("../components/Router/RouterDetail.vue")
    },
]
```

想要在你的路径组件上使用转场，并对导航进行动画处理，你需要使用 v-slot API，其中 Component 表示要传递给 `<component>` 的 VNodes 是 `prop`，`route` 是解析出的标准化路由地址。

```vue
<RouterView v-slot="{Component, route }">
    <Transition :enter-active-class="`animate__animated ${route.meta.transition ?? 'animate__shakeX'}`">
        <component :is="Component" />
    </Transition>
</RouterView>
```

TypeScript 声明元数据类型

```ts
declare module 'vue-router' {
    interface RouteMeta {
        // 是可选的
        title?: string,
        transition?: string
    }
}
```