# Vue3

## 响应式

- `ref` 将数据变成响应式的对象
  - 非 `shallowRef` 的对象类型将使用 `reactive` 函数转化为响应式对象
  - 其他类型的数据，无论是否是 `shallowRef` 类型都会直接将数据原值作为响应式对象
- `shallowRef` 将数据变成（浅）响应式对象。但是只监听数据引用的变化，数据内容的变化不会被监听
  - 一般配合 `triggerRef` 函数使用
- `triggerRef` 将数据内容的变化强制更新 DOM
- `isRef` 判断值是否为引用对象
- `reactive` 用于创建原始对象的响应式副本
  - 反应式转换是“深度”的——它影响所有嵌套的属性
  - 创建后的响应式对象不能通过 `=` 直接进行赋值，只能通过响应式对象的属性和方法对响应式对象进行修改
  - `reactive` 对象也会自动解包其中包含的 `ref`，因此在访问和改变其值时无需使用 `.value`
- `shallowReactive` 返回原始对象的浅响应式副本，其中只有根级别的属性是响应式的。
  - 它也不会自动解包引用（即使在根级别）,即需要使用 `.value`
- `readonly` 创建原始对象的只读副本
  - 返回的副本不是响应式的，但可以在已经响应式的对象上调用 `readonly`
- `toRef` 将对象中的属性转化为 `ref` 对象
  - 如果原始对象是响应式的，生成的 `ref` 对象也是响应式的；否则，不是响应式的
- `toRefs` 将对象的中的所有属性通过 `toRef` 函数转化为 `ref` 属性并返回转化后的对象
- `toRaw` 获取对象的原始对象

## `computed`

计算属性就是当依赖的属性的值发生变化的时候，才会触发他的更改，如果依赖的值，不发生变化的时候，使用的是缓存中的属性值。

1. 函数形式
    ```typescript
    let price = ref(0)
    let m = computed<string>(()=>{
      return `$` + price.value
    })
    ```
2. 对象形式

    ```typescript
    let price = ref<number | string>(1)
    let mul = computed({
      get: () => {
          return price.value
      },
      set: (value) => {
          price.value = 'set' + value
      }
    })
    ```

## `watch`

`watch` 需要侦听特定的数据源，并在单独的回调函数中执行副作用

- 第一个参数监听源
- 第二个参数回调函数
- 第三个参数一个 `options` 配置项是一个对象

```typescript
let message = ref({
  nav: {
    bar: {
      name: ""
    }
  }
})

watch(message, (newVal, oldVal) => {
  console.log('新的值----', newVal);
  console.log('旧的值----', oldVal);
}, {
  immediate: true,
  deep: true
})
```

## `watchEffect`

立即运行一个函数，同时响应地跟踪它的依赖关系，并在依赖关系发生变化时重新运行它。

### 类型

```typescript
function watchEffect(
  effect: (onCleanup: OnCleanup) => void,
  options?: WatchEffectOptions
): StopHandle

type OnCleanup = (cleanupFn: () => void) => void

interface WatchEffectOptions {
  flush?: 'pre' | 'post' | 'sync' // default: 'pre'
  onTrack?: (event: DebuggerEvent) => void
  onTrigger?: (event: DebuggerEvent) => void
}

type StopHandle = () => void
```

### 描述

第一个参数是要运行的效果函数。效果函数接收可用于注册清理回调的函数。清理回调将在下一次重新运行效果之前调用，可用于清理无效的副作用，例如待处理的异步请求。

第二个参数是一个可选的选项对象，可用于调整效果的刷新时间或调试效果的依赖关系。

返回值是一个句柄函数，可以调用它来阻止效果再次运行。

## 组件

组件允许我们将 UI 拆分为独立且可重用的部分，并单独考虑每个部分。

### 组件的生命周期

简单来说就是一个组件从创建到销毁的过程称为生命周期。

![生命周期](imgs/组件生命周期.png)

在我们使用Vue3 组合式API 是没有 `beforeCreate` 和 `created` 这两个生命周期的


| 选项式API         | `setup` 钩子        | 描述                                                             |
| ----------------- | ------------------- | ---------------------------------------------------------------- |
| `beforeCreate`    | Not needed          | 在实例初始化时调用                                               |
| `created`         | Not needed          | 在实例处理完所有与状态相关的选项后调用                           |
| `beforeMount`     | `onBeforeMount`     | 组件挂载之前调用                                                 |
| `mounted`         | `onMounted`         | 在组件挂载后调用                                                 |
| `beforeUpdate`    | `onBeforeUpdate`    | 由于响应状态更改，在组件即将更新其 DOM 树之前调用                |
| `updated`         | `onUpdated`         | 在组件由于响应状态更改而更新其 DOM 树后调用                      |
| `beforeUnmount`   | `onBeforeUnmount`   | 在要卸载组件实例之前调用                                         |
| `unmounted`       | `onUnmounted`       | 在组件卸载后调用                                                 |
| `errorCaptured`   | `onErrorCaptured`   | 当捕获到从后代组件传播的错误时调用                               |
| `renderTracked`   | `onRenderTracked`   | 当组件的渲染效果跟踪到响应式依赖项时调用                         |
| `renderTriggered` | `onRenderTriggered` | 当响应式依赖触发组件的渲染效果重新运行时调用                     |
| `activated`       | `onActivated`       | 在组件实例作为 `<KeepAlive>` 缓存的树的一部分插入 DOM 后调用     |
| `deactivated`     | `onDeactivated`     | 在组件实例作为 `<KeepAlive>` 缓存的树的一部分从 DOM 中删除后调用 |

### 组件注册

一个 Vue 组件需要被“注册”使得 Vue 在渲染模板时能找到其实现。有两种方式来注册组件：全局注册和局部注册。


#### 全局注册

我们可以使用 `app.component()` 方法，让组件在当前 Vue 应用中全局可用。

```typescript
import { createApp } from 'vue'

const app = createApp({})

app.component(
  // 注册的名字
  'MyComponent',
  // 组件的实现
  {
    /* ... */
  }
)
```

如果使用单文件组件，你可以注册被导入的 `.vue` 文件：

```typescript
import MyComponent from './App.vue'

app.component('MyComponent', MyComponent)
```

全局注册的组件可以在此应用的任意组件的模板中使用。

#### 局部注册

全局注册虽然很方便，但有以下几个短板：

1. 全局注册使构建系统无法移除未使用的组件 (也叫“tree-shaking”)。如果你全局注册了一个组件，却一次都没有使用，它仍然会出现在最终的构建产物中。
2. 全局注册在大型项目中使项目的依赖关系变得不那么明确。在父组件中使用子组件时，很难定位子组件的实现。这可能会影响未来长期的可维护性，类似于使用过多的全局变量。

局部注册将注册组件的可用性限定在当前组件的范围内。它使依赖关系更加明确，并且对 tree-shaking 更加友好。

当你在单文件组件中使用了 `<script setup>`，导入的组件可以在本地使用而无需注册：

```vue
<script setup>
import ComponentA from './ComponentA.vue'
</script>

<template>
  <ComponentA />
</template>
```

如果不在 `<script setup>` 中，你将需要使用 `components` 选项：

```typescript
import ComponentA from './ComponentA.js'

export default {
  components: {
    ComponentA
  },
  setup() {
    // ...
  }
}
```

### 递归组件

递归组件示例 `Tree.vue`：

```vue
<script setup lang="ts">
type TreeNode = {
    name: string,
    icon?: string,
    children?: TreeNode[]
}

type Props = { nodeList: TreeNode[] }

defineProps<Props>()

const emit = defineEmits<{
    (e: "on-click", node: TreeNode): void
}>()

const clickNode = (node: TreeNode) => {
    emit("on-click", node)
}
</script>

<script lang="ts">
export default {
    name: "Tree"
}
</script>

<template>
    <div :key="index" v-for="(node, index) in nodeList" @click.stop="clickNode(node)">
        <div>{{ node.name }}</div>
        <Tree v-if="node?.children?.length" :node-list="node.children" @on-click="clickNode"></Tree>
    </div>
</template>

<style scoped lang="less">
</style>
```

递归组件 `Tree.vue` 的使用：

```vue
<script setup lang="ts">
import Tree from 'Tree.vue';

type TreeNode = {
    name: string,
    icon?: string,
    children?: TreeNode[]
}

const treeList = reactive<TreeNode[]>([
    {
        name: "1",
        children: [
            {
                name: "1-1",
                children: [
                    {
                        name: "1-1-1",
                    }
                ]
            }
        ]
    },
    {
        name: "2",
        children: [
            {
                name: "2-1",
            },
            {
                name: "2-2",
            }
        ]
    },
    {
        name: "3"
    }
])

const receiveNode = (node: TreeNode) => {
    console.log(node);
}
</script>

<template>
    <div>
        <Tree :node-list="treeList" @on-click="receiveNode"></Tree>
    </div>
</template>

<style lang="less" scoped>
</style>
```

## [`<script setup>`](https://vuejs.org/api/sfc-script-setup.html#script-setup)

### `defineProps()` & `defineEmits()`

要声明具有完整类型推断支持的 `props` 和 `emits` 等选项，可以使用 `defineProps` 和 `defineEmits` API，它们在 `<script setup>` 中自动可用：

- `defineProps` 和 `defineEmits` 是编译器宏，只能在 `<script setup>` 中使用。它们不需要导入，并在处理 `<script setup>` 时被编译掉。
- `defineProps` 接受与 `props` 选项相同的值，而 `defineEmits` 接受与 `emits` 选项相同的值。
- `defineProps` 和 `defineEmits` 根据传递的选项提供正确的类型推断。
- 传递给 `defineProps` 和 `defineEmits` 的选项将从设置中提升到模块范围内。因此，选项不能引用在设置范围内声明的局部变量。这样做会导致编译错误。但是，它可以引用导入的绑定，因为它们也在模块范围内。

```typescript
const props = defineProps({
  foo: String
})

const emit = defineEmits(['change', 'delete'])
```

#### [仅限 TypeScript 的功能](https://vuejs.org/api/sfc-script-setup.html#typescript-only-features)

Props 和 Emits 也可以通过将文字类型参数传递给 `defineProps` 或 `defineEmits` 来使用纯类型语法声明：

```typescript
const props = defineProps<{
  foo: string
  bar?: number
}>()

const emit = defineEmits<{
  (e: 'change', id: number): void
  (e: 'update', value: string): void
}>()
```


#### 使用类型声明时的默认道具值

仅类型的 `defineProps` 声明的一个缺点是它没有办法为 `props` 提供默认值。为了解决这个问题，还提供了一个 `withDefaults` 编译器宏：

```typescript
interface Props {
  msg?: string
  labels?: string[]
}

const props = withDefaults(defineProps<Props>(), {
  msg: 'hello',
  labels: () => ['one', 'two']
})
```

### `defineExpose()`

默认情况下，使用 `<script setup>` 的组件是对外封闭的 - 即通过模板引用或 `$parent` 链检索的组件的公共实例不会暴露在 `<script setup>` 中声明的任何绑定。

要在 `<script setup>` 组件中显式公开属性，请使用 `defineExpose` 编译器宏：

```typescript
import { ref } from 'vue'

const a = 1
const b = ref(2)

defineExpose({
  a,
  b
})
```

当父级通过模板 `refs` 获取此组件的实例时，检索到的实例将具有 `{ a: number, b: number }` 的类型（就像在普通实例上一样，`refs` 会自动展开）。

## 动态组件

有的时候，在不同组件之间进行动态切换是非常有用的，可以通过 Vue 的 `<component>` 元素加一个特殊的 `is` 属性来实现动态组件：

```vue
<script setup lang="ts">
import A from "./A.vue"
import B from './B.vue'
import C from './C.vue'

import { markRaw, reactive } from "vue";

type Tab = {
    name: string,
    component: any
}

let tabs = reactive<Tab[]>([
    {
        name: "A",
        component: markRaw(A)
    },
    {
        name: "B",
        component: markRaw(B)
    },
    {
        name: "C",
        component: markRaw(C)
    }
])

let current = reactive({
    component: tabs[0].component
})

let switchTab = (tab: Tab) => {
    current.component = tab.component
}
</script>

<template>
    <div>
        <button :key="tab.name" v-for="tab in tabs" @click="switchTab(tab)">{{ tab.name }}</button>
        <component :is="current.component"></component>
    </div>
</template>
```

## 插槽

在某些场景中，我们可能想要为子组件传递一些模板片段，让子组件在它们的组件中渲染这些片段。

举个例子，这里有一个 `<FancyButton>` 组件，可以像这样使用：

```vue
<FancyButton>
  Click me! <!-- 插槽内容 -->
</FancyButton>
```

而 `<FancyButton>` 的模板是这样的：

```vue
<button class="fancy-btn">
  <slot></slot> <!-- 插槽插口 -->
</button>
```

`<slot>` 元素是一个**插槽的插口**，标示了父元素提供的**插槽内容**将在哪里被渲染。

![插槽](imgs/%E6%8F%92%E6%A7%BD.png)

最终渲染出的 DOM 是这样：

```vue
<button class="fancy-btn">
  Click me!
</button>
```

### 渲染作用域

插槽内容可以访问到父组件的数据作用域，因为插槽内容本身是在父组件模板中定义的。举个例子：

```vue
<span>{{ message }}</span>
<FancyButton>{{ message }}</FancyButton>
```

这里的两个 `{{ message }}` 插值表达式渲染的内容都是一样的。

插槽内容无法访问子组件的数据，请牢记一条规则：

> 任何父组件模板中的东西都只被编译到父组件的作用域中；而任何子组件模板中的东西都只被编译到子组件的作用域中。

### 默认内容

在外部没有提供任何内容的情况下，为插槽指定默认内容用于渲染是很有用的。比如在 `<SubmitButton>` 组件中，如果我们想在父组件没有提供任何插槽内容时，把“Submit”文本渲染到 `<button>` 内。需要将“Submit”写在 `<slot>` 标签之间，使其成为默认内容：

```vue
<button type="submit">
  <slot>
    Submit <!-- 默认内容 -->
  </slot>
</button>
```

当我们在父组件中使用 `<SubmitButton>` 但不提供任何插槽内容：

```vue
<SubmitButton />
```
那么将渲染默认的“Submit”单词：

```vue
<button type="submit">Submit</button>
```

### 具名插槽

有时在一个组件中包含多个插槽的插口是很有用的。举个例子，在一个 <BaseLayout> 组件中，有如下这样的模板：

```vue
<div class="container">
  <header>
    <!-- 标题内容放这里 -->
  </header>
  <main>
    <!-- 主要内容放这里 -->
  </main>
  <footer>
    <!-- 底部内容放这里 -->
  </footer>
</div>
```

对于这种场景，`<slot>` 元素可以有一个特殊的 attribute `name`，用来给各个插槽分配唯一的 ID，以确定每一处要渲染的内容：

```vue
<div class="container">
  <header>
    <slot name="header"></slot>
  </header>
  <main>
    <slot></slot>
  </main>
  <footer>
    <slot name="footer"></slot>
  </footer>
</div>
```

没有提供 `name` 的 `<slot>` 插口会隐式地命名为“default”。

在父组件中使用 `<BaseLayout>` 时，我们需要一种方式将多个插槽内容传入到各自目标插槽的插口。此时就需要用到**具名插槽**了，要为具名插槽传入内容，我们需要使用一个含 `v-slot` 指令的 `<template>` 元素，并将目标插槽的名字传给该指令：

```vue
<BaseLayout>
  <template v-slot:header>
    <!-- header 插槽的内容放这里 -->
  </template>
</BaseLayout>
```

`v-slot` 有对应的简写 `#`，因此 `<template v-slot:header>` 可以简写为 `<template #header>`。其意思就是“将这部分模板片段传入子组件的 header 插槽中”。

![具名插槽](imgs/%E5%85%B7%E5%90%8D%E6%8F%92%E6%A7%BD.png)

下面我们给出完整的、向 `<BaseLayout>` 传递插槽内容的代码，指令均使用的是缩写形式：

```vue
<BaseLayout>
  <template #header>
    <h1>Here might be a page title</h1>
  </template>

  <template #default>
    <p>A paragraph for the main content.</p>
    <p>And another one.</p>
  </template>

  <template #footer>
    <p>Here's some contact info</p>
  </template>
</BaseLayout>
```

当一个组件同时接收默认插槽和具名插槽时，所有位于顶级的非 `<template>` 节点都被隐式地视为默认插槽的内容。所以上面也可以写成：

```vue
<BaseLayout>
  <template #header>
    <h1>Here might be a page title</h1>
  </template>

  <!-- 隐式的默认插槽 -->
  <p>A paragraph for the main content.</p>
  <p>And another one.</p>

  <template #footer>
    <p>Here's some contact info</p>
  </template>
</BaseLayout>
```
### 动态插槽

动态指令参数在 `v-slot` 上也是有效的，即可以定义下面这样的动态插槽名：

```vue
<base-layout>
  <template v-slot:[dynamicSlotName]>
    ...
  </template>

  <!-- 缩写为 -->
  <template #[dynamicSlotName]>
    ...
  </template>
</base-layout>
```

### 作用域插槽

在上面的渲染作用域中我们讨论到，插槽的内容无法访问到子组件的状态。

然而在某些场景下插槽的内容可能想要同时使用父组件域内和子组件域内的数据。要做到这一点，我们需要一种方法来让子组件在渲染时将一部分数据提供给插槽。

我们也确实有办法这么做！可以像对组件传递 prop 那样，向一个插槽的插口上传递 attribute：

```vue
<!-- <MyComponent> 的模板 -->
<div>
  <slot :text="greetingMessage" :count="1"></slot>
</div>
```

当需要接收插槽 prop 时，默认插槽和具名插槽的使用方式有一些小区别。下面我们将先展示默认插槽如何接受 prop，通过子组件标签上的 `v-slot` 指令，直接接收到了一个插槽 prop 对象：

```vue
<MyComponent v-slot="slotProps">
  {{ slotProps.text }} {{ slotProps.count }}
</MyComponent>
```

![作用于插槽](imgs/%E4%BD%9C%E7%94%A8%E5%9F%9F%E6%8F%92%E6%A7%BD.svg)

`v-slot="slotProps"` 可以类比这里的函数签名，和函数的参数类似，我们也可以在 `v-slot` 中使用解构：

```vue
<MyComponent v-slot="{ text, count }">
  {{ text }} {{ count }}
</MyComponent>
```

## 异步组件

在大型项目中，我们可能需要拆分应用为更小的块，并仅在需要时再从服务器加载相关组件。为实现这点，Vue 提供了一个 `defineAsyncComponent` 方法：

```typescript
import { defineAsyncComponent } from 'vue'

const AsyncComp = defineAsyncComponent(() => {
  return new Promise((resolve, reject) => {
    // ...从服务器获取组件
    resolve(/* 获取到的组件 */)
  })
})
// ... 像使用其他一般组件一样使用 `AsyncComp`
```

如你所见，`defineAsyncComponent` 方法接收一个返回 `Promise` 的加载函数。这个 `Promise` 的 `resolve` 回调方法应该在从服务器获得组件定义时调用。你也可以调用 `reject(reason)` 表明加载失败。

ES 模块动态导入也会返回一个 Promise，所以多数情况下我们会将它和 defineAsyncComponent 搭配使用，类似 Vite 和 Webpack 这样的构建工具也支持这种语法，因此我们也可以用它来导入 Vue 单文件组件：

```typescript
import { defineAsyncComponent } from 'vue'

const AsyncComp = defineAsyncComponent(() =>
  import('./components/MyComponent.vue')
)
```

最后得到的 AsyncComp 是一个包装器组件，仅在页面需要它渲染时才调用加载函数。另外，它还会将 props 传给内部的组件，所以你可以使用这个异步的包装器组件无缝地替换原始组件，同时实现延迟加载。

### 搭配 Suspense 使用

异步组件通常会搭配内置的 `<Suspense>` 组件一起使用。

## `<Suspense>`

`<Suspense>` 是一个内置组件，用来在组件树中编排异步依赖。它可以在等待组件树下的多个嵌套异步依赖项解析完成时，呈现加载状态。

`<Suspense>` 用于解决如何与异步依赖进行交互的，我们需要想象这样一种组件层级结构：

```text
<Suspense>
└─ <Dashboard>
   ├─ <Profile>
   │  └─ <FriendStatus>（组件有异步的 setup()）
   └─ <Content>
      ├─ <ActivityFeed> （异步组件）
      └─ <Stats>（异步组件）
```

在这个组件树中有多个嵌套组件，要渲染出它们，首先得解析一些异步资源。如果没有 `<Suspense>`，则它们每个都需要处理自己的加载、报错和完成状态。在最坏的情况下，我们可能会在页面上看到三个旋转的加载态，在不同的时间显示出内容。

有了 `<Suspense>` 组件后，我们就可以在等待整个多层级组件树中的各个异步依赖获取结果时，在顶层展示出加载中或加载失败的状态。

`<Suspense>` 可以等待的异步依赖有两种：

1. 带有异步 `setup()` 钩子的组件。这也包含了使用 `<script setup>` 时有顶层 `await` 表达式的组件。
    - 组合式 API 中组件的 setup() 钩子可以是异步的：
        ```typescript
        export default {
          async setup() {
            const res = await fetch(...)
            const posts = await res.json()
            return {
              posts
            }
          }
        }
        ```
    - 如果使用 `<script setup>`，那么顶层 `await` 表达式会自动让该组件成为一个异步依赖：
        ```vue
        <script setup>
        const res = await fetch(...)
        const posts = await res.json()
        </script>

        <template>
          {{ posts }}
        </template>
        ```

2. 异步组件。
    - 异步组件默认就是 “suspensible” 的。这意味着如果组件关系链上有一个 `<Suspense>`，那么这个异步组件就会被当作这个 `<Suspense>` 的一个异步依赖。在这种情况下，加载状态是由 `<Suspense>` 控制，而该组件自己的加载、报错、延时和超时等选项都将被忽略。
    - 异步组件也可以通过在选项中指定 `suspensible: false` 表明不用 `Suspense` 控制，并让组件始终自己控制其加载状态。



### 加载中状态

`<Suspense>` 组件有两个插槽：`#default` 和 `#fallback`。两个插槽都只允许一个直接子节点。在可能的时候都将显示默认槽中的节点。否则将显示后备槽中的节点。

```vue
<Suspense>
  <!-- 具有深层异步依赖的组件 -->
  <Dashboard />

  <!-- 在 #fallback 插槽中显示 “正在加载中” -->
  <template #fallback>
    Loading...
  </template>
</Suspense>
```

在初始渲染时，`<Suspense>` 将在内存中渲染其默认的插槽内容。如果在这个过程中遇到任何异步依赖，则会进入**挂起**状态。在挂起状态期间，展示的是后备内容。当所有遇到的异步依赖都完成后，`<Suspense>` 会进入**完成**状态，并将展示出默认插槽的内容。

## `<Teleport>`

`<Teleport>` 是一个内置组件，使我们可以将一个组件的一部分模板“传送”到该组件的 DOM 层次结构之外的 DOM 节点中。

有时我们可能会遇到以下情况：组件模板的一部分在逻辑上属于它，但从视图角度来看，在 DOM 中它应该显示在 Vue 应用之外的其他地方。

最常见的例子是构建一个**全屏的模态框**时。理想情况下，我们希望模态框的按钮和模态框本身是在同一个组件中，因为它们都与组件的开关状态有关。但这意味着该模态框将与按钮一起呈现，并且位于应用程序的 DOM 更深的层次结构中。在想要通过 CSS 选择器定位该模态框时非常困难。

Teleport 是一种能够将我们的模板渲染至指定DOM节点，不受父级`style`、`v-show`等属性影响，但父级的 `data`、`prop` 数据依旧能够共用的技术。

### 全屏模态框示例

这个组件中有一个 `<button>` 按钮来触发打开模态框，和一个 `class` 名为 `.modal` 的 `<div>`，它包含了模态框的内容和一个用来关闭的按钮。

```vue
<script lang="ts" setup>
import { ref } from 'vue'

const open = ref(false)
</script>

<template>
    <div>
        <button @click="open = true">Open Modal</button>

        <div v-if="open" class="modal">
            <p>Hello from the modal!</p>
            <button @click="open = false">Close</button>
        </div>
    </div>
</template>

<style scoped>
.modal {
    position: fixed;
    border: 1px solid;
    top: 50%;
    left: 50%;
    z-index: 999;
}
</style>
```

当在初始 HTML 结构中使用这个组件时，会有一些潜在的问题：

- `position: fixed` 能够相对于视口放置的条件是：没有任何祖先元素设置了 `transform`、`perspective` 或者 `filter` 样式属性。而如果我们想要用 CSS `transform` 为组件的祖先节点设置动画，则会破坏模态框的布局结构！
- 这个模态框的 `z-index` 被包含它的元素所制约。如果有其他元素与其祖先组件重叠并有更高的 `z-index`，则它会覆盖住我们的模态框。

`<Teleport>` 提供了一个更简洁的方式来解决此类问题，使我们无需考虑那么多层 DOM 结构的问题。让我们用 `<Teleport>` 改写一下组件的 `<template>`：

```html
<div>
    <button @click="open = true">Open Modal</button>
    <Teleport to="body">
    <div v-if="open" class="modal">
        <p>Hello from the modal!</p>
        <button @click="open = false">Close</button>
    </div>
    </Teleport>
</div>
```

为 `<Teleport>` 指定的目标 `to` 期望接收一个 CSS 选择器字符串或者一个真实的 DOM 节点。这里我们其实就是让 Vue 去“传送这部分模板片段到 `body` 标签下”。

## `<KeepAlive>`

`<KeepAlive>` 是一个内置组件，使我们可以在动态切换多个组件时视情况缓存组件实例。

默认情况下，一个活跃的组件实例会在切走后被卸载。这会导致它丢失其中所有已变化的状态。

在下面的例子中，会在登录组件 `<Login>` 和 注册组件 `<Register>` 两个组件之间来回切换。

```vue
<button @click="flag = !flag">切换</button>
<Login v-if="flag"></Login>
<Register v-else></Register>
```

在来回尝试切换组件的时发现之前的组件状态都被重置了。

在切换时创建新的组件实例通常是有用的行为，但在这个例子中，我们是的确想要组件能在非活跃状态时保留它们的状态。要解决这个问题，我们可以用内置的 `<KeepAlive>` 组件将这些动态组件包装起来：

```vue
<button @click="flag = !flag">切换</button>
<KeepAlive include="Login">
    <Login v-if="flag"></Login>
    <Register v-else></Register>
</KeepAlive>
```

`<KeepAlive>` 组件提供了 `include`， `exclude` 和 `max` 三个属性分别用户包括缓存组件、排除缓存组件和限制缓存组件的最大数目。

### 缓存实例的生命周期#

当一个组件实例从 DOM 上移除但因为被 `<KeepAlive>` 缓存而仍作为组件树的一部分时，它将变为不活跃状态(`deactivated`)而不是被卸载(`unmounted`)。当一个组件实例作为缓存树的一部分插入到 DOM 中时，它将重新被激活(`activated`)。

一个持续存在的组件可以通过 `onActivated()` 和 `onDeactivated()` 注册相应的两个状态的生命周期钩子。

## `<Transition>`

Vue 提供了 `<Transition>` 用于帮助制作基于状态变化的过渡和动画。`<Transition>` 会在一个元素或组件进入和离开 DOM 时应用动画。

`<Transition> `是一个内置组件，这意味着它在任意别的组件中都可以被使用，无需注册。它可以将进入和离开动画应用到通过默认插槽传递给它的元素或组件上。进入或离开可以由以下的条件之一触发：

- 由 `v-if` 所带来的条件渲染
- 由 `v-show` 所带来的条件显示
- 由特殊元素 `<component>` 切换的动态组件

当一个 `<Transition> `组件中的元素被插入或移除时，会发生下面这些事情：

1. Vue 会自动检测目标元素是否应用了 CSS 过渡或动画。如果是，则一些 CSS 过渡 class 会在适当的时机被添加和移除。
2. 如果有作为监听器的 JavaScript 钩子，这些钩子函数会在适当时机被调用。
3. 如果没有探测到 CSS 过渡或动画、没有提供 JavaScript 钩子，那么 DOM 的插入、删除操作将在浏览器的下一个动画帧上执行。

### 基于CSS的过度

一共有 6 个应用于进入与离开过渡效果的 CSS class。

![CSS过渡class](imgs/CSS过渡clas.png)

1. `v-enter-from`：进入动画的起始状态。在元素插入之前添加，在元素插入完成后的下一帧移除。
2. `v-enter-active`：进入动画的生效状态。应用于整个进入动画阶段。在元素被插入之前添加，在过渡或动画完成之后移除。这个 class 可以被用来定义进入动画的持续时间、延迟与速度曲线类型。
3. `v-enter-to`：进入动画的结束状态。在元素插入完成后的下一帧被添加 (也就是 v-enter-from 被移除的同时)，在过渡或动画完成之后移除。
4. `v-leave-from`：离开动画的起始状态。在离开过渡效果被触发时立即添加，在一帧后被移除。
5. `v-leave-active`：离开动画的生效状态。应用于整个离开动画阶段。在离开过渡效果被触发时立即添加，在过渡或动画完成之后移除。这个 class 可以被用来定义离开动画的持续时间、延迟与速度曲线类型。
6. `v-leave-to`：离开动画的结束状态。在一个离开动画被触发后的下一帧被添加 (也就是 v-leave-from 被移除的同时)，在过渡或动画完成之后移除。

#### 为过渡命名

可以通过一个 `name` prop 来声明一种过渡：

```vue
<Transition name="fade">
  ...
</Transition>
```

对于一个已命名的过渡，它的过渡相关 class 会以其名字而不是 `v` 作为前缀。比如，上方例子中被应用的 class 将会是 `fade-enter-active` 而不是 `v-enter-active`。

#### 自定义过渡 class

你也可以向 `<Transition>` 传递以下的 props 来指定自定义的过渡 class：

- `enter-from-class`
- `enter-active-class`
- `enter-to-class`
- `leave-from-class`
- `leave-active-class`
- `leave-to-class`

传入的这些 class 会覆盖相应阶段的默认 class 名。这个功能在你想要在 Vue 的动画机制下集成其他的第三方 CSS 动画库时非常有用，比如 [Animate.css](https://animate.style/)：

### JavaScript 钩子

你可以通过监听 `<Transition>` 组件事件的方式在过渡过程中挂上钩子函数：

```html
<Transition
  @before-enter="onBeforeEnter"
  @enter="onEnter"
  @after-enter="onAfterEnter"
  @enter-cancelled="onEnterCancelled"
  @before-leave="onBeforeLeave"
  @leave="onLeave"
  @after-leave="onAfterLeave"
  @leave-cancelled="onLeaveCancelled"
>
  <!-- ... -->
</Transition>
```

```typescript
// 在元素被插入到 DOM 之前被调用
// 用这个来设置元素的 "enter-from" 状态
function onBeforeEnter(el) {},

// 在元素被插入到 DOM 之后的下一帧被调用
// 用这个来开始进入动画
function onEnter(el, done) {
  // 调用回调函数 done 表示过渡结束
  // 如果与 CSS 结合使用，则这个回调是可选参数
  done()
}

// 当进入过渡完成时调用。
function onAfterEnter(el) {}
function onEnterCancelled(el) {}

// 在 leave 钩子之前调用
// 大多数时候，你应该只会用到 leave 钩子
function onBeforeLeave(el) {}

// 在离开过渡开始时调用
// 用这个来开始离开动画
function onLeave(el, done) {
  // 调用回调函数 done 表示过渡结束
  // 如果与 CSS 结合使用，则这个回调是可选参数
  done()
}

// 在离开过渡完成、
// 且元素已从 DOM 中移除时调用
function onAfterLeave(el) {}

// 仅在 v-show 过渡中可用
function leaveCancelled(el) {}
```

这些钩子可以与 CSS 过渡或动画结合使用，也可以单独使用。

在使用仅由 JavaScript 执行的动画时，最好是添加一个 `:css="false"` prop。这显式地向 Vue 表明跳过对 CSS 过渡的自动探测。除了性能稍好一些之外，还可以防止 CSS 规则意外地干扰过渡。

```vue
<Transition :css="false">
  ...
</Transition>
```

在有了 `:css="false"` 后，我们就自己全权负责控制什么时候过渡结束了。这种情况下对于 `@enter` 和 `@leave` 钩子来说，回调函数 `done` 就是必须的。否则，钩子将被同步调用，过渡将立即完成。

JavaScript 钩子可以使用 [GreenSock](https://greensock.com/) 或者 [Anime.js](https://animejs.com/) 库来获取需要的动画效果。

#### 出现时过渡

如果你想在某个节点初次渲染时应用一个过渡效果，你可以添加 `appear` attribute：

```vue
<Transition appear>
  ...
</Transition>
```

## `<TransitionGroup>`

<TransitionGroup> 是一个内置组件，设计用于呈现一个列表中的元素或组件的插入、移除和顺序改变的动画效果。

`<TransitionGroup>` 支持和 `<Transition>` 基本相同的 prop、CSS 过渡 class 和 JavaScript 钩子监听器，但有以下几点区别：

- 默认情况下，它不会渲染一个包装器元素。但你可以通过传入 `tag` prop 来指定一个元素作为包装器元素来渲染。
- 过渡模式（即先执行元素的离开动画，之后在执行元素的进入动画）在这里不可用，因为我们不再是在互斥的元素之间进行切换。
- 其中的元素总是必须有一个独一无二的 `key` attribute。
- CSS 过渡 class 会被应用在其中的每一个元素上，而不是这个组的容器上。

### 示例

这里是 `<TransitionGroup>` 对一个 `v-for` 列表应用进入 / 离开过渡的示例：

```vue
<TransitionGroup name="list" tag="ul">
  <li v-for="item in items" :key="item">
    {{ item }}
  </li>
</TransitionGroup>
```


```css
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
```

### 移动过渡

上面的示例有一些明显的缺陷：当某一项被插入或移除时，它周围的元素会立即发生“跳跃”而不是平稳地移动。我们可以通过添加一些额外的 CSS 规则来解决这个问题：

```css
.list-move, /* 对移动中的元素应用的过渡 */
.list-enter-active,
.list-leave-active {
  transition: all 0.5s ease;
}

.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(30px);
}
```

## 状态过度

通过动画库 Vue 也同样可以给数字、SVG、背景颜色等添加过度动画。

```vue
<script setup lang='ts'>
import { reactive, watch } from "vue";

import gsap from "gsap"

let num = reactive({
    current: 0,
    approximation: 0
})

watch(() => num.current, (newVal, oldVal) => {
    gsap.to(num, {
        duration: 1,
        approximation: newVal
    })
})
</script>

<template>
    <div>
        <input v-model="num.current" step="20" type="number">
        <div>{{ num.approximation.toFixed(0) }}</div>
    </div>
</template>
```

## `provide()` & `inject()` 依赖注入

通常情况下，当我们需要从父组件向子组件传递数据时，会使用 props。想象一下这样的结构：有一些多层级嵌套的组件，形成了一颗巨大的组件树，而某个深层的子组件需要一个较远的祖先组件中的部分内容。在这种情况下，如果仅使用 props 则必须将其沿着组件链逐级传递下去，这会非常麻烦：

![属性钻井](imgs/%E5%B1%9E%E6%80%A7%E9%92%BB%E4%BA%95.png)

这里的 `<Footer>` 组件可能其实根本不关心这些 props，但它仍然需要定义并将它们传递下去使得 `<DeepChild>` 能访问到这些 props，如果组件链路非常长，可能会影响到更多这条路上的组件。这一过程被称为“prop drilling”（属性钻井），这似乎不太好解决。

为解决这一问题，可以使用 `provide` 和 `inject`。一个父组件相对于其所有的后代组件，会作为依赖提供者。任何后代的组件树，无论层级有多深，都可以注入由父组件提供给整条链路的依赖。

![provide-inject](imgs/provide-inject.png)

### Provide (供给)

要为组件后代供给数据，需要使用到 `provide()` 函数：

```vue
<script setup>
import { provide } from 'vue'

provide(/* 注入名 */ 'message', /* 值 */ 'hello!')
</script>
```

如果不使用 `<script setup>`，请确保 `provide()` 是在 `setup()` 同步调用的：

```js
import { provide } from 'vue'

export default {
  setup() {
    provide(/* 注入名 */ 'message', /* 值 */ 'hello!')
  }
}
```

`provide()` 函数接收两个参数。

- 第一个参数被称为注入名，可以是一个字符串或是一个 Symbol。后代组件会用注入名来查找期望注入的值。一个组件可以多次调用 provide()，使用不同的注入名，注入不同的依赖值。
- 第二个参数是供给的值，值可以是任意类型，包括响应式的状态，比如一个 `ref` 或者 `reactive` 之类的响应式对象。

### Inject (注入)

要注入祖先组件供给的数据，需使用 `inject()` 函数：

```vue
<script setup>
import { inject } from 'vue'

const message = inject('message')
</script>
```

如果供给的值是一个 `ref`，注入进来的就是它本身，而不会自动解包。这使得被注入的组件保持了和供给者的响应性链接。

带有响应性的供给 + 注入完整示例

同样的，如果没有使用 `<script setup>`，`inject()` 需要在 `setup()` 同步调用：

```js
import { inject } from 'vue'

export default {
  setup() {
    const message = inject('message')
    return { message }
  }
}
```

默认情况下，`inject` 假设传入的注入名会被某个祖先链上的组件提供。如果该注入名的确没有任何组件提供，则会抛出一个运行时警告。

如果在供给的一侧看来属性是可选提供的，那么注入时我们应该声明一个默认值，和 `props` 类似：

```js
// 如果没有祖先组件提供 "message"
// `value` 会是 "这是默认值"
const value = inject('message', '这是默认值')
```

在一些场景中，默认值可能需要通过调用一个函数或初始化一个类来取得。为了避免在不使用可选值的情况下进行不必要的计算或产生副作用，我们可以使用工厂函数来创建默认值：

```js
const value = inject('key', () => new ExpensiveClass())
```

## 兄弟组件传参

### 借助父组件传参

示例：

`SiblingA` 组件将输入框的值传递给兄弟组件 `SiblingB`。

```vue
<script setup lang="ts">
import { ref } from "vue"

let siblingText = ref("")

const onChange = (text: string) => {
    siblingText.value = text
}
</script>

<template>
    <div>
        <SiblingA @on-change="onChange"></SiblingA>
        <SiblingB :text="siblingText"></SiblingB>
    </div>
</template>
```

```vue
<!-- SiblingA.vue -->
<script setup lang="ts">
import { ref, watch } from "vue"

let text = ref("")

const emit = defineEmits<{
    (e: "on-change", text: string): void
}>()

watch(text, (newVal) => {
    emit("on-change", newVal)
})
</script>

<template>
    <div>
        <input v-model="text" type="text">
    </div>
</template>
```

```vue
<!-- SiblingB.vue -->
<script setup lang="ts">
type SiblingText = {
    text: string
}

defineProps<SiblingText>()
</script>

<template>
    <div>
        {{ text }}
    </div>
</template>
```

### Event Bus

在 Vue2 可以使用 `$emit` 传递 `$on` 监听 `$emit` 传递过来的事件，原理其实是运用了JS设计模式之发布订阅模式。

编写一个事件总线：

```typescript
type EventBusClass<T> = {
    emit: (name: T) => void
    on: (name: T, callback: Function) => void
}

type EventKey = string | number | symbol

type EventMap = {
    [key: EventKey]: Array<Function>
}

class EventBus<T extends EventKey> implements EventBusClass<T> {
    private map: EventMap

    constructor() {
        this.map = {}
    }

    emit(name: T, ...args: Array<any>) {
        let callbacks: Array<Function> = this.map[name]
        callbacks.forEach(cb => {
            cb.apply(this, args)
        })
    }

    on(name: T, callback: Function) {
        let callbacks: Array<Function> = this.map[name] || [];
        callbacks.push(callback)
        this.map[name] = callbacks
    }
}

export default new EventBus<EventKey>()
```

将上面的基于父组件传递参数的方式改为基于 Event Bus 的传参来实现相同的效果：

```vue
<template>
    <div>
        <EventBusA></EventBusA>
        <EventBusB></EventBusB>
    </div>
</template>
```

```vue
<!-- EventBusA.vue -->
<script setup lang="ts">
import { ref, watch } from "vue"
import EventBus from "../../EventBus"

let text = ref("")

watch(text, (newVal) => {
    EventBus.emit("on-change", newVal)
})
</script>

<template>
    <div>
        <input v-model="text" type="text">
    </div>
</template>

<style scoped lang="less">
</style>
```

```vue
<!-- EventBusB.vue -->
<script setup lang="ts">
import { ref } from "vue"
import EventBus from "../../EventBus";

let text = ref("")

EventBus.on("on-change", (val: string) => {
    text.value = val
})
</script>

<template>
    <div>
        {{ text }}
    </div>
</template>

<style scoped lang="less">
</style>
```

### Mitt

使用 Mitt 库作为 Event Bus 提供事件发布订阅功能。

```typescript
import { createApp } from 'vue'
import App from './App.vue'

import mitt, { Emitter } from 'mitt';

// 为时间设置泛型以获得改进的 mitt 实例方法的类型推断。
type Events = {
    change: string
}

// 自定义$Bus全局属性添加到组件
const emitter = mitt<Events>()

declare module '@vue/runtime-core' {
    export interface ComponentCustomProperties {
        $Bus: Emitter<Events>
    }
}

let app = createApp(App)

app.config.globalProperties.$Bus = emitter

app.mount('#app')
```

```vue
<template>
    <div>
        <MittA></MittA>
        <MittB></MittB>
    </div>
</template>
```

```vue
<!-- MittA.vue -->
<script setup lang="ts">
import { ref, getCurrentInstance, watch } from "vue"

let text = ref("")

// Tips: getCurrentInstance 不能写在回调函数内
const instance = getCurrentInstance()
console.log(instance);

watch(text, (newVal) => {
    instance?.proxy?.$Bus.emit("change", newVal)
})
</script>

<template>
    <div>
        <input v-model="text" type="text">
    </div>
</template>

<style scoped lang="less">
</style>
```

```vue
<!-- MittB.vue -->
<script setup lang="ts">
import { ref, getCurrentInstance } from "vue"

let text = ref("")

getCurrentInstance()?.proxy?.$Bus.on("change", (val) => {
    text.value = val
})
</script>

<template>
    <div>
        {{ text }}
    </div>
</template>

<style scoped lang="less">
</style>
```

## 组件事件

### 触发与监听事件

在组件的模板表达式中，可以直接使用 `$emit` 函数**触发自定义事件** (例如：在 `v-on` 的处理函数中)：

```html
<!-- MyComponent -->
<button @click="$emit('someEvent')">click me</button>
```

父组件可以通过 `v-on` (缩写为 `@`) 来**监听事件**：

```html
<MyComponent @some-event="callback" />
```

### 事件参数

有时候我们会需要在触发事件时附带一个特定的值。举个例子，我们想要 `<BlogPost>` 组件来管理文本会缩放得多大。在这个场景下，我们可以给 `$emit` 提供一个值作为额外的参数：

```html
<button @click="$emit('increaseBy', 1)">
  Increase by 1
</button>
```

然后我们在父组件中监听事件，我们可以先简单写一个内联的箭头函数作为监听器，此时可以访问到事件附带的参数：

```html
<MyButton @increase-by="(n) => count += n" />
```

### 声明触发的事件

组件要触发的事件可以显式地通过 `defineEmits()` 宏来声明。

```vue
<script setup>
const emit = defineEmits(['inFocus', 'submit'])
</script>
```

返回的 `emit` 函数可以用来在 JavaScript 代码中触发事件。

如果你正在搭配 `<script setup>` 使用 TypeScript，也可以使用纯类型标注来声明触发的事件：

```vue
<script setup lang="ts">
const emit = defineEmits<{
  (e: 'change', id: number): void
  (e: 'update', value: string): void
}>()
</script>
```

### 事件校验

和对 prop 添加类型校验的方式类似，所有触发的事件也可以使用对象形式来描述。

要为事件添加校验，那么事件可以被赋值为一个函数，接受的参数就是抛出事件时传入 `emit` 的内容，返回一个布尔值来表明事件是否合法。

```vue
<script setup>
const emit = defineEmits({
  // 没有校验
  click: null,

  // 校验 submit 事件
  submit: ({ email, password }) => {
    if (email && password) {
      return true
    } else {
      console.warn('Invalid submit event payload!')
      return false
    }
  }
})

function submitForm(email, password) {
  emit('submit', { email, password })
}
</script>
```

## `v-model` 与事件

自定义事件可以用来创建对应 `v-model` 的自定义输入：

```html
<input v-model="searchText" />
```

和下面这段代码是等价的：

```html
<input
  :value="searchText"
  @input="searchText = ($event.target as HTMLInputElement).value"
/>
```

当使用在一个组件上时，`v-model` 是这样做的：

```html
<CustomInput v-model="searchText" />

<!-- v-model 的等价形式 -->
<CustomInput
  :modelValue="searchText"
  @update:modelValue="newValue => searchText = newValue"
/>
```

为了使组件能像这样工作，内部的 `<input>` 组件必须：

- 绑定 `value` attribute 到 `modelValue` prop
- 输入新的值时在 `input` 元素上触发 `update:modelValue` 事件

这里是相应的代码：

```vue
<!-- CustomInput.vue -->
<script setup lang="ts">
defineProps<{ modelValue: string }>()
defineEmits<{
    (e: "update:modelValue", s: string): void
}>()
</script>

<template>
    <div>
        <input :value="modelValue" @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)" />
    </div>
</template>
```

### `v-model` 的参数

默认情况下，`v-model` 在组件上都是使用 `modelValue` 作为 prop，以 `update:modelValue` 作为对应的事件。我们可以通过给 `v-model` 指定一个参数来更改这些名字：

```html
<MyComponent v-model:title="bookTitle" />
```

在这个例子中，子组件应该有一个 `title` prop，并通过触发 `update:title` 事件更新父组件值：

```vue
<!-- MyComponent.vue -->
<script setup>
defineProps(['title'])
defineEmits<{ (e: "update:title", s: string): void }>()
</script>

<template>
  <input
    type="text"
    :value="title"
    @input="$emit('update:title', ($event.target as HTMLInputElement).value)"
  />
</template>
```

通过使用不同的 `v-model` 的参数就可以实现多个 `v-model` 的绑定。

### 处理 `v-model` 修饰符

当我们在学习输入绑定时，我们知道了 `v-model` 有一些内置的修饰符，例如 `.trim`，`.number` 和 `.lazy`。然而在某些场景下，你可能想要添加自定义的修饰符。

我们一起来创建一个自定义的修饰符 `capitalize` 用于将 `v-model` 绑定输入的字符串值第一个字母转为大写，同时还自定义了一个修饰符 `upper` 用于将 `v-model` 参数 `title` 全部大写：

```html
<MyModifier v-model.capitalize="modelText" v-model:title.upper="titleText" />
```

```vue
<!-- MyModifier.vue -->
<script setup lang="ts">
type Props = {
    modelValue: string,
    modelModifiers?: { capitalize: boolean },
    title: string,
    titleModifiers?: { upper: boolean }
}

const props = defineProps<Props>()

const emit = defineEmits<{
    (e: "update:modelValue", s: string): void,
    (e: "update:title", s: string): void,
}>()

function emitValue(e: Event) {
    let value = (<HTMLInputElement>e.target).value
    if (props.modelModifiers?.capitalize) {
        value = value.charAt(0).toUpperCase() + value.slice(1)
    }
    emit('update:modelValue', value)
}

function emitTitle(e: Event) {
    let value = (<HTMLInputElement>e.target).value
    if (props.titleModifiers?.upper) {
        value = value.toUpperCase()
    }
    emit('update:title', value)
}
</script>

<template>
    <div>
        <input type="text" :value="modelValue" @input="emitValue" />
        <input type="text" :value="title" @input="emitTitle" />
    </div>
</template>
```

## 自定义指令

除了 Vue 内置的一系列指令 (比如 `v-model` 或 `v-show`) 之外，Vue 还允许你注册自定义的指令。

一个自定义指令被定义为一个包含类似于组件的生命周期钩子的对象。钩子接收指令绑定到的元素。下面是一个自定义指令的例子，当一个 `input` 元素被 Vue 插入到 DOM 中后，它将被聚焦：

```vue
<script setup>
// 在模板中启用 v-focus
const vFocus = {
  mounted: (el) => el.focus()
}
</script>

<template>
  <input v-focus />
</template>
```

在 `<script setup>` 中，任何以 `v` 开头的驼峰式命名的变量都可以被用作一个自定义指令。在上面的例子中，`vFocus` 即可以在模板中以 `v-focus` 的形式使用。

如果不使用 `<script setup>`，自定义指令可以通过 `directives` 选项注册：

```javascript
export default {
  setup() {
    /*...*/
  },
  directives: {
    // 在模板中启用 v-focus
    focus: {
      /* ... */
    }
  }
}
```

将一个自定义指令全局注册到应用层级也是一种通用的做法：

```javascript
const app = createApp({})

// 使 v-focus 在所有组件中都可用
app.directive('focus', {
  /* ... */
})
```

### 指令钩子

一个指令的定义对象可以提供几种钩子函数 (都是可选的)：

```javascript
const myDirective = {
  // 在绑定元素的 attribute 前
  // 或事件监听器应用前调用
  created(el, binding, vnode, prevVnode) {
    // 下面会介绍各个参数的细节
  },
  // 在元素被插入到 DOM 前调用
  beforeMount() {},
  // 在绑定元素的父组件
  // 及他自己的所有子节点都挂载完成后调用
  mounted() {},
  // 绑定元素的父组件更新前调用
  beforeUpdate() {},
  // 在绑定元素的父组件
  // 及他自己的所有子节点都更新后调用
  updated() {},
  // 绑定元素的父组件卸载前调用
  beforeUnmount() {},
  // 绑定元素的父组件卸载后调用
  unmounted() {}
}
```

#### 钩子参数

指令的钩子会传递以下几种参数：

- `el`：指令绑定到的元素。这可以用于直接操作 DOM。
- `binding`：一个对象，包含以下 property。
  - `value`：传递给指令的值。例如在 `v-my-directive="1 + 1"` 中，值是 `2`。
  - `oldValue`：之前的值，仅在 `beforeUpdate` 和 `updated` 中可用。无论值是否更改，它都可用。
  - `arg`：传递给指令的参数 (如果有的话)。例如在 `v-my-directive:foo` 中，参数是 `"foo"`。
  - `modifiers`：一个包含修饰符的对象 (如果有的话)。例如在 `v-my-directive.foo.bar` 中，修饰符对象是 `{ foo: true, bar: true }`。
  - `instance`：使用该指令的组件实例。
  - `dir`：指令的定义对象。
- `vnode`：代表绑定元素的底层 VNode。
- `prevNode`：之前的渲染中代表指令所绑定元素的 VNode。仅在 `beforeUpdate` 和 `updated` 钩子中可用。

举个例子，像下面这样使用指令：

```vue
<script setup lang="ts">
import { Directive, DirectiveBinding } from 'vue';

type DirectiveValue = {
    background?: string
}

const vCustomDirect: Directive = {
    mounted(el: HTMLElement, binding: DirectiveBinding<DirectiveValue>, vnode, prevVNode) {
        if (binding.arg === 'style') {
            if (binding.value.background) {
                el.style.background = binding.value.background;
            }
        }

        if (binding.modifiers.focus) {
            el.focus()
        }
    }
}
</script>

<template>
    <div>
        <input type="text" v-custom-direct:style.focus="{ background: 'red' }">`
    </div>
</template>
```

### 简化形式

对于自定义指令来说，需要在 `mounted` 和 `updated` 上实现相同的行为、又并不关心其他钩子的情况很常见。此时我们可以将上面的指令 `v-custom-direct` 定义成一个下面这样的函数：

```typescript
const vCustomDirect: Directive = (el: HTMLElement, binding: DirectiveBinding<DirectiveValue>, vnode, prevVNode) => {
    if (binding.arg === 'style') {
        if (binding.value.background) {
            el.style.background = binding.value.background;
        }
    }

    if (binding.modifiers.focus) {
        el.focus()
    }
}
```

## 工具函数

我们利用生命周期钩子 [`onMounted()`](https://staging-cn.vuejs.org/api/composition-api-lifecycle.html#onmounted) 编写一个在图片挂载后将图片转化为 BASE64 的工具函数，工具函数能提高代码的复用性，能够在不同的组件中使用。

```typescript
type Option = {
    el: string
}

export default function (option: Option): Promise<{ baseUrl: string }> {
    return new Promise((resolve) => {
        onMounted(() => {
            let imgEl: HTMLImageElement = document.querySelector(option.el) as HTMLImageElement
            imgEl.onload = () => {
                resolve({ baseUrl: base64(imgEl) })
            }

            const base64 = (imgEl: HTMLImageElement): string => {
                const canvas = document.createElement('canvas')
                const ctx = canvas.getContext('2d')
                canvas.width = imgEl.width
                canvas.height = imgEl.height
                ctx?.drawImage(imgEl, 0, 0, canvas.width, canvas.height)
                return canvas.toDataURL('image/png')
            }
        })
    })
}
```

工具函数的使用：

```typescript
import useBase64 from "../../hooks"

useBase64({ el: "#img" }).then(res => console.log(res.baseUrl))
```

推荐一个实用工具库 [VueUse](https://github.com/vueuse/vueuse)。

## 全局函数和变量

通过应用[实例 API](https://staging-cn.vuejs.org/api/application.html) `createApp()` 或者 `createSSRApp()` 创建的应用实例 `app` 都会暴露一个 `config` 对象，其中包含了对这个应用的配置设定。

[`app.config.globalProperties`](https://staging-cn.vuejs.org/api/application.html#app-config-globalproperties) 是一个用于注册能够被应用内所有组件实例访问到的全局 property 的对象。

### 用法

```typescript
// 为时间设置泛型以获得改进的 mitt 实例方法的类型推断。
type Events = {
    change: string
}

// 自定义$Bus全局属性添加到组件
const emitter = mitt<Events>()

declare module '@vue/runtime-core' {
    export interface ComponentCustomProperties {
        $Bus: Emitter<Events>,
        $filter: { format: (str: string) => string }
        $env: "dev"
    }
}

let app = createApp(App)

app.config.globalProperties.$Bus = emitter
app.config.globalProperties.$filter = {
    format(str: string): string {
        return `真.${str}`
    }
}
app.config.globalProperties.$env = "dev"

app.component("Card", Card).mount('#app')
```

上述代码在应用全局注册了一个事件监听器 `$Bus`、一个对象 `$filter` 和一个字符串 `$env`。这些全局变量在应用的任意组件模板上都可用，并且也可以通过任意组件实例的 `this` 访问到。

还需要注意的是，为了 TypeScript 的类型提示需要对全局变量进行声明。
