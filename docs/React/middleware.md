## 思考
我们在 Redux 异步 Action 中经常使用这种写法：
```jsx harmony
export function getTodos(){
  return (dispatch,getStore) => {
    TodoApi.getTodos().then(result=>{
      dispatch({
      type:TODOLIST,
      data:result.data
      })
    })
  }
}
``` 
而正常的 Action 就看起来好像应该是这样：
```jsx harmony
export function getTodos(){
  return {
    type:TODOLIST,
    data:result.data
  }
}
```
为什么我们上一种写法能正常工作呢？Action不应该返回一个对象吗怎么返回了一个函数？

Action 之所以支持第一种写法，是因为我们引入了 `redux-thunk` 中间件。那么 `redux-thunk` 是怎么工作的？

让我们在本文中一步步剖析 `middleware` 中间件的实现原理。
## 什么是 middleware
- `middleware` 是指可以被嵌入在框架接收请求到产生响应过程之中的代码。

- `middleware` 最优秀的特性就是可以被**链式组合**。我们可以在一个项目中使用多个独立的第三方 middleware。

正因为 middleware 可以完成包括异步 API 调用在内的各种事情，了解它的演化过程是一件相当重要的事。

我们将以记录日志和创建崩溃报告为例，体会从分析问题到通过构建 middleware 解决问题的思维过程。
## 问题：记录日志
现在设想这么一个问题：我们需要在应用中每一个 `Action` 被发起以及新的 `state` 被计算完成时都将他们记录下来。当程序出现问题时，我们可以通过查阅日志找出是哪个 action 导致了 state 不正确。
### 尝试 1: 手动记录

假设，我们在获取Todo列表时这么调用
```jsx harmony
export function getTodos(){
  return {
    type:TODOLIST,
    data:result.data
  }
}
```
```jsx harmony
store.dispatch(getTodos())
```
为了记录这个action以及新的state，我们可以通过这种方式记录：
```jsx harmony
let action = getTodos();
console.log('dispatching', action)
store.dispatch(action)
```
虽然这么做可以达到想要的效果，可是我们并不想每次都这么多。

### 尝试 2: 封装 Dispatch
我们可以将上面的操作封装成一个函数
```jsx harmony
function dispatchWithLog(store,action){
    console.log('dispatching', action)
    store.dispatch(action)
}
```
然后我们这么调用它：
```jsx harmony
dispatchWithLog(store, getTodos())
```
我们已经接近了 middleware 的思想，但每次都要导入一个外部方法总归不大方便。
### 尝试 3: 替换 Dispatch
如果我们直接`替换` store 实例中的 dispatch 函数会怎么样呢？

Redux store 只是一个包含一些方法的普通对象，同时我们使用的是 JavaScript，因此我们可以这样来包装 dispatch：
```jsx harmony
let next = store.dispatch
store.dispatch = function dispatchWithLog(action) {
  console.log('dispatching', action)
  let result = next(action)
  console.log('next state', store.getState())
  return result
}
```
- 将 next 指向原生的dispatch。
- 将 store.diapatch 变成我们自定义的函数。
- 在这个自定义的函数中调用next，也就是原dispatch。

这样就完美地改写了dispatch，保留了原始功能，还添加了自定义的方法。离我们想要的已经非常接近了！

但直接替换 dispatch 令人感觉还是不太舒服，不过利用它我们做到了我们想要的。

## 问题: 捕获异常
如果我们想对 dispatch 附加超过一个的特殊处理，又会怎么样呢？

脑海中出现的另一个常用的特殊处理就是在生产过程中报告 JavaScript 的错误。

但是全局的 `window.onerror` 并不可靠，因为它在一些旧的浏览器中无法提供错误堆栈，而这是排查错误所需的至关重要信息。

试想当发起一个 action 的结果是一个异常时，我们将包含调用堆栈，引起错误的 action 以及当前的 state 等错误信息通通发到报告服务中，不是很好吗？这样我们可以更容易地在开发环境中重现这个错误。

然而，将**日志记录**和**崩溃报告** `分离`是很重要的。理想情况下，我们希望他们是两个不同的模块，也可能在不同的包中。否则我们无法构建一个由这些工具组成的生态系统。

按照我们的想法，日志记录和崩溃报告属于不同的模块，他们看起来应该像这样：
```jsx harmony
function patchStoreWithLog(store) {
  let next = store.dispatch
  store.dispatch = function dispatchWithLog(action) {
    console.log('dispatching', action)
    let result = next(action)
    console.log('next state', store.getState())
    return result
  }
}

function patchStoreWithReport(store) {
  let next = store.dispatch
  store.dispatch = function dispatchWithReportErrors(action) {
    try {
      return next(action)
    } catch (error) {
      console.error('捕获一个异常!', error)
      report({
          error, 
          action,
          state: store.getState()
      })
      throw error
    }
  }
}
```
如果这些功能以不同的模块发布，我们可以在 store 中像这样使用它们：
```jsx harmony
patchStoreWithLog(store)
patchStoreWithReport(store)
```
- 第一个`patchStoreWithLog`将dispatch进行了第一层封装，他的`next`是store原生dispatch
- 第二个`patchStoreWithReport`将dispatch进行了第二次封装，他的`next`是`dispatchWithLog`

这样我们就实现了对dispatch的多重处理。

尽管如此，这种方式看起来还是有一些啰嗦。
### 尝试 4: 隐藏 `hack`
我们之前的操作本质上是一种hack。

我们用自己的函数替换掉了 store.dispatch。如果我们不这样做，而是在函数中返回新的 dispatch 呢？
```jsx harmony
function logger(store) {
  let next = store.dispatch
  // 我们之前的做法:
  // store.dispatch = function dispatchAndLog(action) {
  return function dispatchWithLog(action) {
    console.log('dispatching', action)
    let result = next(action)
    console.log('next state', store.getState())
    return result
  }
}

function report(store){
  let next = store.dispatch
    // 我们之前的做法:
    // store.dispatch = function dispatchAndLog(action) {
    return function dispatchWithReport(action) {
    try{
      let result = next(action)
      return result
      }catch (error) {
          console.error('捕获一个异常!', error)
            report({
               error, 
               action,
               state: store.getState()
            })
          throw error
      }
    }
}
```
我们通过`闭包`存储了`store`，以便在action真正调用的时候供其访问。

我们可以在 Redux 内部提供一个可以将实际的 hack 应用到 store.dispatch 中的辅助方法：
```jsx harmony
function applyMiddleware(store, middlewares) {
  // 在每一个 middleware 中变换 dispatch 方法。
  middlewares.forEach(middleware =>
    store.dispatch = middleware(store)
  )
}
```
然后像这样应用多个 middleware：
```jsx harmony
applyMiddleware(store, [ logger,report ])
```
上面的代码可能看起来一时难以理解，这也是中间件的精华所在。我们来具体分析一下：
#### middleware
每一个`middleware`都是高阶函数，它使用了`函数柯里化`的思想，分两步执行：
   - 第一步：接收一个`store`对象，利用闭包将其存储。返回一个函数，也就是第二步。
   - 第二步：接收一个具体的`action`，使用上一步存储的`store.dispatch`执行该`action`,并返回执行结果。
#### applyMiddleware
接收原始的`store`对象和一系列的`middlewares`。

它遍历 middlewares 列表，进行以下操作：

- 对每一个 middleware 进行第一步调用，入参为`store`对象，返回一个**可执行函数**。

- 将 store.dispatch  `hack` 为 **可执行函数**。

> 这样一来，每一个 middleware 所存储的 store ，都是被`上一个` middleware hack后的。也就是说，
> 我们在 report 中闭包存储的store对象，它的 dispatch 方法实际上是 logger 的`dispatchWithLog`。

#### 总体流程

- 调用`store.dispatch`，实际上调用的是`dispatchWithReport`

- 进行错误信息收集，然后调用`next(action)`，实际上调用的是`dispatchWithLog(action)`

- 进行日志记录,然后调用`next(action)`，此时才真正调用原生 `store.dispatch`

- 原生的 dispatch 返回一个 Reducer 可识别的对象，层层向外传递，交由 Reducer处理。

### 尝试 #5: 移除 hack
为什么我们要替换原来的 dispatch 呢 ？
就是每一个 middleware 都可以操作前一个 middleware 包装过的 store.dispatch。

如果没有在第一个 middleware 执行时立即替换掉 store.dispatch，
那么 store.dispatch 将会一直指向原始的 dispatch 方法。也就是说，第二个 middleware 依旧会作用在原始的 dispatch 方法。

还有另一种方式来实现这种链式调用的效果。就是将middleware`柯里化`为三步，
让 middleware 以方法参数的形式接收一个 next() 方法，而不是通过 store 的实例去获取，这样我们就可以避免对`store.dispatch`的hack
```jsx harmony
function logger(store) {
  return function wrapDispatch(next) {
    return function dispatchWithLog(action) {
      console.log('dispatching', action)
      let result = next(action)
      console.log('next state', store.getState())
      return result
    }
  }
}
```
这些串联函数很吓人。ES6 的箭头函数可以使 `柯里化` 看起来更舒服一些:
```jsx harmony
const logger = store => next => action => {
     console.log('dispatching', action)
     let result = next(action)
     console.log('next state', store.getState())
     return result
}
   ```
```jsx harmony
const crashReporter = store => next => action => {
  try {
    return next(action)
  } catch (err) {
    console.error('Caught an exception!', err)
    Raven.captureException(err, {
      extra: {
        action,
        state: store.getState()
      }
    })
    throw err
  }
}
```
这正是 Redux middleware 的样子。

如果要自己实现一个 `middleware` 应用到 redux 中，完全可以按照这种形式去写。

## 源码分析
我们的`applyMiddleware` 和 Redux 中 `applyMiddleware()` 的实现已经很接近了。有了上面的铺垫，让我们来分析一下真正的源码。

代码虽然只有不到20行，但看懂确实是不容易。
```jsx harmony
export default function applyMiddleware(...middlewares) { 
  return createStore => (...args) => { 
    const store = createStore(...args)  
    let dispatch = () => { 
      throw new Error(
      )
    }
    const middlewareAPI = {  // 定义API
      getState: store.getState, //注入 getStore方法
      dispatch: (...args) => dispatch(...args) //初始化dispatch
    }
    const chain = middlewares.map(middleware => middleware(middlewareAPI))
    dispatch = compose(...chain)(store.dispatch)
    return {
      ...store,
      dispatch
    }
  }
}

```
### middlewares
```jsx harmony
export default function applyMiddleware(...middlewares)
```
`applyMiddleware`接收第一个参数，他正是所有的middleware列表。
### createStore 以及 reducers
```jsx harmony
return createStore => (...args) => {
  ... ...
}
```
`applyMiddleware`接收第二和第三个参数，他们分别是`createStore` `reducers`

为了保证只能应用 middleware 一次，它作用在 createStore() 上而不是 store 本身。

### 创建store
```jsx harmony
 const store = createStore(...args)  
```
利用传入的createStore和reducer和创建一个store
### 定义API
```jsx harmony
let dispatch = () => { 
      throw new Error(
      )
    }
    const middlewareAPI = {  // 定义API
      getState: store.getState, //注入 getStore方法
      dispatch: (...args) => dispatch(...args) //初始化dispatch
    }
```
这里有一个地方需要注意：
- 并没有直接使用`dispatch:dispatch`，而是使用了`dispatch:(action) => dispatch(action)`

- 如果使用了`dispatch:dispatch`，那么在所有的 Middleware 中实际都引用的同一个dispatch(闭包)，
那么一个中间件修改了dispatch，其他所有的dispatch都将被改变。

- 所以这里使用`dispatch:(action) => dispatch(action)`，每一个 middlewareAPI 的 dispatch 引用都是不同的

### 初始化
```jsx harmony
 const chain = middlewares.map(middleware => middleware(middlewareAPI))
```
让每个 middleware 带着 middlewareAPI 这个参数分别执行一遍，进行初始化。

得到的函数链为每个中间件的第一个返回函数，该函数可接收一个dispatch动作，再返回一个可以接收action的函数。

函数链中的每一个函数看起来像是这样：
```jsx harmony
middlewareAPI = {  
  getState: store.getState,
  dispatch: (...args) => dispatch(...args)
} 
// 这里 middlewareAPI 作为闭包存在于匿名函数Anonymous的作用域链
function Anonymous (next) {
  return function(action){
    ... ...
    return next(action);
  }
}
```
它的柯里化后两步操作分别为：
- 接收一个next方法
- 接受一个action，并执行`next(action)`
 
### compose
```jsx harmony
dispatch = compose(...chain,store.dispatch)
```
这句是最精妙也是最有难度的地方。

个人认为这个compose函数是整个redux中非常亮眼的部分，
短短几行代码，就完成了一个核心功能的扩展，是责任链设计模式的经典体现。
我们来看一下`compose`的源码：
```jsx harmony
function compose() {
  for (var _len = arguments.length, funcs = Array(_len), _key = 0; _key < _len; _key++) {
    funcs[_key] = arguments[_key];
  }

  if (funcs.length === 0) {
    return function (arg) {
      return arg;
    };
  }

  if (funcs.length === 1) {
    return funcs[0];
  }

  return funcs.reduce(function (a, b) {
    return function () {
      return a(b.apply(undefined, arguments));
    };
  });
}
```

`compose`在这里将所有的 `中间件的第一个返回函数` 聚合。
也就像我们刚才分析的，将`store.dispatch`传给第一个中间件，第一个中间件对其进行封装后传给第二个中间件，
以此类推... ...。

最底层的`dispatch`为`store.dispatch`，一层一层的封装，最终得到一个层层封装后的`“dispatch”`。

或许已经不能称之为`dispatch`，他是原生的`dispatch`，以及一系列增强函数的`集合`。
### 最后
```jsx harmony
return {
  ...store,
  dispatch
}
```
将`store`中的所有可枚举属性复制进去(浅复制),并用层层封装好的`“dispatch”`覆盖store中的dispatch属性。

## redux-thunk

我们回到最开始的问题
```jsx harmony
export function getTodos(){
  return (dispatch,getStore) => {
    TodoApi.getTodos().then(result=>{
      dispatch({
      type:TODOLIST,
      data:result.data
      })
    })
  }
}
```
上面这种写法是怎么工作的呢？

让我们结合redux-thunk源码来分析一下便一目了然。
```jsx harmony
function createThunkMiddleware(extraArgument) {
  return function (_ref) {
    var dispatch = _ref.dispatch,
      getState = _ref.getState;
    return function (next) {
      return function (action) {
        if (typeof action === 'function') {
          return action(dispatch, getState, extraArgument);
        }
        return next(action);
      };
    };
  };
}
```
代码同样精炼，改造后的dispatch接收到action后有两种情况：
- 如果我们返回的`action`是一个普通对象，形如
```jsx harmony
{
  type:GETTODOS,
  data:[]
}
```
那么，redux-thunk将不予处理，继续将 action 向下传递。项目中如果没有其他中间件，这里会直接调用原生的dispatch，交由 Reducer 处理。
- 如果我们返回的`action`是一个函数，就像我们一直在使用的：
```jsx harmony
  return (dispatch,getStore) => {
    TodoApi.getTodos().then(result=>{
      dispatch({
      type:TODOLIST,
      data:result.data
      })
    })
  }
```
为了方便理解，我们可以稍作变换：
```jsx harmony
const func = (dispatch, getStore) => {
  TodoApi.getTodos().then(result => {
    dispatch({
      type: TODOLIST,
      data: result.data
    })
  })
}
return func;
```
这里的返回值无疑是`function`。现在就轮到`redux-thunk`上场了：
```jsx harmony
if (typeof action === 'function') {
    return action(dispatch, getState, extraArgument);
}
```
这里的`action`就是我们的`func`,`func`在此处被执行，就相当于：
```jsx harmony
  func(dispatch, getState, extraArgument);
```
这里的`dispatch`，`getState`都是在闭包中存储的变量。
- `getState` 可以获取到store中所有的state
- `dispatch`可能是`store.dispatch`原生方法，当然也有可能是下一个 middleware 封装后的方法。

看到这里，应该不难明白这是如何工作的了吧：
```jsx harmony
export function getTodos(){
  return (dispatch,getStore) => {
    TodoApi.getTodos().then(result=>{
      dispatch({
      type:TODOLIST,
      data:result.data
      })
    })
  }
}
```

