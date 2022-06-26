# Pinia

## 定义 Store

在深入了解核心概念之前，我们需要知道 Store 是使用 `defineStore()` 定义的，并且它需要一个**唯一**名称(`name`)，作为第一个参数传递：

```js
import { defineStore } from 'pinia'

// useStore 可以是 useUser、useCart 之类的任何东西
// 第一个参数是应用程序中 store 的唯一 id
export const useStore = defineStore('main', {
  // other options...
})
```

这个 `name`，也称为 id，是必要的，Pinia 使用它来将 `store` 连接到 devtools。 将返回的函数命名为 `use...` 是跨可组合项的约定，以使其符合你的使用习惯。

## 使用 Store

在 `setup()` 中调用 `useStore()` 之前不会创建 `store`。一旦 `store` 被实例化，你就可以直接在 `store` 上访问 `state、getters` 和 `actions` 中定义的任何属性。

```js
import { storeToRefs } from 'pinia'

export default defineComponent({
  setup() {
    const store = useStore()
    // `name` 和 `doubleCount` 是响应式引用
    // 这也会为插件添加的属性创建引用
    // 但跳过任何 action 或 非响应式（不是 ref/reactive）的属性
    const { name, doubleCount } = storeToRefs(store)

    return {
      name,
      doubleCount
    }
  },
})
```

`store` 是一个用 `reactive` 包裹的对象，这意味着不需要在`getter` 之后写 `.value`，但是，就像 `setup` 中的 `props` 一样，我们不能对其进行解构。为了从 Store 中提取属性同时保持其响应式，您需要使用 `storeToRefs()`。 它将为任何响应式属性创建 refs。

## State

```js
import { defineStore } from 'pinia'

const useStore = defineStore('storeId', {
  // 推荐使用 完整类型推断的箭头函数
  state: () => {
    return {
      // 所有这些属性都将自动推断其类型
      counter: 0,
      name: 'Eduardo',
      isAdmin: true,
    }
  },
})
```

### 修改 state

默认情况下，您可以通过 `store` 实例访问状态来直接读取和写入状态：

```js
const store = useStore()

store.counter++
```

除了直接用 `store.counter++` 修改 `store`，你还可以调用 `$patch` 方法。 它允许您使用部分“state”对象同时应用多个更改：

```js
store.$patch({
  counter: store.counter + 1,
  name: 'Abalam',
})
```

但是，使用这种语法应用某些突变非常困难或代价高昂：任何集合修改（例如，从数组中推送、删除、拼接元素）都需要您创建一个新集合。 正因为如此，`$patch` 方法也接受一个函数来批量修改集合内部分对象的情况：

```js
cartStore.$patch((state) => {
  state.items.push({ name: 'shoes', quantity: 1 })
  state.hasChanged = true
})
```

您可以通过将其 `$state` 属性设置为新对象来替换 Store 的整个状态：

```js
store.$state = { counter: 666, name: 'Paimon' }
```

### 重置 state

您可以通过调用 `store` 上的 `$reset()` 方法将状态 重置 到其初始值：

```js
const store = useStore()

store.$reset()
```

### 订阅 state

可以通过 `store` 的 `$subscribe()` 方法查看状态及其变化，类似于 Vuex 的 `subscribe` 方法。 与常规的 `watch()` 相比，使用 `$subscribe()` 的优点是 `subscriptions` 只会在 patches 之后触发一次。

```js
cartStore.$subscribe((mutation, state) => {
  // import { MutationType } from 'pinia'
  mutation.type // 'direct' | 'patch object' | 'patch function'
  // 与 cartStore.$id 相同
  mutation.storeId // 'cart'
  // 仅适用于 mutation.type === 'patch object'
  mutation.payload // 补丁对象传递给 to cartStore.$patch()

  // 每当它发生变化时，将整个状态持久化到本地存储
  localStorage.setItem('cart', JSON.stringify(state))
})
```


> 上述 `$subscribe()` 方法与下面的 `watch()` 函数等效：
> 
> ```js
> watch(
>   pinia.state,
>   (state) => {
>     // persist the whole state to the local storage whenever it changes
>     localStorage.setItem('piniaState', JSON.stringify(state))
>   },
>   { deep: true }
> )
> ```

#### 订阅的卸载

默认情况下，state 订阅会绑定到添加它们的组件（如果 `store` 位于组件的 `setup()` 中）。 意思是，当组件被卸载时，它们将被自动删除。 如果要在卸载组件后保留它们，请将 `{ detached: true }` 作为第二个参数传递给当前组件的 state 订阅：

```js
export default {
  setup() {
    const someStore = useSomeStore()

    // 此订阅将在组件卸载后保留
    someStore.$subscribe(callback, { detached: true })

    // ...
  },
}
```

## Getters

Getter 完全等同于 Store 状态的 计算值。 它们可以用 `defineStore()` 中的 `getters` 属性定义。

### getters 定义

接收“状态”作为第一个参数以鼓励箭头函数的使用：

```js
export const useStore = defineStore('main', {
  state: () => ({
    counter: 0,
  }),
  getters: {
    doubleCount: (state) => state.counter * 2,
  },
})
```

大多数时候，`getter` 只会依赖 `state`，但是，他们可能需要使用**其他 `getter`**。这样就需要在在定义常规函数时通过 `this` 访问到整个 `store` 的实例， 但是需要定义返回类型（在 TypeScript 中）。

```js
export const useStore = defineStore('main', {
  state: () => ({
    counter: 0,
  }),
  getters: {
    // 自动将返回类型推断为数字
    doubleCount(state) {
      return state.counter * 2
    },
    // 返回类型必须明确设置
    doublePlusOne(): number {
      return this.doubleCount + 1
    },
  },
})
```

然后你可以直接在 `store` 实例上访问 `getter`：

```vue
<template>
  <p>Double count is {{ store.doubleCount }}</p>
</template>

<script>
export default {
  setup() {
    const store = useStore()

    return { store }
  },
}
</script>
```

### 将参数传递给 getter

Getters 只是幕后的 `computed` 属性，因此无法向它们传递任何参数。 但是，您可以从 `getter` 返回一个函数以接受任何参数：

```js
export const useStore = defineStore('main', {
  getters: {
    getUserById: (state) => {
      return (userId) => state.users.find((user) => user.id === userId)
    },
  },
})
```

并在组件中使用：

```vue
<script>
export default {
  setup() {
    const store = useStore()

    return { getUserById: store.getUserById }
  },
}
</script>

<template>
  <p>User 2: {{ getUserById(2) }}</p>
</template>
```

请注意，在执行此操作时，`getter` 不再缓存，它们只是您调用的函数。 但是，您可以在 `getter` 本身内部缓存一些结果，这并不常见，但应该证明性能更高：

```js
export const useStore = defineStore('main', {
  getters: {
    getActiveUserById(state) {
      const activeUsers = state.users.filter((user) => user.active)
      return (userId) => activeUsers.find((user) => user.id === userId)
    },
  },
})
```

### 访问其他 Store 的getter

要使用其他存储 getter，您可以直接在 `getter` 内部使用它：

```js
import { useOtherStore } from './other-store'

export const useStore = defineStore('main', {
  state: () => ({
    // ...
  }),
  getters: {
    otherGetter(state) {
      const otherStore = useOtherStore()
      return state.localData + otherStore.data
    },
  },
})
```

## Actions

Actions 相当于组件中的 `methods`。它们可以使用 `defineStore()` 中的 `actions` 属性定义，并且它们非常适合定义业务逻辑：

```js
export const useMainStore = defineStore('main', {
  state: () => ({
    counter: 99,
  }),

  actions: {
    increment() {
      this.counter++
    },
    async getLoginInfo() {
      let loginInfo = await login()
      console.log(loginInfo.username)
    }
  },
})
```

与 `getters` 一样，操作可以通过 `this` 访问整个 `store` 示例并提供完整类型支持。 与它们不同，`actions` 可以是异步的，您可以在其中 `await` 任何 API 调用甚至其他操作！

### 订阅 Actions

可以使用 `store.$onAction()` 订阅 `action` 及其结果。 传递给它的回调在 `action` 之前执行。`after` 处理 `Promise` 并允许您在 `action` 完成后执行函数。 `以类似的方式，onError` 允许您在处理中抛出错误。

```js
const unsubscribe = someStore.$onAction(
  ({
    name, // action 的名字
    store, // store 实例
    args, // 调用这个 action 的参数
    after, // 在这个 action 执行完毕之后，执行这个函数
    onError, // 在这个 action 抛出异常的时候，执行这个函数
  }) => {
    // 记录开始的时间变量
    const startTime = Date.now()
    // 这将在 `store` 上的操作执行之前触发
    console.log(`Start "${name}" with params [${args.join(', ')}].`)

    // 如果 action 成功并且完全运行后，after 将触发。
    // 它将等待任何返回的 promise
    after((result) => {
      console.log(
        `Finished "${name}" after ${
          Date.now() - startTime
        }ms.\nResult: ${result}.`
      )
    })

    // 如果 action 抛出或返回 Promise.reject ，onError 将触发
    onError((error) => {
      console.warn(
        `Failed "${name}" after ${Date.now() - startTime}ms.\nError: ${error}.`
      )
    })
  }
)

// 手动移除订阅
unsubscribe()
```

## 插件

由于是底层 API，Pania Store可以完全扩展。 以下是您可以执行的操作列表：

- 向 Store 添加新属性
- 定义 Store 时添加新选项
- 为 Store 添加新方法
- 包装现有方法
- 更改甚至取消操作
- 实现本地存储等副作用
- 仅适用于特定 Store

使用 `pinia.use()` 将插件添加到 `pinia` 实例中。最简单的例子是通过返回一个对象为所有 Store 添加一个静态属性：

```ts
// main.ts
// 自定义 Pinia 插件
function MyPiniaPlugin(context: PiniaPluginContext) {
    return {
        foo: "bar"
    }
}

// 向 store 添加新属性时扩展 PiniaCustomProperties 接口
declare module 'pinia' {
    export interface PiniaCustomProperties {
        foo: string
    }
}

let app = createApp(App)
// Vue 安装 Pinia 插件
app.use(
    // Pinia 安装 MyPiniaPlugin 插件
    createPinia().use(MyPiniaPlugin)
)
app.mount('#app')
```

在为 Pinia 安装好插件后，可以在获取 Store 后直接访问 `store.foo` 来直接获取插件添加的属性。

```ts
const store = useStore()
store.foo // 'bar'
```

### `pinia.use()` 详解

`pinia.use()` 的类型声明如下，`pinia.use()` 函数传入的插件本质上就是一个函数。函数只有一个参数，参数类型为 `PiniaPluginContext` 表示 Pinia 插件的上下文。返回值是 `PiniaCustomProperties` 和 `PiniaCustomStateProperties` 两个类型的可选属性或者不返回值。

```ts
export declare interface Pinia {
    /**
     * Adds a store plugin to extend every store
     *
     * @param plugin - store plugin to add
     */
    use(plugin: PiniaPlugin): Pinia;
}

/**
 * Plugin to extend every store.
 */
export declare interface PiniaPlugin {
    (context: PiniaPluginContext): Partial<PiniaCustomProperties & PiniaCustomStateProperties> | void;
}

/**
 * Context argument passed to Pinia plugins.
 */
export declare interface PiniaPluginContext<Id extends string = string, S extends StateTree = StateTree, G = _GettersTree<S>, A = _ActionsTree> {
    /**
     * pinia instance.
     */
    pinia: Pinia;
    /**
     * Current app created with `Vue.createApp()`.
     */
    app: App;
    /**
     * Current store being extended.
     */
    store: Store<Id, S, G, A>;
    /**
     * Initial options defining the store when calling `defineStore()`.
     */
    options: DefineStoreOptionsInPlugin<Id, S, G, A>;
}
```

下面看看插件函数的返回值对象会被如何处理：

可见使用 `pinia.use()` 安装的插件会被添加到 `_p` 或者 `toBeInstalled` 数组中。如果是 Vue2 会直接添加到 `toBeInstalled` 数组中，而如果不过是 Vue2 的话则会先添加到 `_p` 数组中。在 Pinia 插件安装到 Vue 之后执行 `install()` 函数，`install()` 函数会将 `toBeInstalled` 数组中的组件转移到 `_p` 数组中。

```ts
let _p: Pinia['_p'] = []
// plugins added before calling app.use(pinia)
let toBeInstalled: PiniaPlugin[] = []
const pinia: Pinia = markRaw({
  install(app: App) {
    // this allows calling useStore() outside of a component setup after
    // installing pinia's plugin
    setActivePinia(pinia)
    if (!isVue2) {
      pinia._a = app
      app.provide(piniaSymbol, pinia)
      app.config.globalProperties.$pinia = pinia
      /* istanbul ignore else */
      if (__DEV__ && IS_CLIENT) {
        registerPiniaDevtools(app, pinia)
      }
      toBeInstalled.forEach((plugin) => _p.push(plugin))
      toBeInstalled = []
    }
  },
  use(plugin) {
    if (!this._a && !isVue2) {
      toBeInstalled.push(plugin)
    } else {
      _p.push(plugin)
    }
    return this
  },
})
```

在之后的过程中，Pinia 会应用所有已经安装的插件。可以看到无论是否处于开发环境，Pinia 都会将返回对象中的属性通过 `assign` 方法添加到 Pinia 的 `store` 对象中，不同的是在开发环境下还会将属性的 `key` 添加到 `store._customProperties` 来用于调试。

```ts
// apply all plugins
pinia._p.forEach((extender) => {
  /* istanbul ignore else */
  if (__DEV__ && IS_CLIENT) {
    const extensions = scope.run(() =>
      extender({
        store,
        app: pinia._a,
        pinia,
        options: optionsForPlugin,
      })
    )!
    Object.keys(extensions || {}).forEach((key) =>
      store._customProperties.add(key)
    )
    assign(store, extensions)
  } else {
    assign(
      store,
      scope.run(() =>
        extender({
          store,
          app: pinia._a,
          pinia,
          options: optionsForPlugin,
        })
      )!
    )
  }
})
```

### 拓充 store

可以通过简单地在插件中返回它们的对象来为每个 `store` 添加属性：

```js
pinia.use(() => ({ hello: 'world' }))
```

也可以直接在 `store` 上设置属性。

```js
pinia.use(({ store }) => {
  store.hello = 'world'
})
```

但是这样并不能通过 devtools 来跟踪添加的属性，所以为了让 `hello` 在 devtools 中可见，需要确保将它添加到 `store._customProperties`：

```js
// 该段代码实际上与直接返回添加的属性等效
pinia.use(({ store }) => {
  store.hello = 'world'
  // 确保您的打包器可以处理这个问题。 webpack 和 vite 应该默认这样做
  if (process.env.NODE_ENV === 'development') {
    // 添加您在 store 中设置的任何 keys
    store._customProperties.add('hello')
  }
})
```

请注意，每个 store 都使用 reactive 包装，自动展开任何 Ref (ref(), computed() ， ...） 它包含了：

```js
const sharedRef = ref('shared')
pinia.use(({ store }) => {
  // 每个 store 都有自己的 `hello` 属性
  store.hello = ref('secret')
  // 它会自动展开
  store.hello // 'secret'

  // 所有 store 都共享 value `shared` 属性
  store.shared = sharedRef
  store.shared // 'shared'
})
```

这就是为什么您可以在没有 .value 的情况下访问所有计算属性以及它们是响应式的原因。

#### 添加新状态

> 注：添加状态和上面的添加属性是不一样的

如果您想将新的状态属性添加到 store 或打算在 hydration 中使用的属性，您必须在两个地方添加它：

- 在 `store` 上，因此您可以使用 `store.myState` 访问它
- 在 `store.$state` 上，因此它可以在 devtools 中使用，并且在 SSR 期间被序列化。

```ts
// 自定义 Pinia 插件
function MyPiniaPlugin(context: PiniaPluginContext) {
    const store = context.store;
    // 为了正确处理 SSR，需要确保没有覆盖现有值
    if (!store.$state.hasOwnProperty('foo')) {
        const foo = ref('bar')
        store.$state.foo = foo
    }
    // 需要将 ref 从 $state 传输到 store 以保证 store.hasError 和 store.$state.hasError 共享相同的变量
    store.hasError = toRef(store.$state, 'foo')
}

// 向 store 添加新属性时扩展 PiniaCustomProperties 接口
declare module 'pinia' {
    export interface PiniaCustomProperties {
        foo: string,
    }
}
```

### 添加新的外部属性

当添加**外部属性**、**来自其他库的类实例**或仅仅是**非响应式的东西**时，您应该在将对象传递给 pinia 之前使用 `markRaw()` 包装对象。 这是一个将路由添加到每个 store 的示例：

```js
import { markRaw } from 'vue'
// 根据您的路由所在的位置进行调整
import { router } from './router'

pinia.use(({ store }) => {
  store.router = markRaw(router)
})
```

### 在插件中调用 `$subscribe`
您也可以在插件中使用 `store.$subscribe` 和 `store.$onAction`：

```js
pinia.use(({ store }) => {
  store.$subscribe(() => {
    // 在存储变化的时候执行
  })
  store.$onAction(() => {
    // 在 action 的时候执行
  })
})
```

### Pinia 持久化插件示例

```ts
import { PiniaPluginContext } from "pinia"

const __piniaKey = '__PINIAKEY__'

// 定义入参类型
type Options = {
    key?: string
}

// 将数据存在本地
const setStorage = (key: string, value: any): void => {
    localStorage.setItem(key, JSON.stringify(value))
}


// 存缓存中读取
const getStorage = (key: string) => {
    return (localStorage.getItem(key) ? JSON.parse(localStorage.getItem(key) as string) : {})
}

const StoragePlugin = (options: Options) => {
    return (context: PiniaPluginContext) => {
        const { store } = context;
        const data = getStorage(`${options?.key ?? __piniaKey}-${store.$id}`)
        store.$subscribe(() => {
            setStorage(`${options?.key ?? __piniaKey}-${store.$id}`, toRaw(store.$state));
        })
        return data
    }
}
```