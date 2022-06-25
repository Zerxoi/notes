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
