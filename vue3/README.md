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