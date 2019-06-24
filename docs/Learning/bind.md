## 介绍

双向绑定其实已经是一个老掉牙的问题了，只要涉及到**MVVM**框架就不得不谈的知识点。

可以实现双向绑定的方法有很多，`KnockoutJS`基于观察者模式的双向绑定，`Ember`基于数据模型的双向绑定，`Angular`基于脏检查的双向绑定，本篇文章重点讲常见的基于数据劫持的双向绑定。

- 常见的基于数据劫持的双向绑定有两种实现，一个是`Object.defineProperty`，另一个是 `ES2015` 中新增的`Proxy`，通过本文我们可以知道两者的优劣。
::: tip 提示 

严格来讲 `Proxy` 应该被称为『代理』而非『劫持』，不过由于作用有很多相似之处，我们在下文中就不再做区分，统一叫『劫持』。
:::

## 什么是数据劫持
数据劫持比较好理解，通常我们利用`Object.defineProperty`劫持对象的访问器，在属性值发生变化时我们可以获取变化，从而进行进一步操作
```jsx harmony
// 这是将要被劫持的对象
const data = {
  name: '',
};

function say(name) {
  if (name === 'dog') {
    console.log('汪~');
  } else if (name === 'cat') {
    console.log('喵~');
  }
}

// 遍历对象,对其属性值进行劫持
Object.keys(data).forEach(function(key) {
  Object.defineProperty(data, key, {
    enumerable: true,
    configurable: true,
    get: function() {
      console.log('检测到属性获取');
      return key
    },
    set: function(newVal) {
      // 当属性值发生变化时我们可以进行额外操作
      console.log(`属性值将要改变为${newVal}`);
      say(newVal);
      key = newVal
    },
  });
});

data.name = 'dog';
console.log(data.name)

```
控制台依次打印
```
属性值将要改变为dog
汪~
检测到属性获取
dog
```
## 数据劫持的优势
目前业界分为两个大的流派，一个是以React为首的单向数据绑定，另一个是以Angular、Vue为主的双向数据绑定

::: tip
其实三大框架都是既可以双向绑定也可以单向绑定，比如`React`可以手动绑定`onChange`，调用`setState`实现双向绑定。`Vue`也加入了`props`这种单向流的`api`，不过都并非主流卖点。
:::

单向或者双向的优劣不在我们的讨论范围，我们需要讨论一下对比其他双向绑定的实现方法，数据劫持的优势所在。
- **无需显示调用**: 例如 `Vue` 运用数据劫持+发布订阅，直接可以通知变化并驱动视图。而比如 `Angular` 的脏检测则需要显示调用 `markForCheck` 。`React` 需要显示调用 `setState`
- **可精确得知变化数据**：还是上面的例子，我们劫持了属性的`setter`，当属性值改变，我们可以精确获知变化的内容`newVal`，因此在这部分不需要额外的`diff`操作，否则我们只知道数据发生了变化而不知道具体哪些数据变化了，这个时候需要大量`diff`来找出变化值，这是额外性能损耗。

## 实现思路
基于数据劫持的双向绑定离不开`Proxy`与`Object.defineProperty`等方法对 **对象/对象属性**的『劫持』，我们要实现一个完整的双向绑定需要以下几个要点:
- 利用 `Proxy` 或 `Object.defineProperty` 生成的 `Observer` 针对**对象/对象的属性**进行『劫持』，在属性发生变化后通知订阅者。
- 解析器 `Compile` 解析模板中的 `Directive` (指令)，收集指令所依赖的方法和数据，等待数据变化然后进行渲染。
- `Watcher` 属于 `Observer` 和 `Compile` 桥梁，它将接收到的 `Observer` 产生的数据变化，并根据`Compile`提供的指令进行视图渲染，使得数据变化促使视图变化。
 <Picture src="observer/bind.jpg"/>
::: tip
可以看到，虽然运用了数据劫持，但是依然离不开**发布订阅**的模式，在上文做了 `Event Bus` 的实现，就是因为不管在学习一些框架的原理还是一些流行库（例如Redux、Vuex），基本上都离不开发布订阅模式，而`Event`模块则是此模式的经典实现。
:::

## 极简版的双向绑定
`Object.defineProperty`的作用就是劫持一个对象的属性，通常我们对属性的`getter`和`setter`方法进行劫持，在对象的属性发生变化时进行特定的操作。

我们就对对象obj的text属性进行劫持，在更改属性值的时候对DOM进行操作，这就是一个极简的双向绑定。

```jsx harmony
const obj = {};
Object.defineProperty(obj, 'text', {
  get: function() {
    return text
  },
  set: function(newVal) {
    console.log('set val:' + newVal);
    document.getElementById('input').value = newVal;
    document.getElementById('span').innerHTML = newVal;
    text = newVal
  }
});

const input = document.getElementById('input');
input.addEventListener('keyup', function(e){
  obj.text = e.target.value;
})
```
##  升级改造
我们很快会发现，这个所谓的双向绑定貌似并没有什么卵用。

原因如下:
- 只监听了一个属性，一个对象不可能只有一个属性，我们需要对对象每个属性进行监听。
- 违反开放封闭原则，我们如果了解开放封闭原则的话，上述代码是明显违反此原则，我们每次修改都需要进入方法内部，这是需要坚决杜绝的。
- 代码耦合严重，数据、方法和DOM都是耦合在一起的。

那么如何解决上述问题？
- 加入**发布订阅**模式，结合`Object.defineProperty`的劫持能力，实现了可用性很高的双向绑定。

首先，以发布订阅的角度看我们第一部分写的那一坨代码，会发现它的监听、发布和订阅都是写在一起的，我们首先要做的就是解耦。
### Dep 订阅中心

我们先实现一个订阅发布中心，即消息管理员`Dep`。Dep主要负责收集订阅者，然后在属性变化的时候执行对应订阅者的更新函数。

```jsx harmony
let uid = 0;
    /**
    * 用于储存订阅者并发布消息
    */
  class Dep {
    constructor() {
      this.id = uid++;// 设置id,用于区分新Watcher和只改变属性值后新产生的Watcher
      this.subs = []; // 储存订阅者的数组
    }
    /**
    * 触发target上的Watcher中的addDep方法,参数为dep的实例本身
    */
    depend() {
      Dep.target.addDep(this);
    }
    // 添加订阅者
    addSub(sub) {
      this.subs.push(sub);
    }
    /**
    * 通知所有的订阅者(Watcher)，触发订阅者的相应逻辑处理
    */
    notify() {
      this.subs.forEach(sub => sub.update());
    }
    
  }
  Dep.target = null;// 用来缓存刚初始化的Watcher
```
### Observer 监听者
现在我们需要实现监听者`Observer`，用于监听属性值的变化。
```jsx harmony
  class Observer {
    constructor(value) {
      this.value = value;
      this.watch(value);
    }
    // 遍历属性值并监听
    watch(value) {
      Object.keys(value).forEach(key => defineReactive(this.value,key, value[key]));
    }
  }

  function defineReactive(obj, key, val) {
    const dep = new Dep(); // 每个基本类型数据都独有自己的发布订阅中心
    let chlidOb = observe(val);// 递归为给当前属性的值添加监听
    Object.defineProperty(obj, key, {
      enumerable: true,
      configurable: true,
      get: () => {  // Watcher实例在实例化过程中，会读取data中的某个属性，从而触发当前get方法
        if (Dep.target) { // 判断是否是初始化读取，是的话需要才注册订阅者
          dep.depend();
        }
        return val;
      },
      set: newVal => {
        if (val === newVal) return;
        key = newVal; // 为成员变量赋值
        chlidOb = observe(newVal);// 对新值进行监听（如果新值类型改变，需要重新监听）
        dep.notify();// 通知所有订阅者，数值被改变了
      },
    });
  }

  /**
    * 当值不存在，或者不是复杂数据类型时，不再需要继续深入监听，否则继续深入监听
    * @param value
    * @returns {*}
    */
  function observe(value) {
    if (!value || typeof value !== 'object') {
      return;
    }
    return new Observer(value);
  }

```
- `Observer` 是一个数据监听器，其实现核心方法就是前文所说的 `Object.defineProperty`。
- 如果要对所有属性都进行监听的话，那么可以通过递归方法遍历所有属性值，并对其进行 `Object.defineProperty` 处理。
- `Observer` 为该属性的每一个 `key` 分配 `dep` ，当 `Observer` 劫持到某一属性变化时，该属性相应的 `dep` 遍历 `subs` 订阅者列表（Watchers），为他们分发状态。
- 我们将订阅器**Dep添加订阅者**设计在 `getter` 里面，这是为了让 `Watcher` 初始化进行触发，因此需要判断是否要添加订阅者，下文详细说明。

### Watcher 订阅者
订阅者Watcher在初始化的时候需要将自己添加进订阅器Dep中，那该如何添加呢？

我们已经知道监听器 `Observer` 是在 `get` 函数执行添加订阅者的操作的，所以我们只要在订阅者 `Watcher` 初始化的时候触发对应的 `get` 函数去执行添加订阅者操作即可。
- 这里还有一个细节点需要处理，我们只要在订阅者 `Watcher` 初始化的时候才需要添加订阅者，所以需要做一个判断操作。因此可以在订阅器上做一下手脚：

在 `Dep.target` 上缓存订阅者，添加成功后再将其去掉就可以了。订阅者 `Watcher` 的实现如下：
```jsx harmony
class Watcher {
    constructor(vm, expOrFn, cb) {
      this.depIds = {}; // hash储存订阅者的id,避免重复的订阅者
      this.vm = vm; // 被订阅的数据一定来自于当前Vue实例
      this.cb = cb; // 当数据更新时想要做的事情，即订阅者定义的处理函数
      this.expOrFn = expOrFn; // 被订阅的数据
      this.val = this.get(); // 维护更新之前的数据
    }
    // 对外暴露的接口，用于在订阅的数据被更新时，由订阅者管理员(Dep)调用
    update() {
      this.run();
    }
    run() {
          const val = this.get();
          if (val !== this.val) {
            this.val = val;
            this.cb.call(this.vm, val);
          }
    }
    /**
    * 当前订阅者(Watcher)读取被订阅数据的最新更新后的值时，通知订阅者管理员收集当前订阅者
    * @returns {*}
    */
    get() {
          Dep.target = this; // 缓存当前订阅者到Dep中
          const val = this.vm._data[this.expOrFn];//做取值操作，将自己添加进Dep中
          Dep.target = null;// 置空，用于下一个Watcher使用
          return val;
        }
        
    addDep(dep) {
      // 如果在depIds的hash中没有当前的id,可以判断是新Watcher,因此可以添加到dep的数组中储存
      // 此判断是避免同id的Watcher被多次储存
      if (!this.depIds.hasOwnProperty(dep.id)) {
        dep.addSub(this);
        this.depIds[dep.id] = dep;
      }
    }
    
  }
```
那么我们最后完成MVVM,将上述方法挂载在MVVM上。

### MVVM 
```jsx harmony
class MVVM {
    constructor(options = {}) {
      // 简化了$options的处理
      this.$options = options;
      // 简化了对data的处理
      let data = (this._data = this.$options.data);
      // 将所有data最外层属性代理到Vue实例上
      Object.keys(data).forEach(key => this._proxy(key));
      // 监听数据
      observe(data);
    }
    _proxy(key) {
          Object.defineProperty(this, key, {
            configurable: true,
            enumerable: true,
            get: () => this._data[key],
            set: val => {
              this._data[key] = val;
            },
          });
        }
    // 对外暴露调用订阅者的接口，内部主要在指令中使用订阅者
    $watch(expOrFn, cb) {
      new Watcher(this, expOrFn, cb);
    }
  }
```
#### 这里还有一个细节要注意

- 在赋值的时候是这样的形式 `this.data.name = 'dog'`
- 而理想的形式是 `this.name = 'dog'`

为了实现这样的形式，我们需要在 `new MVVM()` 的时候做一个代理处理，让访问 `MVVM` 的属性代理为访问 `MVVM.data` 的属性，实现原理还是使用 `Object.defineProperty` 对属性值再包一层。

::: tip
到这里我们还少了一步就是指令解析器，用来解析指令并进行试图渲染。为了方便我们直接手动订阅事件。
:::
### 事件订阅
```jsx harmony
let demo = new MVVM({
  data: {
    text: '',
  },
});

const label = document.getElementById('label');
const input = document.getElementById('input');

input.addEventListener('keyup', function(e) {
  demo.text = e.target.value;
});

demo.$watch('text', str => label.innerHTML = str);
```

[双向绑定实现](https://codepen.io/xiaomuzhu/pen/jxBRgj/) by Iwobi (@xiaomuzhu) on CodePen.

### Object.defineProperty 的缺陷

其实我们升级版的双向绑定依然存在漏洞，比如我们将属性值改为数组。
```jsx harmony
 let demo = new Vue({
    data: {
      list:[1,2,3]
    },
  });

  const list = document.getElementById('list');
  const btn = document.getElementById('btn');
  btn.addEventListener('click', function() {
    demo.list.push(1);
    console.log(demo.list)
  });

  const render = arr => {
    for (let i = 0; i < arr.length; i++) {
      const li = document.createElement('li');
      li.textContent = arr[i];
      list.appendChild(li);
    }
  };

  demo.$watch('list', list => render(list));

```

`Object.defineProperty` 的第一个缺陷，无法监听数组变化。然而 `Vue` 的文档提到了 `Vue` 是可以检测到数组变化的，但是只有以下八种方法。`vm.items[indexOfItem] = newValue` 这种是无法检测的。
```jsx harmony
push()
pop()
shift()
unshift()
splice()
sort()
reverse()

```
其实作者在这里用了一些奇技淫巧，把无法监听数组的情况hack掉了，以下是方法示例。
```jsx harmony
const aryMethods = ['push', 'pop', 'shift', 'unshift', 'splice', 'sort', 'reverse'];
const arrayAugmentations = [];

aryMethods.forEach((method)=> {

    // 这里是原生Array的原型方法
    let original = Array.prototype[method];

   // 将push, pop等封装好的方法定义在对象arrayAugmentations的属性上
   // 注意：是属性而非原型属性
    arrayAugmentations[method] = function () {
        console.log('我被改变了!');
        // 调用对应的原生方法并返回结果
        return original.apply(this, arguments);
    };

});

let list = ['a', 'b', 'c'];
list.__proto__ = arrayAugmentations;// 修改将要监听的数组的原型指针指向上面包装好的方法集合
list.push('d');  // 我被改变啦！ 4


let list2 = ['a', 'b', 'c']; // 这里的list2没有被重新定义原型指针，所以就正常输出
list2.push('d');  // 4

```

由于只针对了八种方法进行了 `hack` 所以其他数组的属性也是检测不到的。

可以注意到在上文中的实现里，我们多次用遍历方法遍历对象的属性。
```jsx harmony
Object.keys(value).forEach(key => this.convert(key, value[key]));
```

这就引出了 `Object.defineProperty` 的第二个缺陷：

只能劫持对象的属性，因此我们需要对每个对象的每个属性进行遍历，如果属性值也是对象那么需要深度遍历，显然能劫持一个完整的对象是更好的选择。


## Proxy 实现的双向绑定
`Proxy` 在 `ES2015` 规范中被正式发布，它在目标对象之前架设一层“拦截”，外界对该对象的访问，都必须先通过这层拦截，因此提供了一种机制，可以对外界的访问进行过滤和改写，我们可以这样认为，`Proxy`是`Object.defineProperty`的全方位加强版。

关于 Proxy 的用法可以移步阮一峰老师的 [ECMAScript 6 入门](http://es6.ruanyifeng.com/#docs/proxy)

### Proxy 可以直接监听对象而非属性
我们还是以上文中用 `Object.defineProperty` 实现的极简版双向绑定为例，用` Proxy `进行改写。
```jsx harmony
const input = document.getElementById('input');
const p = document.getElementById('p');
const obj = {};

const newObj = new Proxy(obj, {
  get: function(target, key, receiver) {
    console.log(`getting ${key}!`);
    return Reflect.get(target, key, receiver);
  },
  set: function(target, key, value, receiver) {
    console.log(target, key, value, receiver);
    if (key === 'text') {
      input.value = value;
      p.innerHTML = value;
    }
    return Reflect.set(target, key, value, receiver);
  },
});

input.addEventListener('keyup', function(e) {
  newObj.text = e.target.value;
});

```
我们可以看到， `Proxy` 直接可以劫持整个对象，并返回一个新对象，不管是操作便利程度还是底层功能上都远强于 `Object.defineProperty`。
###  Proxy 可以直接监听数组的变化

当我们对数组进行操作 `push` `shift` `splice` 时，会触发对应的方法名称和 `length` 的变化，我们可以借此进行操作，以上文中 `Object.defineProperty` 无法生效的列表渲染为例。
```jsx harmony

const list = document.getElementById('list');
const btn = document.getElementById('btn');

// 渲染列表
const Render = {
  // 初始化
  init: function(arr) {
    const fragment = document.createDocumentFragment();
    for (let i = 0; i < arr.length; i++) {
      const li = document.createElement('li');
      li.textContent = arr[i];
      fragment.appendChild(li);
    }
    list.appendChild(fragment);
  },
  // 我们只考虑了增加的情况,仅作为示例
  change: function(val) {
    const li = document.createElement('li');
    li.textContent = val;
    list.appendChild(li);
  },
};

// 初始数组
const arr = [1, 2, 3, 4];

// 监听数组
const newArr = new Proxy(arr, {
  get: function(target, key, receiver) {
    console.log(key);
    return Reflect.get(target, key, receiver);
  },
  set: function(target, key, value, receiver) {
    console.log(target, key, value, receiver);
    if (key !== 'length') {
      Render.change(value);
    }
    return Reflect.set(target, key, value, receiver);
  },
});

// 初始化
window.onload = function() {
    Render.init(arr);
}

// push数字
btn.addEventListener('click', function() {
  newArr.push(6);
});

```
在线示例 [Proxy列表渲染](https://codepen.io/xiaomuzhu/pen/zjwGoN/) by Iwobi (@xiaomuzhu) on CodePen.

很显然，`Proxy ` 不需要那么多 `hack`（即使hack也无法完美实现监听）就可以无压力监听数组的变化，我们都知道，标准永远优先于 `hack`。

### Proxy 的其他优势
`Proxy` 有多达13种拦截方法，不限于 `apply` `ownKeys` `deleteProperty` `has`等等是 `Object.defineProperty` 不具备的。

`Proxy` 返回的是一个新对象，我们可以只操作新的对象达到目的，而 `Object.defineProperty` 只能遍历对象属性直接修改。

当然，`Proxy` 的劣势就是兼容性问题，而且无法用 `polyfill` 磨平，因此Vue的作者才声明需要等到下个大版本3.0才能用 `Proxy` 重写。
