## 关于QAP
**QAP**，本质上来说就是[Rax](https://alibaba.github.io/rax/)。它是阿里基于weex和ReactNative自己又独立搞出来的一套架构。

我们在web端如果想要进行全局的异常捕获，只需要对`window.onerror`事件进行监听就可以。

而Rax是个异类。它的window对象上没有onerror这个事件，我们也就无法对错误进行全局监听。只有采用手动`try catch`的方法来捕获错误。

但是设想一下如果为每一个方法都加上`try catch`，代码的可读性想必... ...

## 处理方式
- 对逻辑层进行包装，为所有的方法自动添加`try catch`
- 分析AST(抽象语法树)，编写一个插件在代码编译时为每一个函数自动添加`try catch`
> AST太高深了，我也不太懂哈哈哈🤣所以本文只介绍第一种方法

## 现状
目前移动端项目中的逻辑层，基本是统一放在`controller`里面进行处理的。
```jsx harmony
class GoodsDetail extends Component{
  constructor(props){
    super(props);
    this.controller = new GoodsDetailController(); 
    // 所有的业务逻辑都是通过调用this.controller.XXX
  }
}
```
```jsx harmony
class GoodsDetailController{
  constructor(){
    
  }
  getTodos(){
    
  }
  addTodo = () =>{
    
  }
}
```
这样做对我们的下一步提供了极大的便利，我们只需要对`controller`动刀就可以了。

### 问题
就像刚才代码中所看到的，GoodsDetailController中定义的方法有些是直接定义
```jsx harmony
getTodos(){
    
  }
```
而有些是使用箭头函数定义
```jsx harmony
addTodo = () =>{
    
  }
```
这里要引入一个小知识点：
#### 直接定义的方法

根据 `ES6` class的特性，它是定义在`GoodsDetailController.prototype`中的，所有实例共享一份。

换句话说，
`this.controller`实例上并没有`getTodos`这个方法，`this.controller.getTodos()`之所以能够调用成功，是因为当前对象没有找到该方法时，会沿着原型链向上查找，
当查找`this.controller.__proto__`也就是`GoodsDetailController.prototype`时，发现有`getTodos`这个方法，那么再调用。
<Picture src="proto.png" />

#### 箭头函数定义的方法

而在类中使用箭头函数定义的方法，不会定义在`GoodsDetailController.prototype`。他会在实例化该类时，为每一个实例自动绑定该方法，他们之间并不共享。
```jsx harmony
this.controller = new GoodsDetailController();
this.controller1 = new GoodsDetailController();
console.log(this.controller.getTodos === this.controller1.getTodos)// true
console.log(this.controller.addTodo === this.controller1.addTodo) // false
```
### 两个角度
根据上面的知识点，我们想要获取`this.controller`中所有的方法就要从两个角度出发

- 获取`GoodsDetailController`原型中的所有方法
- 获取`this.controller`实例中的所有方法
::: warning
要知道，所有原型中的属性都是不可枚举的，我们不能采用`Object.keys()`来获取，这里需要借助`Object.getOwnPropertyNames()`。它在MDN中的定义如下：
返回一个由指定对象的所有自身属性的属性名（包括不可枚举属性但不包括Symbol值作为名称的属性）组成的数组
:::
## 第一步
首先我们先获取`GoodsDetailController`原型中的所有方法
```jsx harmony
const result = Object.create(null); // 创建空对象
const prototype = Object.getPrototypeOf(this.controller); // 获取原型
const names = Object.getOwnPropertyNames(prototype); // 获取原型上的不可枚举属性方法列表
 names.forEach((key) => { // 遍历所有实例方法
    if (typeof source[key] === 'function'&&key !== 'constructor') {
      result[key] = function (...args) {
        try {
          this.controller[key].apply(this, args);
        } catch (e) {
          reportInfo(e); // 错误上报
          console.error(e);
        }
      };
    }
  });
```
这里需要注意一点，原型上方法在调用时，它的`this`指向可以通过`apply`、`call`或者`bind`改变。

所以这里我们使用函数声明来定义方法，目的就是获取到该函数被调用时的`this`，然后使用`apply`继续为我们hack后的方法绑定原有的`this`
## 第二步
接下来是获取实例中的所有方法，也就是通过箭头函数定义的方法。
```jsx harmony
for (const key of Object.keys(this.controller)) { // 遍历实例方法，主要为通过箭头函数定义的方法
    if (typeof this.controller[key] === 'function') {
      result[key]=(...args) => {
        try {
          this.controller[key].apply(this.controller, args); // 箭头函数自动绑定this为this.controller
        } catch (e) {
          reportInfo(e); // 错误上报
          console.error(e);
        }
      };
    }
  }
```
这里的处理又和上面不同。原因是通过箭头函数定义的方法，无法使用`bind` `call`或者`apply`来改变`this`指向，所以他的`this`始终指向的是实例本身。
## 复用
我们将上面的逻辑简单封装一下，就得到一个可以复用的方法
```jsx harmony
export default function LogAdvice(source) {
  const target = Object.create(null);
  const prototype = Object.getPrototypeOf(source); 
  const name = Object.getOwnPropertyNames(prototype); 
  Array.isArray(name)&&name.forEach((key) => { // 实例方法
    if (typeof source[key] === 'function'&&key !== 'constructor') {
      target[key] = function (...args) {
        try {
          source[key].apply(this, args);
        } catch (e) {
          reportInfo(e);
          console.error(e);
        }
      };
    }
  });
  for (const key of Object.keys(source)) { 
    if (typeof source[key] === 'function') {
      target[key]=(...args) => {
        try {
          source[key].apply(source, args);
        } catch (e) {
          reportInfo(e);
          console.error(e);
        }
      };
    }
  }
  return target;
}
```
### 使用
```jsx harmony
class GoodsDetail extends Component{
  constructor(props){
    super(props);
    this.controller = LogAdvice(new GoodsDetailController()); 
    // 所有的业务逻辑都是通过调用this.controller.XXX
  }
}
```
### 缺点
使用`LogAdvice`可以捕获到所有同步代码中的错误，但是对于异步代码就无能为力了。比如说`Promise.catch`还是需要我们手动处理。
